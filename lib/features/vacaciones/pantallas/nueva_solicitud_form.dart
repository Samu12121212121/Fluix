import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import '../../../models/vacacion_model.dart';
import '../../../models/saldo_vacaciones_model.dart';
import '../../../services/vacaciones_service.dart';
import '../../../services/bandeja_notificaciones_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FORMULARIO NUEVA SOLICITUD DE VACACIONES / AUSENCIA
// ═══════════════════════════════════════════════════════════════════════════════

class NuevaSolicitudForm extends StatefulWidget {
  final String empresaId;
  final String? empleadoIdFijo;
  final DateTime? fechaInicioFija;
  const NuevaSolicitudForm({
    super.key,
    required this.empresaId,
    this.empleadoIdFijo,
    this.fechaInicioFija,
  });

  @override
  State<NuevaSolicitudForm> createState() => _NuevaSolicitudFormState();
}

class _NuevaSolicitudFormState extends State<NuevaSolicitudForm> {
  final _formKey = GlobalKey<FormState>();
  final VacacionesService _svc = VacacionesService();
  final _db = FirebaseFirestore.instance;

  String? _empleadoId;
  String? _empleadoNombre;
  TipoAusencia _tipo = TipoAusencia.vacaciones;
  SubtipoPermiso _subtipo = SubtipoPermiso.matrimonio;
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now().add(const Duration(days: 1));
  final _notasCtrl = TextEditingController();
  bool _guardando = false;

  int get _diasNaturales =>
      VacacionesService.calcularDiasNaturales(_fechaInicio, _fechaFin);
  int get _diasLaborables =>
      VacacionesService.calcularDiasLaborables(_fechaInicio, _fechaFin);

  SaldoVacaciones? _saldoActual;

  // Paleta
  static const _primary = Color(0xFF10B981);
  static const _primaryLight = Color(0xFFD1FAE5);
  static const _bg = Color(0xFFF8FAFC);
  static const _surface = Colors.white;
  static const _textMain = Color(0xFF0F172A);
  static const _textSub = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    if (widget.empleadoIdFijo != null) {
      _empleadoId = widget.empleadoIdFijo;
      _cargarSaldo();
    }
    if (widget.fechaInicioFija != null) {
      _fechaInicio = widget.fechaInicioFija!;
      _fechaFin = widget.fechaInicioFija!;
    }
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSaldo() async {
    if (_empleadoId == null) return;
    try {
      final saldo = await _svc.calcularSaldo(
        widget.empresaId,
        _empleadoId!,
        DateTime.now().year,
      );
      if (mounted) setState(() => _saldoActual = saldo);
    } catch (_) {
      if (mounted) setState(() => _saldoActual = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Material(
        color: Colors.transparent,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          Flexible(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (widget.empleadoIdFijo == null) ...[
                    _buildSectionLabel('Empleado', Icons.person_outline_rounded),
                    _buildSelectorEmpleado(),
                    const SizedBox(height: 16),
                  ],
                  if (_saldoActual != null && _tipo == TipoAusencia.vacaciones) ...[
                    _buildSaldoInfo(),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionLabel('Tipo de ausencia', Icons.category_outlined),
                  _buildTipoSelector(),
                  const SizedBox(height: 16),
                  if (_tipo == TipoAusencia.permisoRetribuido) ...[
                    _buildSectionLabel('Permiso (art. 37 ET)', Icons.gavel_outlined),
                    _buildSubtipoSelector(),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionLabel('Período', Icons.date_range_outlined),
                  _buildFechasRow(),
                  const SizedBox(height: 16),
                  _buildResumen(),
                  if (_tipo == TipoAusencia.vacaciones &&
                      _saldoActual != null &&
                      _diasNaturales > _saldoActual!.totalDisponible)
                    _buildAvisoSaldo(),
                  const SizedBox(height: 16),
                  _buildSectionLabel('Notas', Icons.notes_rounded),
                  _buildNotasField(),
                  const SizedBox(height: 24),
                  _buildBotonGuardar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _border,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.beach_access_rounded,
                color: _primary, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nueva solicitud',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textMain)),
            const Text('Ausencia o permiso',
                style: TextStyle(fontSize: 12, color: _textSub)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: _textSub),
            ),
          ),
        ]),
      );

  Widget _buildSectionLabel(String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 14, color: _textSub),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textSub,
                  letterSpacing: 0.5)),
        ]),
      );

  Widget _buildTipoSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TipoAusencia.values.map((t) {
        final sel = _tipo == t;
        return GestureDetector(
          onTap: () => setState(() {
            _tipo = t;
            if (t == TipoAusencia.permisoRetribuido) {
              _subtipo = SubtipoPermiso.matrimonio;
              _actualizarFechasPorPermiso();
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? _primary : _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? _primary : _border, width: sel ? 1.5 : 1),
              boxShadow: sel
                  ? [
                      BoxShadow(
                          color: _primary.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : [],
            ),
            child: Text(t.etiqueta,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel ? Colors.white : _textMain)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubtipoSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonFormField<SubtipoPermiso>(
        value: _subtipo,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
        items: SubtipoPermiso.values
            .map((s) => DropdownMenuItem(value: s, child: Text(s.etiqueta)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _subtipo = v;
            _actualizarFechasPorPermiso();
          });
        },
      ),
    );
  }

  Widget _buildSelectorEmpleado() {
    return FutureBuilder<QuerySnapshot>(
      future: _db
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('activo', isEqualTo: true)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const LinearProgressIndicator(color: _primary);
        }
        final empleados = snap.data!.docs;
        return Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonFormField<String>(
            value: _empleadoId,
            decoration: const InputDecoration(
              hintText: 'Selecciona empleado',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
            validator: (v) =>
                v == null ? 'Selecciona un empleado' : null,
            items: empleados.map((e) {
              final d = e.data() as Map<String, dynamic>;
              return DropdownMenuItem(
                value: e.id,
                child: Text(d['nombre'] as String? ?? 'Sin nombre'),
              );
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              final doc = empleados.firstWhere((e) => e.id == v);
              final d = doc.data() as Map<String, dynamic>;
              setState(() {
                _empleadoId = v;
                _empleadoNombre =
                    d['nombre'] as String? ?? 'Empleado';
              });
              _cargarSaldo();
            },
          ),
        );
      },
    );
  }

  Widget _buildFechasRow() {
    return Row(children: [
      Expanded(child: _buildFechaCard('Inicio', _fechaInicio, true)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(Icons.arrow_forward_rounded,
            size: 16, color: _textSub),
      ),
      Expanded(child: _buildFechaCard('Fin', _fechaFin, false)),
    ]);
  }

  Widget _buildFechaCard(String label, DateTime value, bool esInicio) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _primary),
            ),
            child: child!,
          ),
        );
        if (picked == null) return;
        setState(() {
          if (esInicio) {
            _fechaInicio = picked;
            if (_fechaFin.isBefore(_fechaInicio)) _fechaFin = _fechaInicio;
          } else {
            _fechaFin = picked;
            if (_fechaFin.isBefore(_fechaInicio)) _fechaInicio = _fechaFin;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: _textSub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 13, color: _primary),
            const SizedBox(width: 6),
            Text(
              '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textMain),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildResumen() {
    final saldoOk = _saldoActual == null ||
        _diasNaturales <= _saldoActual!.totalDisponible;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: saldoOk ? _primaryLight : _amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: saldoOk
                ? _primary.withValues(alpha: 0.3)
                : _amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _resumenChip(
              '$_diasNaturales', 'Días naturales', Icons.sunny_snowing),
          _divider(),
          _resumenChip(
              '$_diasLaborables', 'Días laborables', Icons.work_outline_rounded),
          if (_tipo.descuentaSalario) ...[
            _divider(),
            _resumenChip('Sí', 'Descuenta salario',
                Icons.money_off_rounded,
                color: _red),
          ],
        ],
      ),
    );
  }

  Widget _resumenChip(String val, String label, IconData icon,
      {Color? color}) {
    final c = color ?? _primary;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: c),
      const SizedBox(height: 4),
      Text(val,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: _textSub),
          textAlign: TextAlign.center),
    ]);
  }

  Widget _divider() => Container(
      width: 1, height: 40, color: _border);

  Widget _buildAvisoSaldo() => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _amber.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: _amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Saldo insuficiente: disponibles '
              '${_saldoActual!.totalDisponible.toStringAsFixed(1)} días, '
              'solicitados $_diasNaturales días',
              style: const TextStyle(
                  fontSize: 12, color: _amber),
            ),
          ),
        ]),
      );

  Widget _buildSaldoInfo() {
    final s = _saldoActual!;
    final pct = s.diasDevengados > 0
        ? (s.diasDisfrutados / s.diasDevengados).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 14, color: _primary),
          const SizedBox(width: 6),
          Text(
            'Saldo ${s.anio}: ${s.diasDisfrutados.toStringAsFixed(1)} / ${s.diasDevengados.toStringAsFixed(1)} días',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: _border,
            color: pct > 0.8 ? _amber : _primary,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Disponibles: ${s.totalDisponible.toStringAsFixed(1)} días'
          '${s.diasPendientesAnoAnterior > 0 ? '  ·  ${s.diasPendientesAnoAnterior.toStringAsFixed(1)} del año anterior' : ''}',
          style: const TextStyle(fontSize: 11, color: _textSub),
        ),
      ]),
    );
  }

  Widget _buildNotasField() => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: TextFormField(
          controller: _notasCtrl,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Opcional — motivo, observaciones…',
            hintStyle: TextStyle(fontSize: 13, color: _textSub),
            contentPadding: EdgeInsets.all(14),
            border: InputBorder.none,
          ),
          onFieldSubmitted: (_) =>
              FocusManager.instance.primaryFocus?.unfocus(),
        ),
      );

  Widget _buildBotonGuardar() => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: _guardando
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            _guardando ? 'Enviando…' : 'Enviar solicitud',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      );

  Widget _buildFechaField(String label, DateTime value, bool esInicio) =>
      _buildFechaCard(label, value, esInicio);

  void _actualizarFechasPorPermiso() {
    if (_tipo != TipoAusencia.permisoRetribuido) return;
    setState(() {
      _fechaFin =
          _fechaInicio.add(Duration(days: _subtipo.diasMaxDefecto - 1));
    });
  }

  Widget _infoChip(String label, String value, {Color? color}) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: color ?? _primary)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: _textSub)),
      ]);

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_empleadoId == null) {
      FluxToast.aviso(context, 'Selecciona un empleado');
      return;
    }

    setState(() => _guardando = true);

    try {
      double descuento = 0;
      if (_tipo == TipoAusencia.ausenciaInjustificada) {
        final empDoc =
            await _db.collection('usuarios').doc(_empleadoId).get();
        final datosNomina =
            empDoc.data()?['datos_nomina'] as Map<String, dynamic>?;
        if (datosNomina != null) {
          final salarioBruto =
              (datosNomina['salario_bruto_anual'] as num?)
                  ?.toDouble() ?? 0;
          final salarioMensual = salarioBruto / 12;
          descuento = VacacionesService.calcularDescuentoAusencia(
            salarioBrutoMensual: salarioMensual,
            diasMes: 30,
            diasAusencia: _diasNaturales,
          );
        }
      }

      if (_empleadoNombre == null) {
        final empDoc =
            await _db.collection('usuarios').doc(_empleadoId).get();
        _empleadoNombre =
            empDoc.data()?['nombre'] as String? ?? 'Empleado';
      }

      final solicitud = SolicitudVacaciones(
        id: '',
        empleadoId: _empleadoId!,
        empresaId: widget.empresaId,
        tipo: _tipo,
        subtipo:
            _tipo == TipoAusencia.permisoRetribuido ? _subtipo : null,
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        diasNaturales: _diasNaturales,
        diasLaborables: _diasLaborables,
        descuentoSalario: descuento,
        fechaCreacion: DateTime.now(),
        empleadoNombre: _empleadoNombre,
      );

      final creada = await _svc.crearSolicitud(widget.empresaId, solicitud);

      try {
        final tipoLabel = _tipo == TipoAusencia.vacaciones
            ? 'vacaciones'
            : _tipo.name.replaceAllMapped(
                RegExp(r'([A-Z])'),
                (m) => ' ${m[1]!.toLowerCase()}');
        await BandejaNotificacionesService().crear(
          empresaId: widget.empresaId,
          titulo: '🏖️ Nueva solicitud de $tipoLabel',
          cuerpo:
              '${_empleadoNombre ?? 'Un empleado'} ha solicitado '
              '$_diasNaturales días (${_fechaInicio.day}/'
              '${_fechaInicio.month} → ${_fechaFin.day}/${_fechaFin.month})',
          tipo: TipoNotificacion.vacacionesSolicitadas,
          entidadId: creada.id,
          remitenteNombre: _empleadoNombre,
        );
      } catch (eNotif) {
        debugPrint('⚠️ Notificación vacaciones: $eNotif');
      }

      if (mounted) {
        FluxToast.exito(context,
            'Solicitud enviada correctamente. Pendiente de aprobación.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al crear la solicitud: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

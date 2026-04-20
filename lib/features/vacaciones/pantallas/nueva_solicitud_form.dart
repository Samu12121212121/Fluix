import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/vacacion_model.dart';
import '../../../models/saldo_vacaciones_model.dart';
import '../../../services/vacaciones_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FORMULARIO NUEVA SOLICITUD DE VACACIONES / AUSENCIA
// ═══════════════════════════════════════════════════════════════════════════════

class NuevaSolicitudForm extends StatefulWidget {
  final String empresaId;
  final String? empleadoIdFijo; // si viene preseleccionado
  final DateTime? fechaInicioFija; // prefill desde el calendario
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 8),
            if (widget.empleadoIdFijo == null) ...[
              _buildSelectorEmpleado(),
              const SizedBox(height: 12),
            ],

            // Saldo actual
            if (_saldoActual != null && _tipo == TipoAusencia.vacaciones) ...[
              _buildSaldoInfo(),
              const SizedBox(height: 12),
            ],

            // Tipo
            DropdownButtonFormField<TipoAusencia>(
              // ignore: deprecated_member_use
              value: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de ausencia',
                border: OutlineInputBorder(),
              ),
              items: TipoAusencia.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.etiqueta),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _tipo = v;
                  if (v == TipoAusencia.permisoRetribuido) {
                    _actualizarFechasPorPermiso();
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            // Subtipo permiso
            if (_tipo == TipoAusencia.permisoRetribuido) ...[
              DropdownButtonFormField<SubtipoPermiso>(
                // ignore: deprecated_member_use
                value: _subtipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de permiso (art. 37 ET)',
                  border: OutlineInputBorder(),
                ),
                items: SubtipoPermiso.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.etiqueta),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _subtipo = v;
                    _actualizarFechasPorPermiso();
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // Fechas
            Row(
              children: [
                Expanded(child: _buildFechaField('Desde', _fechaInicio, true)),
                const SizedBox(width: 12),
                Expanded(child: _buildFechaField('Hasta', _fechaFin, false)),
              ],
            ),
            const SizedBox(height: 12),

            // Resumen días
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoChip('Días naturales', '$_diasNaturales'),
                  _infoChip('Días laborables', '$_diasLaborables'),
                  if (_tipo.descuentaSalario)
                    _infoChip('Descuenta', 'Sí',
                        color: Colors.red),
                ],
              ),
            ),

            // Aviso saldo insuficiente
            if (_tipo == TipoAusencia.vacaciones &&
                _saldoActual != null &&
                _diasNaturales > _saldoActual!.totalDisponible)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saldo insuficiente: disponibles ${_saldoActual!.totalDisponible.toStringAsFixed(1)} días, solicitados $_diasNaturales días',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Notas
            TextFormField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Botón guardar
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_guardando ? 'Enviando...' : 'Enviar solicitud'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSelectorEmpleado() {
    return FutureBuilder<QuerySnapshot>(
      future: _db
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('activo', isEqualTo: true)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }
        final empleados = snap.data!.docs;
        return DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _empleadoId,
          decoration: const InputDecoration(
            labelText: 'Empleado',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v == null ? 'Selecciona un empleado' : null,
          items: empleados
              .map((e) {
                final d = e.data() as Map<String, dynamic>;
                return DropdownMenuItem(
                  value: e.id,
                  child: Text(d['nombre'] as String? ?? 'Sin nombre'),
                );
              })
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            final doc = empleados.firstWhere((e) => e.id == v);
            final d = doc.data() as Map<String, dynamic>;
            setState(() {
              _empleadoId = v;
              _empleadoNombre = d['nombre'] as String? ?? 'Empleado';
            });
            _cargarSaldo();
          },
        );
      },
    );
  }

  Widget _buildSaldoInfo() {
    final s = _saldoActual!;
    final pct = s.diasDevengados > 0
        ? (s.diasDisfrutados / s.diasDevengados).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00796B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vacaciones ${s.anio}: ${s.diasDisfrutados.toStringAsFixed(1)}/${s.diasDevengados.toStringAsFixed(1)} días',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: pct > 0.8 ? Colors.orange : const Color(0xFF00796B),
              minHeight: 8,
            ),
          ),
          Text(
            'Disponibles: ${s.totalDisponible.toStringAsFixed(1)} días'
            '${s.diasPendientesAnoAnterior > 0 ? ' (incl. ${s.diasPendientesAnoAnterior.toStringAsFixed(1)} del año anterior)' : ''}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildFechaField(String label, DateTime value, bool esInicio) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked == null) return;
        setState(() {
          if (esInicio) {
            _fechaInicio = picked;
            if (_fechaFin.isBefore(_fechaInicio)) {
              _fechaFin = _fechaInicio;
            }
          } else {
            _fechaFin = picked;
            if (_fechaFin.isBefore(_fechaInicio)) {
              _fechaInicio = _fechaFin;
            }
          }
        });
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: color ?? const Color(0xFF00796B))),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  void _actualizarFechasPorPermiso() {
    if (_tipo != TipoAusencia.permisoRetribuido) return;
    setState(() {
      _fechaFin = _fechaInicio
          .add(Duration(days: _subtipo.diasMaxDefecto - 1));
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GUARDAR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_empleadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un empleado')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      // Calcular descuento si es ausencia injustificada
      double descuento = 0;
      if (_tipo == TipoAusencia.ausenciaInjustificada) {
        final empDoc =
            await _db.collection('usuarios').doc(_empleadoId).get();
        final datosNomina =
            empDoc.data()?['datos_nomina'] as Map<String, dynamic>?;
        if (datosNomina != null) {
          final salarioBruto =
              (datosNomina['salario_bruto_anual'] as num?)?.toDouble() ??
                  0;
          final salarioMensual = salarioBruto / 12;
          descuento = VacacionesService.calcularDescuentoAusencia(
            salarioBrutoMensual: salarioMensual,
            diasMes: 30,
            diasAusencia: _diasNaturales,
          );
        }
      }

      // Si no tenemos nombre, intentar obtenerlo
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

      await _svc.crearSolicitud(widget.empresaId, solicitud);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud creada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}







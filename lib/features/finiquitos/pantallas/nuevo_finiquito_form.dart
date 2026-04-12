import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/finiquito.dart';
import 'package:planeag_flutter/domain/modelos/nomina.dart';
import 'package:planeag_flutter/services/finiquito_calculator.dart';
import 'package:planeag_flutter/services/finiquito_service.dart';
import 'package:planeag_flutter/services/finiquito_pdf_service.dart';
import 'package:planeag_flutter/services/finiquito_autorellena_service.dart';
import 'package:planeag_flutter/features/finiquitos/pantallas/finiquito_detalle.dart';

// ═════════════════════════════════════════════════════════════════════════════
// FORMULARIO DE NUEVO FINIQUITO
// ═════════════════════════════════════════════════════════════════════════════

class NuevoFiniquitoForm extends StatefulWidget {
  final String empresaId;
  final String? empleadoIdPreseleccionado;

  const NuevoFiniquitoForm({
    super.key,
    required this.empresaId,
    this.empleadoIdPreseleccionado,
  });

  @override
  State<NuevoFiniquitoForm> createState() => _NuevoFiniquitoFormState();
}

class _NuevoFiniquitoFormState extends State<NuevoFiniquitoForm> {
  final _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _svc = FiniquitoService();
  final _autoSvc = FiniquitoAutoRellenaService();

  String? _empleadoId;
  Map<String, dynamic>? _empleadoData;
  DatosAutoFiniquito? _datosAuto;
  DateTime _fechaBaja = DateTime.now();
  CausaBaja _causaBaja = CausaBaja.dimision;
  final _ctrlDiasTrabajados = TextEditingController(text: '0');
  final _ctrlDiasVacDisfrutadas = TextEditingController(text: '0');
  final _ctrlDiasVacConvenio = TextEditingController(text: '30');
  final _ctrlNotas = TextEditingController();

  // ── Estados ──────────────────────────────────────────────────────────────
  Finiquito? _finiquitoCalculado;
  bool _guardando = false;
  bool _cargandoAuto = false;

  final Set<String> _camposModificados = {};

  @override
  void initState() {
    super.initState();
    if (widget.empleadoIdPreseleccionado != null) {
      _cargarEmpleadoConAutoRelleno(widget.empleadoIdPreseleccionado!);
    }
  }

  Future<void> _cargarEmpleadoConAutoRelleno(String id) async {
    setState(() {
      _cargandoAuto = true;
      _empleadoId = id;
    });

    try {
      // Cargar datos básicos del empleado
      final doc = await _db.collection('usuarios').doc(id).get();
      if (!doc.exists) return;

      setState(() {
        _empleadoData = doc.data();
        _empleadoId = id;
      });

      // Intentar auto-rellenar desde nóminas y vacaciones
      try {
        final datosAuto = await _autoSvc.cargarDatosEmpleado(
          widget.empresaId,
          id,
          _fechaBaja,
        );
        if (mounted) {
          setState(() {
            _datosAuto = datosAuto;
            if (!_camposModificados.contains('dias_vac_disfrutadas')) {
              _ctrlDiasVacDisfrutadas.text =
                  datosAuto.diasVacacionesDisfrutados.round().toString();
            }
            if (!_camposModificados.contains('dias_vac_convenio')) {
              _ctrlDiasVacConvenio.text =
                  datosAuto.diasVacacionesConvenio.toString();
            }
            if (!_camposModificados.contains('dias_trabajados') &&
                _fechaBaja.day > 0) {
              _ctrlDiasTrabajados.text = _fechaBaja.day.toString();
            }
          });

          // Mostrar advertencias si las hay
          if (datosAuto.hayAdvertencias && mounted) {
            _mostrarAdvertencias(datosAuto.advertencias);
          }
        }
      } catch (e) {
        debugPrint('Error auto-relleno: $e');
        // Fallback: datos del convenio
        final sector =
            _empleadoData?['datos_nomina']?['sector_empresa'] as String?;
        final convenioId = _resolverConvenio(sector);
        final diasVac =
            FiniquitoCalculator.diasVacacionesPorConvenio[convenioId] ?? 30;
        if (mounted) {
          setState(() => _ctrlDiasVacConvenio.text = diasVac.toString());
        }
      }
    } catch (e) {
      debugPrint('Error cargando empleado: $e');
    } finally {
      if (mounted) setState(() => _cargandoAuto = false);
    }
  }

  void _mostrarAdvertencias(List<String> advertencias) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('Advertencias', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: advertencias
              .map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(a, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _resolverConvenio(String? sector) {
    if (sector == null) return 'hosteleria-guadalajara';
    switch (sector.toLowerCase()) {
      case 'veterinarios':
      case 'veterinaria':
      case 'clinica_veterinaria':
        return 'veterinarios-guadalajara-2026';
      case 'construccion':
      case 'obras_publicas':
      case 'construccion_obras_publicas':
        return 'construccion-obras-publicas-guadalajara';
      default:
        return 'hosteleria-guadalajara';
    }
  }

  void _calcular() {
    if (_empleadoData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un empleado primero')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final datosN = _empleadoData!['datos_nomina'] as Map<String, dynamic>? ?? {};
    final config = DatosNominaEmpleado.fromMap(datosN);
    final nombre = _empleadoData!['nombre'] as String? ?? '';
    final nif = _empleadoData!['nif'] as String?;
    final nss = _empleadoData!['nss'] as String?;

    // Datos empresa
    final sector = datosN['sector_empresa'] as String?;
    final convenioId = _resolverConvenio(sector);

    final finiquito = FiniquitoCalculator.calcular(
      config: config,
      empleadoNombre: nombre,
      empleadoId: _empleadoId!,
      empresaId: widget.empresaId,
      empleadoNif: nif,
      empleadoNss: nss,
      fechaBaja: _fechaBaja,
      causaBaja: _causaBaja,
      diasTrabajadosMes: int.tryParse(_ctrlDiasTrabajados.text) ?? 0,
      diasVacacionesDisfrutadas:
          int.tryParse(_ctrlDiasVacDisfrutadas.text) ?? 0,
      diasVacacionesConvenio: int.tryParse(_ctrlDiasVacConvenio.text) ?? 30,
      convenioId: convenioId,
      notas: _ctrlNotas.text.isNotEmpty ? _ctrlNotas.text : null,
    );

    setState(() => _finiquitoCalculado = finiquito);
  }

  Future<void> _guardar() async {
    if (_finiquitoCalculado == null) return;
    setState(() => _guardando = true);
    try {
      final guardado = await _svc.guardarFiniquito(
          widget.empresaId, _finiquitoCalculado!);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FiniquitoDetalle(
              finiquito: guardado,
              empresaId: widget.empresaId,
            ),
          ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Nuevo finiquito'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Selector de empleado ──────────────────────────────────────
              _buildSelectorEmpleado(),
              const SizedBox(height: 16),

              // ── Datos del finiquito ───────────────────────────────────────
              _buildCardDatos(),
              const SizedBox(height: 16),

              // ── Botón calcular ────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _calcular,
                icon: const Icon(Icons.calculate),
                label: const Text('Calcular finiquito'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_finiquitoCalculado != null) ...[
                const SizedBox(height: 16),
                _buildResultado(_finiquitoCalculado!),
                const SizedBox(height: 16),
                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: const Text('Guardar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => FiniquitoPdfService.generarYCompartir(
                            context, _finiquitoCalculado!),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Generar PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSelectorEmpleado() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Empleado',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            if (_cargandoAuto)
              _buildSkeletonLoader()
            else if (_empleadoData != null)
              _buildEmpleadoSeleccionado()
            else
              _buildBuscadorEmpleado(),

            // Banner de datos auto-cargados
            if (_datosAuto != null && !_cargandoAuto) ...[
              const SizedBox(height: 10),
              _buildBannerAutoRelleno(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpleadoSeleccionado() {
    final nombre = _empleadoData?['nombre'] as String? ?? 'Empleado';
    final datosN =
        _empleadoData?['datos_nomina'] as Map<String, dynamic>? ?? {};
    final salario =
        (datosN['salario_bruto_anual'] as num?)?.toDouble() ?? 0;
    final inicio = datosN['fecha_inicio_contrato'];
    String fechaStr = '—';
    if (inicio is Timestamp) {
      final d = inicio.toDate();
      fechaStr = _fmtDate(d);
    } else if (inicio is String) {
      fechaStr = inicio;
    }

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Text(nombre.isNotEmpty ? nombre[0] : '?',
              style: TextStyle(color: Colors.indigo.shade700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                  'Salario: ${salario.toStringAsFixed(0)} €/año · Inicio: $fechaStr',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => setState(() {
            _empleadoId = null;
            _empleadoData = null;
            _datosAuto = null;
            _finiquitoCalculado = null;
          }),
        ),
      ],
    );
  }

  Widget _buildBuscadorEmpleado() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final empleados = snap.data!.docs;
        if (empleados.isEmpty) {
          return const Text('No hay empleados activos');
        }
        return Column(
          children: empleados.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] as String? ?? 'Empleado';
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo.shade50,
                child: Text(nombre.isNotEmpty ? nombre[0] : '?',
                    style: TextStyle(
                        fontSize: 12, color: Colors.indigo.shade700)),
              ),
              title: Text(nombre, style: const TextStyle(fontSize: 14)),
              onTap: () => _cargarEmpleadoConAutoRelleno(doc.id),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(
                  height: 12,
                  width: 200,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4))),
            ],
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const SizedBox(width: 16),
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text('Cargando datos automáticamente...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
      ],
    );
  }

  Widget _buildBannerAutoRelleno() {
    final d = _datosAuto!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Text('Datos cargados automáticamente',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          _miniFila('Salario mensual',
              '${d.salarioBrutoMensual.toStringAsFixed(2)} €'),
          _miniFila(
              'Salario diario', '${d.salarioDiario.toStringAsFixed(2)} €'),
          _miniFila('Vac. pendientes',
              '${d.diasVacacionesPendientes.toStringAsFixed(1)} días',
              color: Colors.blue.shade700),
          if (d.ultimaNominaId != null)
            _miniFila('Última nómina',
                '${_nombreMes(d.ultimaNominaMes ?? 0)} ${d.ultimaNominaAnio}'),
        ],
      ),
    );
  }

  Widget _miniFila(String label, String valor, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ),
        Text(valor,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87)),
      ]),
    );
  }

  static String _nombreMes(int m) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return (m >= 1 && m <= 12) ? meses[m] : '—';
  }

  Widget _buildCardDatos() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Datos del finiquito',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 14),

            // Fecha de baja
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event, color: Colors.indigo),
              title: Text('Fecha de baja: ${_fmtDate(_fechaBaja)}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fechaBaja,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _fechaBaja = d);
              },
            ),
            const Divider(),

            // Causa de baja
            DropdownButtonFormField<CausaBaja>(
              value: _causaBaja,
              decoration: const InputDecoration(
                labelText: 'Causa de baja',
                prefixIcon: Icon(Icons.gavel),
                border: OutlineInputBorder(),
              ),
              items: CausaBaja.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.etiqueta,
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _causaBaja = v;
                    _finiquitoCalculado = null;
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Días trabajados en el mes
            TextFormField(
              controller: _ctrlDiasTrabajados,
              decoration: const InputDecoration(
                labelText: 'Días trabajados en el mes de baja',
                prefixIcon: Icon(Icons.work),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _camposModificados.add('dias_trabajados'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0 || n > 31) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Vacaciones disfrutadas
            TextFormField(
              controller: _ctrlDiasVacDisfrutadas,
              decoration: const InputDecoration(
                labelText: 'Días de vacaciones disfrutadas este año',
                prefixIcon: Icon(Icons.beach_access),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) =>
                  _camposModificados.add('dias_vac_disfrutadas'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Vacaciones del convenio
            TextFormField(
              controller: _ctrlDiasVacConvenio,
              decoration: const InputDecoration(
                labelText: 'Días vacaciones/año (convenio)',
                prefixIcon: Icon(Icons.sunny),
                border: OutlineInputBorder(),
                helperText: 'Mínimo legal 30 días naturales',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _camposModificados.add('dias_vac_convenio'),
            ),
            const SizedBox(height: 14),

            // Notas
            TextFormField(
              controller: _ctrlNotas,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado(Finiquito f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resultado del cálculo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Divider(),
            _lineaDesglose(
                'Salario pendiente (${f.diasTrabajadosMes} días)',
                f.salarioPendiente),
            _lineaDesglose(
                'Vacaciones pendientes (${f.diasVacacionesPendientes} días)',
                f.importeVacaciones),
            _lineaDesglose('Prorrata pagas extra', f.totalProrrataPagas),
            if (f.indemnizacion > 0) ...[
              _lineaDesglose('Indemnización', f.indemnizacion),
              const Divider(),
              if (f.indemnizacionExenta > 0)
                _lineaDesglose('  · Exenta IRPF', f.indemnizacionExenta,
                    color: Colors.green.shade600, fontSize: 12),
              if (f.indemnizacionSujeta > 0)
                _lineaDesglose('  · Sujeta IRPF', f.indemnizacionSujeta,
                    color: Colors.red.shade600, fontSize: 12),
            ],
            _lineaDesglose('TOTAL BRUTO', f.totalBruto,
                bold: true, color: Colors.indigo),
            const Divider(),
            _lineaDesglose(
                '(-) IRPF (${f.porcentajeIrpf.toStringAsFixed(2)}%)',
                -f.importeIrpf,
                color: Colors.red),
            _lineaDesglose('(-) SS trabajador', -f.cuotaObreraSSFiniquito,
                color: Colors.red),
            const Divider(thickness: 2),
            _lineaDesglose('LÍQUIDO A PERCIBIR', f.liquidoPercibir,
                bold: true, fontSize: 17, color: Colors.green.shade700),
          ],
        ),
      ),
    );
  }

  Widget _lineaDesglose(String label, double valor, {
    bool bold = false,
    double fontSize = 13,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: color,
                )),
          ),
          Text(
            '${valor.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void dispose() {
    _ctrlDiasTrabajados.dispose();
    _ctrlDiasVacDisfrutadas.dispose();
    _ctrlDiasVacConvenio.dispose();
    _ctrlNotas.dispose();
    super.dispose();
  }
}




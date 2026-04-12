import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../domain/modelos/convenio_colectivo.dart';
import '../../../services/nominas_service.dart';
import '../../../services/sepa_xml_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO DATOS NÓMINA
// ─────────────────────────────────────────────────────────────────────────────

class FormularioDatosNomina extends StatefulWidget {
  final String empleadoId;
  final String empleadoNombre;
  final Map<String, dynamic>? datosActuales;
  final List<CategoriaConvenio> categoriasConvenio;

  const FormularioDatosNomina({
    super.key,
    required this.empleadoId,
    required this.empleadoNombre,
    this.datosActuales,
    this.categoriasConvenio = const [],
  });

  @override
  State<FormularioDatosNomina> createState() => _FormularioDatosNominaState();
}

class _FormularioDatosNominaState extends State<FormularioDatosNomina>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabCtrl;

  late TextEditingController _nifCtrl;
  late TextEditingController _nssCtrl;
  late TextEditingController _ibanCtrl;
  late TextEditingController _fechaNacCtrl;
  late TextEditingController _salarioCtrl;
  late TextEditingController _complementoFijoCtrl;
  late TextEditingController _irpfPctCtrl;
  late TextEditingController _otrasRentasCtrl;
  late TextEditingController _horasCtrl;
  late TextEditingController _retrEspecieCtrl;
  late TextEditingController _hijosCtrl;
  late TextEditingController _hijosMenoresCtrl;
  late TextEditingController _pctDiscapacidadCtrl;
  late TextEditingController _antiguedadManualImporteCtrl;
  late TextEditingController _nivelCarnicasCtrl;
  late Map<String, TextEditingController> _plusesCtrls;

  EstadoCivil _estadoCivil = EstadoCivil.soltero;
  TipoContrato _tipoContrato = TipoContrato.indefinido;
  String? _categoriaConvenioSeleccionada;
  DateTime? _fechaNacimiento;
  int _numHijos = 0;
  int _numHijosMenores3 = 0;
  double _pctDiscapacidad = 33.0;
  bool _discapacidad = false;
  bool _guardando = false;
  bool _prorrateoPagas = true;
  bool _antiguedadManual = false;
  int _numPagas = 12;
  GrupoCotizacion _grupoCotizacion = GrupoCotizacion.grupo7;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final d = widget.datosActuales;
    _nifCtrl = TextEditingController(text: d?['nif'] ?? '');
    _nssCtrl = TextEditingController(text: d?['nss'] ?? '');
    _ibanCtrl = TextEditingController(text: d?['cuenta_bancaria'] ?? '');
    _fechaNacCtrl = TextEditingController();
    _salarioCtrl = TextEditingController(text: (d?['salario_bruto_anual'] ?? '').toString());
    _complementoFijoCtrl = TextEditingController(
        text: ((d?['complemento_fijo'] as num?)?.toDouble() ?? 0).toString());
    _irpfPctCtrl = TextEditingController(
        text: ((d?['irpf_porcentaje'] as num?) ?? 15.0).toString());
    _otrasRentasCtrl = TextEditingController(
        text: ((d?['otras_rentas'] as num?)?.toDouble() ?? 0).toString());
    _horasCtrl = TextEditingController(
        text: ((d?['horas_semanales'] as num?)?.toDouble() ?? 40).toString());
    _retrEspecieCtrl = TextEditingController(
        text: ((d?['retribuciones_especie'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2));
    _hijosCtrl = TextEditingController(
        text: ((d?['num_hijos'] as num?)?.toInt() ?? 0).toString());
    _hijosMenoresCtrl = TextEditingController(
        text: ((d?['num_hijos_menores_3'] as num?)?.toInt() ?? 0).toString());
    _pctDiscapacidadCtrl = TextEditingController(
        text: ((d?['porcentaje_discapacidad'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));

    _estadoCivil = EstadoCivil.values.firstWhere(
        (e) => e.name == (d?['estado_civil'] as String?),
        orElse: () => EstadoCivil.soltero);
    _discapacidad = d?['discapacidad'] as bool? ?? false;
    _pctDiscapacidad = (d?['porcentaje_discapacidad'] as num?)?.toDouble() ?? 0;
    _numHijos = (d?['num_hijos'] as num?)?.toInt() ?? 0;
    _numHijosMenores3 = (d?['num_hijos_menores_3'] as num?)?.toInt() ?? 0;
    _prorrateoPagas = d?['pagas_prorrateadas'] as bool? ?? true;
    _numPagas = (d?['num_pagas'] as num?)?.toInt() ?? 12;
    _antiguedadManual = d?['antiguedad_manual'] as bool? ?? false;
    _antiguedadManualImporteCtrl = TextEditingController(
        text: ((d?['antiguedad_manual_importe'] as num?)?.toDouble() ?? 0).toString());
    _nivelCarnicasCtrl = TextEditingController(
        text: ((d?['nivel_categoria_carnicas'] as num?)?.toInt() ?? 5).toString());

    final fechaNacRaw = d?['fecha_nacimiento'];
    if (fechaNacRaw is Timestamp) {
      _fechaNacimiento = fechaNacRaw.toDate();
    } else if (fechaNacRaw is String) {
      _fechaNacimiento = DateTime.tryParse(fechaNacRaw);
    } else if (fechaNacRaw is DateTime) {
      _fechaNacimiento = fechaNacRaw;
    }
    if (_fechaNacimiento != null) {
      _fechaNacCtrl.text = _formatearFecha(_fechaNacimiento!);
    }

    final gcRaw = d?['grupo_cotizacion'] as String?;
    if (gcRaw != null) {
      _grupoCotizacion = GrupoCotizacion.values.firstWhere(
          (g) => g.name == gcRaw, orElse: () => GrupoCotizacion.grupo7);
    }

    _categoriaConvenioSeleccionada = d?['categoria_convenio_id'] as String?;
    _tipoContrato = _parseTipoContrato(d?['tipo_contrato']);

    final Map<String, dynamic> plusesPrevios =
        (d?['pluses_variables'] as Map<String, dynamic>?) ?? {};
    _plusesCtrls = {
      'festivos': TextEditingController(text: (plusesPrevios['festivos'] ?? '').toString()),
      'apertura_domingos': TextEditingController(text: (plusesPrevios['apertura_domingos'] ?? '').toString()),
      'dietas': TextEditingController(text: (plusesPrevios['dietas'] ?? '').toString()),
      'media_dieta': TextEditingController(text: (plusesPrevios['media_dieta'] ?? '').toString()),
      'horas_extra': TextEditingController(text: (plusesPrevios['horas_extra'] ?? '').toString()),
    };
  }

  TipoContrato _parseTipoContrato(dynamic raw) {
    final s = raw as String?;
    return TipoContrato.values.firstWhere(
        (e) => e.name == s, orElse: () => TipoContrato.indefinido);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nifCtrl.dispose();
    _nssCtrl.dispose();
    _ibanCtrl.dispose();
    _fechaNacCtrl.dispose();
    _otrasRentasCtrl.dispose();
    _horasCtrl.dispose();
    _salarioCtrl.dispose();
    _complementoFijoCtrl.dispose();
    _irpfPctCtrl.dispose();
    _retrEspecieCtrl.dispose();
    _hijosCtrl.dispose();
    _hijosMenoresCtrl.dispose();
    _pctDiscapacidadCtrl.dispose();
    _antiguedadManualImporteCtrl.dispose();
    _nivelCarnicasCtrl.dispose();
    for (final c in _plusesCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final salario = double.tryParse(_salarioCtrl.text) ?? 0;
    final irpf = double.tryParse(_irpfPctCtrl.text) ?? 15.0;
    _numHijos = int.tryParse(_hijosCtrl.text) ?? 0;
    _numHijosMenores3 = int.tryParse(_hijosMenoresCtrl.text) ?? 0;
    _pctDiscapacidad = double.tryParse(_pctDiscapacidadCtrl.text) ?? _pctDiscapacidad;

    final Map<String, double> plusesVariables = {};
    _plusesCtrls.forEach((k, ctrl) {
      final v = double.tryParse(ctrl.text.trim());
      if (v != null && v > 0) plusesVariables[k] = v;
    });

    double? minimoConvenio;
    if (_categoriaConvenioSeleccionada != null) {
      try {
        final cat = widget.categoriasConvenio
            .firstWhere((c) => c.id == _categoriaConvenioSeleccionada);
        minimoConvenio = cat.salarioAnual;
        _numPagas = cat.numPagas;
      } catch (_) {}
    }
    const smiAnual2026 = 15876.0;
    final minimo = [smiAnual2026, minimoConvenio ?? 0].reduce((a, b) => a > b ? a : b);
    if (salario < minimo) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'El salario anual (${salario.toStringAsFixed(2)}) está por debajo del mínimo '
            '(SMI/convenio: ${minimo.toStringAsFixed(2)}). Corrige para guardar.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final datos = {
      'salario_bruto_anual': salario,
      'irpf_porcentaje': irpf,
      'nif': _nifCtrl.text.trim(),
      'nss': _nssCtrl.text.trim(),
      'cuenta_bancaria': _ibanCtrl.text.trim(),
      if (_fechaNacimiento != null) 'fecha_nacimiento': _fechaNacimiento!.toIso8601String(),
      'estado_civil': _estadoCivil.name,
      'num_hijos': _numHijos,
      'num_hijos_menores_3': _numHijosMenores3,
      'discapacidad': _discapacidad,
      'porcentaje_discapacidad': _pctDiscapacidad,
      'otras_rentas': double.tryParse(_otrasRentasCtrl.text) ?? 0,
      'horas_semanales': double.tryParse(_horasCtrl.text) ?? 40,
      'retribuciones_especie': double.tryParse(_retrEspecieCtrl.text) ?? 0,
      'complemento_fijo': double.tryParse(_complementoFijoCtrl.text) ?? 0,
      'num_pagas': _numPagas,
      'prorrateo_pagas_extras': _prorrateoPagas,
      'pagas_prorrateadas': _prorrateoPagas,
      'tipo_contrato': _tipoContrato.name,
      'grupo_cotizacion': _grupoCotizacion.name,
      'categoria_convenio_id': _categoriaConvenioSeleccionada,
      'antiguedad_manual': _antiguedadManual,
      'antiguedad_manual_importe': double.tryParse(_antiguedadManualImporteCtrl.text) ?? 0,
      'nivel_categoria_carnicas': int.tryParse(_nivelCarnicasCtrl.text) ?? 5,
      if (plusesVariables.isNotEmpty) 'pluses_variables': plusesVariables,
    };

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(widget.empleadoId).update({
        'datos_nomina': datos,
        'fecha_actualizacion_nomina': DateTime.now(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Datos de nómina guardados'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 8, right: 8, top: 8),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const TabBar(
                  labelColor: Color(0xFF0D47A1),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF0D47A1),
                  tabs: [
                    Tab(text: 'Personal y Contrato', icon: Icon(Icons.person)),
                    Tab(text: 'Salario y Cotización', icon: Icon(Icons.euro)),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: TabBarView(
                    children: [
                      _tabPersonal(),
                      _tabSalario(),
                    ],
                  ),
                ),
                _buildGuardar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabPersonal() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCampoTexto(_nifCtrl, 'NIF / NIE', 'Documento de identidad', Icons.badge),
        const SizedBox(height: 16),
        _buildCampoTexto(_nssCtrl, 'Nº Seguridad Social', 'Ej: 28/1234567890/12',
            Icons.health_and_safety),
        const SizedBox(height: 16),
        _buildCampoIBAN(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _fechaNacCtrl,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Fecha de nacimiento',
            hintText: 'YYYY-MM-DD',
            prefixIcon: const Icon(Icons.cake, color: Color(0xFF1976D2)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onTap: _pickFechaNacimiento,
        ),
        const SizedBox(height: 16),
        _buildDropdown<EstadoCivil>(
          'Estado civil', EstadoCivil.values, _estadoCivil,
          (v) => setState(() => _estadoCivil = v ?? EstadoCivil.soltero),
          (v) => v.etiqueta, Icons.family_restroom,
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildCampoTexto(_hijosCtrl, 'Hijos a cargo', '0', Icons.child_care, numerico: true)),
          const SizedBox(width: 12),
          Expanded(child: _buildCampoTexto(_hijosMenoresCtrl, 'Hijos < 3 años', '0', Icons.baby_changing_station, numerico: true)),
        ]),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Discapacidad reconocida'),
          value: _discapacidad,
          onChanged: (v) => setState(() => _discapacidad = v),
        ),
        if (_discapacidad) ...[
          const SizedBox(height: 8),
          _buildCampoTexto(_pctDiscapacidadCtrl, 'Porcentaje discapacidad', 'Ej: 33', Icons.percent, numerico: true),
        ],
        const SizedBox(height: 16),
        _buildDropdown<TipoContrato>(
          'Tipo de Contrato', TipoContrato.values, _tipoContrato,
          (v) => setState(() => _tipoContrato = v!),
          (v) => v.etiqueta, Icons.article,
        ),
        if (widget.categoriasConvenio.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDropdown<String>(
            'Categoría Convenio',
            widget.categoriasConvenio.map((c) => c.id).toList(),
            _categoriaConvenioSeleccionada,
            (v) {
              setState(() {
                _categoriaConvenioSeleccionada = v;
                if (v != null) {
                  try {
                    final categoria = widget.categoriasConvenio.firstWhere((c) => c.id == v);
                    _numPagas = categoria.numPagas > 0 ? categoria.numPagas : 14;
                    if (!categoria.salarioLibre) {
                      _salarioCtrl.text = categoria.salarioAnual.toString();
                    }
                  } catch (_) {}
                }
              });
            },
            (v) {
              try { return widget.categoriasConvenio.firstWhere((c) => c.id == v).nombre; }
              catch (_) { return v; }
            },
            Icons.category,
          ),
          if (_categoriaConvenioSeleccionada != null)
            Builder(builder: (_) {
              final cat = widget.categoriasConvenio.cast<CategoriaConvenio?>()
                  .firstWhere((c) => c?.id == _categoriaConvenioSeleccionada, orElse: () => null);
              if (cat != null && (cat.salarioLibre || (cat.nota?.isNotEmpty ?? false))) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(child: Text(cat.nota ?? 'Salario libre según convenio',
                          style: const TextStyle(fontSize: 12))),
                    ]),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildCampoTexto(_salarioCtrl, 'Salario bruto anual (€)', 'Ej: 20000', Icons.euro, numerico: true)),
          const SizedBox(width: 12),
          Expanded(child: _buildCampoTexto(_horasCtrl, 'Horas semanales', 'Ej: 40', Icons.timer, numerico: true)),
        ]),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Prorratear pagas extra'),
          value: _prorrateoPagas,
          onChanged: (v) => setState(() => _prorrateoPagas = v),
        ),
      ],
    );
  }

  Widget _tabSalario() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCampoTexto(_irpfPctCtrl, 'Retención IRPF (%)', 'Ej: 15', Icons.percent, numerico: true),
        const SizedBox(height: 16),
        _buildCampoTexto(_otrasRentasCtrl, 'Otras rentas anuales (€)', 'Ej: 0', Icons.savings, numerico: true),
        const SizedBox(height: 16),
        _buildDropdown<GrupoCotizacion>(
          'Grupo de Cotización', GrupoCotizacion.values, _grupoCotizacion,
          (v) => setState(() => _grupoCotizacion = v!),
          (v) => '${v.index + 1} - ${v.etiquetaCorta}', Icons.groups,
        ),
        const SizedBox(height: 16),
        _buildCampoTexto(_complementoFijoCtrl, 'Complemento fijo anual', 'Ej: 1200', Icons.add_card, numerico: true),
        const SizedBox(height: 16),
        _buildCampoTexto(_retrEspecieCtrl, 'Retribuciones en especie (€/mes)', 'Ej: 0', Icons.card_giftcard, numerico: true),
        const SizedBox(height: 16),
        // Antigüedad
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF5D4037).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF5D4037).withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.workspace_premium, size: 18, color: Color(0xFF5D4037)),
                SizedBox(width: 6),
                Text('Antigüedad', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cálculo manual', style: TextStyle(fontSize: 13)),
                subtitle: const Text('Sobreescribe el cálculo automático por convenio',
                    style: TextStyle(fontSize: 11)),
                value: _antiguedadManual,
                onChanged: (v) => setState(() => _antiguedadManual = v),
              ),
              if (_antiguedadManual)
                _buildCampoTexto(_antiguedadManualImporteCtrl, 'Importe manual (€/mes)', 'Ej: 120',
                    Icons.edit, numerico: true),
              const SizedBox(height: 8),
              _buildCampoTexto(_nivelCarnicasCtrl, 'Nivel cárnicas (1-6)', '5', Icons.factory, numerico: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _cardPlusesVariables(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Estimación mensual',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0D47A1))),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _kpi('Salario base', '€${_calcularSalarioMensual().toStringAsFixed(2)}'),
                _kpi('IRPF estimado', '${_calcularPctIrpf().toStringAsFixed(1)}%'),
              ],
            ),
          ]),
        ),
      ],
    );
  }

  Widget _cardPlusesVariables() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pluses variables (unidades mes)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _buildCampoTexto(_plusesCtrls['festivos']!, 'Festivos trabajados', 'Ej: 2', Icons.event, numerico: true),
          const SizedBox(height: 8),
          _buildCampoTexto(_plusesCtrls['apertura_domingos']!, 'Domingos trabajados', 'Ej: 1', Icons.calendar_today, numerico: true),
          const SizedBox(height: 8),
          _buildCampoTexto(_plusesCtrls['dietas']!, 'Dietas (días)', 'Ej: 3', Icons.lunch_dining, numerico: true),
          const SizedBox(height: 8),
          _buildCampoTexto(_plusesCtrls['media_dieta']!, 'Media dieta (días)', 'Ej: 1', Icons.fastfood, numerico: true),
          const SizedBox(height: 8),
          _buildCampoTexto(_plusesCtrls['horas_extra']!, 'Horas extra (unid.)', 'Ej: 4', Icons.timer, numerico: true),
        ],
      ),
    );
  }

  double _calcularSalarioMensual() {
    final bruto = double.tryParse(_salarioCtrl.text) ?? 0;
    if (!_prorrateoPagas) return _numPagas > 0 ? bruto / _numPagas : bruto;
    return bruto / 12;
  }

  double _calcularPctIrpf() {
    final bruto = double.tryParse(_salarioCtrl.text) ?? 0;
    final tempCfg = DatosNominaEmpleado(
      salarioBrutoAnual: bruto,
      numPagas: _numPagas,
      pagasProrrateadas: _prorrateoPagas,
      fechaNacimiento: _fechaNacimiento,
      estadoCivil: _estadoCivil,
      numHijos: _numHijos,
      numHijosMenores3: _numHijosMenores3,
      discapacidad: _discapacidad,
      porcentajeDiscapacidad: _pctDiscapacidad,
      otrasRentas: double.tryParse(_otrasRentasCtrl.text) ?? 0,
      horasSemanales: double.tryParse(_horasCtrl.text) ?? 40,
      retribucionesEspecie: double.tryParse(_retrEspecieCtrl.text) ?? 0,
    );
    final nacimiento = _fechaNacimiento;
    final edad = nacimiento != null ? DateTime.now().year - nacimiento.year : null;
    return bruto > 0
        ? NominasService.calcularPorcentajeIrpf(bruto, config: tempCfg, edadEmpleado: edad)
        : 0.0;
  }

  String _formatearFecha(DateTime f) =>
      '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  Future<void> _pickFechaNacimiento() async {
    final ahora = DateTime.now();
    final inicial = _fechaNacimiento ?? DateTime(1990, 1, 1);
    final elegido = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(ahora) ? ahora : inicial,
      firstDate: DateTime(1940),
      lastDate: ahora,
    );
    if (elegido != null) {
      setState(() {
        _fechaNacimiento = elegido;
        _fechaNacCtrl.text = _formatearFecha(elegido);
      });
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Datos de Nómina',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoTexto(TextEditingController ctrl, String label,
      String helper, IconData icono, {bool numerico = false}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: helper,
        prefixIcon: Icon(icono, color: const Color(0xFF1976D2)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: numerico
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Obligatorio';
        if (numerico && double.tryParse(v) == null) return 'Número inválido';
        return null;
      },
    );
  }

  Widget _buildCampoIBAN() {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final texto = _ibanCtrl.text.trim();
        final String? error;
        final bool valido;
        if (texto.isEmpty) {
          error = null;
          valido = false;
        } else {
          error = SepaXmlGenerator.validarIBAN(texto);
          valido = error == null;
        }
        return TextFormField(
          controller: _ibanCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Cuenta Bancaria (IBAN)',
            hintText: 'ES12 1234 1234 1234 1234 1234',
            prefixIcon: Icon(Icons.account_balance,
                color: texto.isEmpty ? const Color(0xFF1976D2) : (valido ? Colors.green : Colors.red)),
            suffixIcon: texto.isEmpty
                ? null
                : Icon(valido ? Icons.check_circle : Icons.error,
                    color: valido ? Colors.green : Colors.red, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: texto.isEmpty ? Colors.grey[50] : (valido ? Colors.green.withValues(alpha: 0.04) : Colors.red.withValues(alpha: 0.04)),
            helperText: valido ? '✅ IBAN válido — ${SepaXmlGenerator.formatearIBAN(texto)}' : null,
            helperStyle: const TextStyle(color: Colors.green, fontSize: 11),
            errorText: (texto.isNotEmpty && !valido) ? error : null,
          ),
          onChanged: (_) => setLocalState(() {}),
          onEditingComplete: () {
            if (_ibanCtrl.text.trim().isNotEmpty) {
              final formatted = SepaXmlGenerator.formatearIBAN(_ibanCtrl.text);
              _ibanCtrl.text = formatted;
              _ibanCtrl.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
            }
            setLocalState(() {});
            FocusScope.of(context).nextFocus();
          },
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'IBAN obligatorio';
            return SepaXmlGenerator.validarIBAN(v);
          },
        );
      },
    );
  }

  Widget _buildDropdown<T>(String label, List<T> items, T? valor,
      void Function(T?) onChanged, String Function(T) itemLabel, IconData icon,
      {List<DropdownMenuItem<T>>? opciones}) {
    return DropdownButtonFormField<T>(
      value: valor,
      items: opciones ??
          items.map((i) => DropdownMenuItem(value: i, child: Text(itemLabel(i)))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildGuardar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _guardando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(_guardando ? 'Guardando...' : 'Guardar datos de nómina',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _kpi(String label, String valor) => Column(children: [
        Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ]);
}



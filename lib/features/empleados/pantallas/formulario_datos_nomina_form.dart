import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../domain/modelos/convenio_colectivo.dart';
import '../../../services/nominas_service.dart';
import '../../../services/sepa_xml_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colores consistentes con el sistema de diseño
// ─────────────────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF3B82F6);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF8F9FA);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kOrange = Color(0xFFF59E0B);

// ─────────────────────────────────────────────────────────────────────────────
// Config de un plus variable
// ─────────────────────────────────────────────────────────────────────────────
class _PlusConfig {
  final String key;
  final String label;
  final IconData icon;
  final String hint;
  const _PlusConfig(this.key, this.label, this.icon, this.hint);
}

// Pluses por sector — se cargan dinámicamente según el convenio
const Map<String, List<_PlusConfig>> _kPlusesSector = {
  'hosteleria': [
    _PlusConfig('festivos',          'Festivos trabajados',      Icons.event_rounded,         'Ej: 2'),
    _PlusConfig('apertura_domingos', 'Domingos trabajados',      Icons.calendar_today_rounded,'Ej: 1'),
    _PlusConfig('nocturnidad',       'Noches trabajadas',        Icons.nightlight_round,      'Ej: 4'),
    _PlusConfig('dietas',            'Dietas (días)',             Icons.lunch_dining,          'Ej: 3'),
    _PlusConfig('media_dieta',       'Media dieta (días)',        Icons.fastfood,              'Ej: 1'),
    _PlusConfig('horas_extra',       'Horas extra',              Icons.timer_rounded,         'Ej: 4'),
  ],
  'comercio': [
    _PlusConfig('horas_extra',       'Horas extra',              Icons.timer_rounded,         'Ej: 4'),
    _PlusConfig('festivos',          'Festivos trabajados',      Icons.event_rounded,         'Ej: 2'),
    _PlusConfig('apertura_domingos', 'Domingos trabajados',      Icons.calendar_today_rounded,'Ej: 1'),
    _PlusConfig('incentivos_venta',  'Incentivos venta (€)',     Icons.trending_up_rounded,   'Ej: 150'),
  ],
  'peluqueria': [
    _PlusConfig('horas_extra',       'Horas extra',              Icons.timer_rounded,         'Ej: 4'),
    _PlusConfig('festivos',          'Festivos trabajados',      Icons.event_rounded,         'Ej: 2'),
    _PlusConfig('plus_clientela',    'Plus clientela (€/mes)',   Icons.people_rounded,        'Ej: 80'),
  ],
  'carnicas': [
    _PlusConfig('horas_extra',       'Horas extra',              Icons.timer_rounded,         'Ej: 4'),
    _PlusConfig('plus_asistencia',   'Plus asistencia (días)',   Icons.check_circle_outline,  'Ej: 20'),
    _PlusConfig('plus_productividad','Plus productividad (€)',   Icons.speed_rounded,         'Ej: 100'),
    _PlusConfig('nocturnidad',       'Noches trabajadas',        Icons.nightlight_round,      'Ej: 2'),
  ],
  'veterinarios': [
    _PlusConfig('horas_extra',       'Horas extra',              Icons.timer_rounded,         'Ej: 4'),
    _PlusConfig('guardia_localizada','Guardias localizadas',     Icons.phone_in_talk_rounded, 'Ej: 3'),
    _PlusConfig('festivos',          'Festivos trabajados',      Icons.event_rounded,         'Ej: 2'),
  ],
  'construccion': [
    _PlusConfig('horas_extra',       'Horas extra',              Icons.timer_rounded,         'Ej: 4'),
    _PlusConfig('plus_distancia',    'Desplazamiento (días)',    Icons.directions_car_rounded,'Ej: 10'),
    _PlusConfig('dietas',            'Dietas (días)',             Icons.lunch_dining,          'Ej: 3'),
    _PlusConfig('plus_herramientas', 'Plus herramientas (€)',    Icons.build_rounded,         'Ej: 50'),
    _PlusConfig('festivos',          'Festivos trabajados',      Icons.event_rounded,         'Ej: 2'),
  ],
  '_default': [
    _PlusConfig('horas_extra',       'Horas extra',              Icons.timer_rounded,         'Ej: 4'),
    _PlusConfig('dietas',            'Dietas (días)',             Icons.lunch_dining,          'Ej: 3'),
    _PlusConfig('festivos',          'Festivos trabajados',      Icons.event_rounded,         'Ej: 2'),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// IBAN formatter
// ─────────────────────────────────────────────────────────────────────────────
class _IBANFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final clean = newValue.text
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final limited = clean.length > 24 ? clean.substring(0, 24) : clean;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMI — actualizar anualmente
// ─────────────────────────────────────────────────────────────────────────────
const double _kSmiAnual = 15876.0; // SMI 2026

// ═════════════════════════════════════════════════════════════════════════════
// FORMULARIO DATOS NÓMINA
// ═════════════════════════════════════════════════════════════════════════════
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

  // Pluses dinámicos por sector
  late Map<String, TextEditingController> _plusesCtrls;

  EstadoCivil _estadoCivil     = EstadoCivil.soltero;
  TipoContrato _tipoContrato   = TipoContrato.indefinido;
  String? _categoriaConvenioSeleccionada;
  DateTime? _fechaNacimiento;
  int  _numHijos          = 0;
  bool _guardando         = false;
  double _pctDiscapacidad = 0.0;
  bool _discapacidad      = false;
  int  _numHijosMenores3  = 0;
  bool _prorrateoPagas    = true;
  bool _antiguedadManual  = false;
  int  _numPagas          = 12;
  GrupoCotizacion _grupoCotizacion = GrupoCotizacion.grupo7;

  // ── Sector detectado desde el convenio ─────────────────────────────────────
  String get _sectorActual {
    if (widget.categoriasConvenio.isEmpty) return '_default';
    final id = widget.categoriasConvenio.first.id.toLowerCase();
    if (id.contains('hosteleria') || id.contains('hostelería')) return 'hosteleria';
    if (id.contains('comercio'))                                 return 'comercio';
    if (id.contains('peluqueria') || id.contains('estetica') ||
        id.contains('gimnasio'))                                 return 'peluqueria';
    if (id.contains('carnic'))                                   return 'carnicas';
    if (id.contains('veterinar'))                                return 'veterinarios';
    if (id.contains('construcci') || id.contains('obras'))       return 'construccion';
    return '_default';
  }

  List<_PlusConfig> get _plusesDelSector =>
      _kPlusesSector[_sectorActual] ?? _kPlusesSector['_default']!;

  bool get _esSectorCarnicas => _sectorActual == 'carnicas';

  // ── Init ────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final d = widget.datosActuales;

    _nifCtrl      = TextEditingController(text: d?['nif'] ?? '');
    _nssCtrl      = TextEditingController(text: d?['nss'] ?? '');
    _ibanCtrl     = TextEditingController(text: d?['cuenta_bancaria'] ?? '');
    _fechaNacCtrl = TextEditingController();
    _salarioCtrl  = TextEditingController(
        text: (d?['salario_bruto_anual'] ?? '').toString());
    _complementoFijoCtrl = TextEditingController(
        text: ((d?['complemento_fijo'] as num?)?.toDouble() ?? 0).toString());
    _irpfPctCtrl = TextEditingController(
        text: ((d?['irpf_porcentaje'] as num?) ?? 15.0).toString());
    _otrasRentasCtrl = TextEditingController(
        text: ((d?['otras_rentas'] as num?)?.toDouble() ?? 0).toString());
    _horasCtrl = TextEditingController(
        text: ((d?['horas_semanales'] as num?)?.toDouble() ?? 40).toString());
    _retrEspecieCtrl = TextEditingController(
        text: ((d?['retribuciones_especie'] as num?)?.toDouble() ?? 0.0)
            .toStringAsFixed(2));
    _hijosCtrl = TextEditingController(
        text: ((d?['num_hijos'] as num?)?.toInt() ?? 0).toString());
    _hijosMenoresCtrl = TextEditingController(
        text: ((d?['num_hijos_menores_3'] as num?)?.toInt() ?? 0).toString());
    _pctDiscapacidadCtrl = TextEditingController(
        text: ((d?['porcentaje_discapacidad'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(0));
    _antiguedadManualImporteCtrl = TextEditingController(
        text: ((d?['antiguedad_manual_importe'] as num?)?.toDouble() ?? 0)
            .toString());
    _nivelCarnicasCtrl = TextEditingController(
        text: ((d?['nivel_categoria_carnicas'] as num?)?.toInt() ?? 5).toString());

    _estadoCivil = EstadoCivil.values.firstWhere(
        (e) => e.name == (d?['estado_civil'] as String?),
        orElse: () => EstadoCivil.soltero);
    _discapacidad    = d?['discapacidad'] as bool? ?? false;
    _pctDiscapacidad = (d?['porcentaje_discapacidad'] as num?)?.toDouble() ?? 0;
    _numHijos        = (d?['num_hijos'] as num?)?.toInt() ?? 0;
    _numHijosMenores3 = (d?['num_hijos_menores_3'] as num?)?.toInt() ?? 0;
    _prorrateoPagas  = d?['pagas_prorrateadas'] as bool? ?? true;
    _numPagas        = (d?['num_pagas'] as num?)?.toInt() ?? 12;
    _antiguedadManual = d?['antiguedad_manual'] as bool? ?? false;

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

    // Pluses dinámicos: inicializar con los guardados, rellenar con 0 los nuevos
    final plusesPrevios = (d?['pluses_variables'] as Map<String, dynamic>?) ?? {};
    _plusesCtrls = {
      for (final p in _plusesDelSector)
        p.key: TextEditingController(
            text: (plusesPrevios[p.key] ?? '').toString()),
    };
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nifCtrl.dispose();
    _nssCtrl.dispose();
    _ibanCtrl.dispose();
    _fechaNacCtrl.dispose();
    _salarioCtrl.dispose();
    _complementoFijoCtrl.dispose();
    _irpfPctCtrl.dispose();
    _otrasRentasCtrl.dispose();
    _horasCtrl.dispose();
    _retrEspecieCtrl.dispose();
    _hijosCtrl.dispose();
    _hijosMenoresCtrl.dispose();
    _pctDiscapacidadCtrl.dispose();
    _antiguedadManualImporteCtrl.dispose();
    _nivelCarnicasCtrl.dispose();
    for (final c in _plusesCtrls.values) c.dispose();
    super.dispose();
  }

  TipoContrato _parseTipoContrato(dynamic raw) {
    final s = raw as String?;
    return TipoContrato.values.firstWhere(
        (e) => e.name == s, orElse: () => TipoContrato.indefinido);
  }

  // ── Guardar ──────────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final salario = double.tryParse(_salarioCtrl.text) ?? 0;
    final irpf    = double.tryParse(_irpfPctCtrl.text) ?? 15.0;
    _numHijos         = int.tryParse(_hijosCtrl.text) ?? 0;
    _numHijosMenores3 = int.tryParse(_hijosMenoresCtrl.text) ?? 0;
    _pctDiscapacidad  = double.tryParse(_pctDiscapacidadCtrl.text) ?? _pctDiscapacidad;

    // Solo guarda pluses con valor > 0
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
        _numPagas = cat.numPagas > 0 ? cat.numPagas : 14;
      } catch (_) {}
    }
    final minimo = [_kSmiAnual, minimoConvenio ?? 0].reduce((a, b) => a > b ? a : b);
    if (salario < minimo) {
      if (mounted) {
        FluxToast.error(context,
            'Salario (${salario.toStringAsFixed(2)} €) bajo el mínimo '
            '(SMI/convenio: ${minimo.toStringAsFixed(2)} €)');
      }
      setState(() => _guardando = false);
      return;
    }

    final datos = {
      'salario_bruto_anual':     salario,
      'irpf_porcentaje':         irpf,
      'nif':                     _nifCtrl.text.trim(),
      'nss':                     _nssCtrl.text.trim(),
      'cuenta_bancaria':         _ibanCtrl.text.trim(),
      if (_fechaNacimiento != null)
        'fecha_nacimiento':      _fechaNacimiento!.toIso8601String(),
      'estado_civil':            _estadoCivil.name,
      'num_hijos':               _numHijos,
      'num_hijos_menores_3':     _numHijosMenores3,
      'discapacidad':            _discapacidad,
      'porcentaje_discapacidad': _pctDiscapacidad,
      'otras_rentas':            double.tryParse(_otrasRentasCtrl.text) ?? 0,
      'horas_semanales':         double.tryParse(_horasCtrl.text) ?? 40,
      'retribuciones_especie':   double.tryParse(_retrEspecieCtrl.text) ?? 0,
      'complemento_fijo':        double.tryParse(_complementoFijoCtrl.text) ?? 0,
      'num_pagas':               _numPagas,
      'prorrateo_pagas_extras':  _prorrateoPagas,
      'pagas_prorrateadas':      _prorrateoPagas,
      'tipo_contrato':           _tipoContrato.name,
      'grupo_cotizacion':        _grupoCotizacion.name,
      'categoria_convenio_id':   _categoriaConvenioSeleccionada,
      'antiguedad_manual':       _antiguedadManual,
      'antiguedad_manual_importe':
          double.tryParse(_antiguedadManualImporteCtrl.text) ?? 0,
      'nivel_categoria_carnicas':
          int.tryParse(_nivelCarnicasCtrl.text) ?? 5,
      if (plusesVariables.isNotEmpty) 'pluses_variables': plusesVariables,
    };

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.empleadoId)
          .update({
        'datos_nomina':                 datos,
        'fecha_actualizacion_nomina':   DateTime.now(),
      });
      if (mounted) {
        Navigator.pop(context);
        FluxToast.exito(context, 'Datos de nómina guardados');
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
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
              _buildHandle(),
              _buildHeader(),
              _buildTabBar(),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.52,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [_tabPersonal(), _tabSalario()],
                ),
              ),
              const Divider(height: 1, color: _kBorder),
              _buildGuardar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      );

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: _kBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Datos de nómina',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: _kText)),
            Text(widget.empleadoNombre,
                style: const TextStyle(fontSize: 12, color: _kSub)),
          ]),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18, color: _kSub),
          splashRadius: 18,
        ),
      ]),
    );
  }

  Widget _buildTabBar() => TabBar(
        controller: _tabCtrl,
        labelColor: _kBlue,
        unselectedLabelColor: _kSub,
        indicatorColor: _kBlue,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Personal y Contrato', icon: Icon(Icons.person_outline, size: 18)),
          Tab(text: 'Salario y Cotización', icon: Icon(Icons.euro_rounded, size: 18)),
        ],
      );

  // ── Tab Personal ────────────────────────────────────────────────────────────
  Widget _tabPersonal() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        _sectionLabel('Identificación'),
        _campo(_nifCtrl, 'NIF / NIE', 'Ej: 12345678A', Icons.badge_outlined),
        const SizedBox(height: 12),
        _campo(_nssCtrl, 'Nº Seguridad Social', 'Ej: 28/1234567890/12',
            Icons.health_and_safety_outlined,
            helpText: 'Encuéntralo en tu tarjeta de la Seguridad Social'),
        const SizedBox(height: 12),
        _buildCampoIBAN(),
        const SizedBox(height: 16),
        _sectionLabel('Datos personales'),
        _buildFechaNacimiento(),
        const SizedBox(height: 12),
        _buildDropdown<EstadoCivil>(
          'Estado civil', EstadoCivil.values, _estadoCivil,
          (v) => setState(() => _estadoCivil = v ?? EstadoCivil.soltero),
          (v) => v.etiqueta, Icons.family_restroom_outlined,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _campo(_hijosCtrl, 'Hijos a cargo', '0',
              Icons.child_care_rounded, numerico: true)),
          const SizedBox(width: 12),
          Expanded(child: _campo(_hijosMenoresCtrl, 'Hijos < 3 años', '0',
              Icons.baby_changing_station_rounded, numerico: true)),
        ]),
        const SizedBox(height: 12),
        _buildSwitchTile('Discapacidad reconocida', _discapacidad,
            (v) => setState(() => _discapacidad = v)),
        if (_discapacidad) ...[
          const SizedBox(height: 8),
          _campo(_pctDiscapacidadCtrl, 'Porcentaje discapacidad (%)',
              'Ej: 33', Icons.percent_rounded, numerico: true),
        ],
        const SizedBox(height: 16),
        _sectionLabel('Contrato'),
        _buildDropdown<TipoContrato>(
          'Tipo de contrato', TipoContrato.values, _tipoContrato,
          (v) => setState(() => _tipoContrato = v!),
          (v) => v.etiqueta, Icons.article_outlined,
        ),
        if (widget.categoriasConvenio.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDropdown<String>(
            'Categoría del convenio',
            widget.categoriasConvenio.map((c) => c.id).toList(),
            _categoriaConvenioSeleccionada,
            (v) {
              setState(() {
                _categoriaConvenioSeleccionada = v;
                if (v != null) {
                  try {
                    final cat = widget.categoriasConvenio
                        .firstWhere((c) => c.id == v);
                    _numPagas = cat.numPagas > 0 ? cat.numPagas : 14;
                    if (!cat.salarioLibre) {
                      _salarioCtrl.text = cat.salarioAnual.toString();
                    }
                  } catch (_) {}
                }
              });
            },
            (v) {
              try {
                return widget.categoriasConvenio
                    .firstWhere((c) => c.id == v).nombre;
              } catch (_) {
                return v;
              }
            },
            Icons.category_outlined,
          ),
          _buildNotaConvenio(),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _campo(_salarioCtrl, 'Salario bruto anual (€)',
              'Ej: 20000', Icons.euro_rounded, numerico: true)),
          const SizedBox(width: 12),
          Expanded(child: _campo(_horasCtrl, 'Horas semanales',
              '40', Icons.timer_outlined, numerico: true)),
        ]),
        const SizedBox(height: 4),
        _buildSwitchTile('Prorratear pagas extra en 12 mensualidades',
            _prorrateoPagas, (v) => setState(() => _prorrateoPagas = v)),
      ],
    );
  }

  // ── Tab Salario ─────────────────────────────────────────────────────────────
  Widget _tabSalario() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        _sectionLabel('Retención e IRPF'),
        _campo(_irpfPctCtrl, 'Retención IRPF (%)', 'Ej: 15',
            Icons.percent_rounded, numerico: true,
            helpText: 'Consulta tu nómina anterior o usa la estimación de abajo'),
        const SizedBox(height: 12),
        _campo(_otrasRentasCtrl, 'Otras rentas anuales (€)', 'Ej: 0',
            Icons.savings_outlined, numerico: true,
            helpText: 'Ingresos de alquileres, inversiones u otros empleos'),
        const SizedBox(height: 16),
        _sectionLabel('Cotización a la Seguridad Social'),
        _buildGrupoCotizacion(),
        const SizedBox(height: 16),
        _sectionLabel('Complementos'),
        _campo(_complementoFijoCtrl, 'Complemento fijo anual (€)',
            'Ej: 1200', Icons.add_card_rounded, numerico: true),
        const SizedBox(height: 12),
        _campo(_retrEspecieCtrl, 'Retribuciones en especie (€/mes)',
            'Ej: 0', Icons.card_giftcard_outlined, numerico: true,
            helpText: 'Coche, seguro médico, comida... pagados por la empresa'),
        const SizedBox(height: 16),
        _buildAntiguedad(),
        const SizedBox(height: 16),
        _buildPlusesVariables(),
        const SizedBox(height: 16),
        _buildEstimacion(),
      ],
    );
  }

  // ── Widgets auxiliares ─────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: _kSub, letterSpacing: 0.5)),
      );

  Widget _buildFechaNacimiento() => TextFormField(
        controller: _fechaNacCtrl,
        readOnly: true,
        style: const TextStyle(fontSize: 13, color: _kText),
        decoration: _inputDeco('Fecha de nacimiento', 'YYYY-MM-DD',
            Icons.cake_outlined),
        onTap: _pickFechaNacimiento,
      );

  Widget _buildNotaConvenio() {
    if (_categoriaConvenioSeleccionada == null) return const SizedBox.shrink();
    final cat = widget.categoriasConvenio.cast<CategoriaConvenio?>()
        .firstWhere((c) => c?.id == _categoriaConvenioSeleccionada,
            orElse: () => null);
    if (cat == null) return const SizedBox.shrink();
    final tieneNota = cat.salarioLibre || (cat.nota?.isNotEmpty ?? false);
    if (!tieneNota) {
      // Mostrar salario mínimo de la categoría como info positiva
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: _kGreen),
            const SizedBox(width: 8),
            Text('Salario mínimo convenio: ${cat.salarioAnual.toStringAsFixed(2)} €/año · '
                '${cat.numPagas} pagas',
                style: const TextStyle(fontSize: 11, color: _kGreen,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kOrange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kOrange.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: _kOrange),
          const SizedBox(width: 8),
          Expanded(child: Text(cat.nota ?? 'Salario libre según convenio',
              style: const TextStyle(fontSize: 11, color: _kOrange))),
        ]),
      ),
    );
  }

  Widget _buildGrupoCotizacion() {
    return Column(children: [
      _buildDropdown<GrupoCotizacion>(
        'Grupo de cotización', GrupoCotizacion.values, _grupoCotizacion,
        (v) => setState(() => _grupoCotizacion = v!),
        (v) => '${v.index + 1} — ${v.etiquetaCorta}',
        Icons.groups_outlined,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBlue.withValues(alpha: 0.15)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.help_outline_rounded, size: 13, color: _kBlue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Grupos 1-3: Ingenieros, Licenciados, Jefes. '
                'Grupo 5: Oficiales. Grupo 7: Peones/aux. '
                'Consulta el contrato o a tu gestoría si tienes dudas.',
                style: const TextStyle(fontSize: 10, color: _kBlue,
                    height: 1.4),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildAntiguedad() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5D4037).withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.workspace_premium_rounded, size: 16,
              color: Color(0xFF5D4037)),
          SizedBox(width: 6),
          Text('Antigüedad',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                  color: Color(0xFF5D4037))),
        ]),
        const SizedBox(height: 8),
        _buildSwitchTile(
            'Importe manual (sobreescribe el convenio)',
            _antiguedadManual,
            (v) => setState(() => _antiguedadManual = v)),
        if (_antiguedadManual) ...[
          const SizedBox(height: 8),
          _campo(_antiguedadManualImporteCtrl, 'Antigüedad (€/mes)',
              'Ej: 50', Icons.edit_rounded, numerico: true),
          if (_esSectorCarnicas) ...[
            const SizedBox(height: 8),
            _campo(_nivelCarnicasCtrl, 'Nivel cárnicas (1-6)',
                '5', Icons.factory_rounded, numerico: true),
          ],
        ],
      ]),
    );
  }

  Widget _buildPlusesVariables() {
    final pluses = _plusesDelSector;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.add_chart_rounded, size: 16, color: _kBlue),
          const SizedBox(width: 6),
          const Text('Pluses variables',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                  color: _kText)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_sectorLabel,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _kBlue)),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Unidades o importe del mes a calcular',
            style: TextStyle(fontSize: 10, color: _kSub)),
        const SizedBox(height: 12),
        ...pluses.map((p) {
          // Crear controller si no existe (cambio de sector en caliente)
          _plusesCtrls.putIfAbsent(p.key, TextEditingController.new);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _campo(_plusesCtrls[p.key]!, p.label, p.hint, p.icon,
                numerico: true, obligatorio: false),
          );
        }),
      ]),
    );
  }

  String get _sectorLabel => switch (_sectorActual) {
    'hosteleria'   => 'Hostelería',
    'comercio'     => 'Comercio',
    'peluqueria'   => 'Peluquería',
    'carnicas'     => 'Cárnicas',
    'veterinarios' => 'Veterinarios',
    'construccion' => 'Construcción',
    _              => 'General',
  };

  Widget _buildEstimacion() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBlue.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Estimación mensual',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                color: _kBlue)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _kpiEstimacion('Salario base',
              '${_calcularSalarioMensual().toStringAsFixed(2)} €'),
          _kpiEstimacion('IRPF estimado',
              '${_calcularPctIrpf().toStringAsFixed(1)} %'),
        ]),
      ]),
    );
  }

  Widget _kpiEstimacion(String label, String valor) => Column(children: [
        Text(valor, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.bold, color: _kText)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: _kSub)),
      ]);

  Widget _buildGuardar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: FilledButton.icon(
        onPressed: _guardando ? null : _guardar,
        icon: _guardando
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded, size: 18),
        label: Text(_guardando ? 'Guardando...' : 'Guardar datos de nómina',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: _kBlue,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Helpers de campos ──────────────────────────────────────────────────────

  InputDecoration _inputDeco(String label, String hint, IconData icon,
      {String? helpText}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helpText,
        helperMaxLines: 2,
        helperStyle: const TextStyle(fontSize: 10, color: _kSub),
        prefixIcon: Icon(icon, size: 18, color: _kBlue),
        labelStyle: const TextStyle(fontSize: 13, color: _kSub),
        filled: true,
        fillColor: _kBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kRed)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kRed, width: 2)),
        isDense: true,
      );

  Widget _campo(TextEditingController ctrl, String label, String hint,
      IconData icon,
      {bool numerico = false,
      bool obligatorio = true,
      String? helpText}) =>
      TextFormField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13, color: _kText),
        decoration: _inputDeco(label, hint, icon, helpText: helpText),
        keyboardType: numerico
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        validator: obligatorio
            ? (v) {
                if (v == null || v.isEmpty) return 'Campo obligatorio';
                if (numerico && double.tryParse(v) == null) return 'Número inválido';
                return null;
              }
            : null,
      );

  Widget _buildCampoIBAN() {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final texto  = _ibanCtrl.text.trim();
        final error  = texto.isEmpty ? null : SepaXmlGenerator.validarIBAN(texto);
        final valido = texto.isNotEmpty && error == null;
        return TextFormField(
          controller: _ibanCtrl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_IBANFormatter()],
          style: const TextStyle(fontSize: 13, color: _kText),
          decoration: InputDecoration(
            labelText: 'Cuenta bancaria (IBAN)',
            hintText: 'ES12 1234 1234 1234 1234 1234',
            helperText: texto.isEmpty
                ? 'Ej: ES12 1234 5678 9012 3456 7890'
                : (valido
                    ? '✅ ${SepaXmlGenerator.formatearIBAN(texto)}'
                    : null),
            helperStyle: TextStyle(
                fontSize: 10,
                color: texto.isEmpty ? _kSub : (valido ? _kGreen : _kRed)),
            prefixIcon:
                const Icon(Icons.account_balance_rounded, size: 18, color: _kBlue),
            suffixIcon: texto.isEmpty
                ? null
                : Icon(valido ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: valido ? _kGreen : _kRed, size: 18),
            filled: true,
            fillColor: texto.isEmpty
                ? _kBg
                : (valido
                    ? _kGreen.withValues(alpha: 0.04)
                    : _kRed.withValues(alpha: 0.04)),
            errorText: texto.isNotEmpty && !valido ? error : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBlue, width: 2)),
            isDense: true,
          ),
          onChanged: (_) => setLocalState(() {}),
          onEditingComplete: () {
            if (_ibanCtrl.text.trim().isNotEmpty) {
              final f = SepaXmlGenerator.formatearIBAN(_ibanCtrl.text);
              _ibanCtrl.text = f;
              _ibanCtrl.selection =
                  TextSelection.fromPosition(TextPosition(offset: f.length));
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
      void Function(T?) onChanged, String Function(T) itemLabel, IconData icon) {
    final allItems = items
        .map((i) => DropdownMenuItem(value: i, child: Text(itemLabel(i),
            style: const TextStyle(fontSize: 13))))
        .toList();
    final valorValido =
        allItems.any((item) => item.value == valor) ? valor : null;
    return DropdownButtonFormField<T>(
      initialValue: valorValido,
      items: allItems,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: _kText),
      decoration: _inputDeco(label, '', icon),
    );
  }

  Widget _buildSwitchTile(
      String title, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title,
            style: const TextStyle(fontSize: 12, color: _kText)),
        activeColor: _kBlue,
        value: value,
        onChanged: onChanged,
      );

  // ── Lógica ────────────────────────────────────────────────────────────────

  double _calcularSalarioMensual() {
    final bruto = double.tryParse(_salarioCtrl.text) ?? 0;
    if (!_prorrateoPagas) return _numPagas > 0 ? bruto / _numPagas : bruto;
    return bruto / 12;
  }

  double _calcularPctIrpf() {
    final bruto = double.tryParse(_salarioCtrl.text) ?? 0;
    final tempCfg = DatosNominaEmpleado(
      salarioBrutoAnual:    bruto,
      numPagas:             _numPagas,
      pagasProrrateadas:    _prorrateoPagas,
      fechaNacimiento:      _fechaNacimiento,
      estadoCivil:          _estadoCivil,
      numHijos:             _numHijos,
      numHijosMenores3:     _numHijosMenores3,
      discapacidad:         _discapacidad,
      porcentajeDiscapacidad: _pctDiscapacidad,
      otrasRentas:          double.tryParse(_otrasRentasCtrl.text) ?? 0,
      horasSemanales:       double.tryParse(_horasCtrl.text) ?? 40,
      retribucionesEspecie: double.tryParse(_retrEspecieCtrl.text) ?? 0,
    );
    final edad = _fechaNacimiento != null
        ? DateTime.now().year - _fechaNacimiento!.year
        : null;
    return bruto > 0
        ? NominasService.calcularPorcentajeIrpf(bruto,
            config: tempCfg, edadEmpleado: edad)
        : 0.0;
  }

  String _formatearFecha(DateTime f) =>
      '${f.year}-${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  Future<void> _pickFechaNacimiento() async {
    final ahora   = DateTime.now();
    final inicial = _fechaNacimiento ?? DateTime(1990, 1, 1);
    final elegido = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(ahora) ? ahora : inicial,
      firstDate: DateTime(1940),
      lastDate:  ahora,
    );
    if (elegido != null) {
      setState(() {
        _fechaNacimiento = elegido;
        _fechaNacCtrl.text = _formatearFecha(elegido);
      });
    }
  }
}

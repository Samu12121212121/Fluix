import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'modelo303_screen.dart';
import 'modelo111_screen.dart';
import 'modelo115_screen.dart';
import 'modelo202_screen.dart';
import 'modelo390_screen.dart';
import 'modelo190_screen.dart';
import 'modelo180_screen.dart';
import 'modelo347_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// EXPORT MODELS SCREEN — Wizard unificado para los 8 modelos AEAT
// ═════════════════════════════════════════════════════════════════════════════

class ExportModelsScreen extends StatefulWidget {
  final String empresaId;

  const ExportModelsScreen({super.key, required this.empresaId});

  @override
  State<ExportModelsScreen> createState() => _ExportModelsScreenState();
}

class _ExportModelsScreenState extends State<ExportModelsScreen> {
  String _periodo = '';
  bool _tienePack = false;
  bool _cargando = true;

  static const _modelosTrimestrales = [
    _ModeloInfo('303', 'IVA trimestral', Icons.receipt_long, Colors.blue),
    _ModeloInfo('111', 'Retenciones IRPF', Icons.people, Colors.purple),
    _ModeloInfo('115', 'Retenciones alquileres', Icons.home_work, Colors.teal),
    _ModeloInfo('202', 'Pagos fraccionados IS', Icons.business_center, Colors.indigo),
  ];

  static const _modelosAnuales = [
    _ModeloInfo('390', 'Resumen anual IVA', Icons.summarize, Colors.blue),
    _ModeloInfo('190', 'Resumen retenciones IRPF', Icons.group, Colors.purple),
    _ModeloInfo('180', 'Resumen retenciones alquileres', Icons.home, Colors.teal),
    _ModeloInfo('347', 'Operaciones con terceros', Icons.swap_horiz, Colors.orange),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final q = ((now.month - 1) ~/ 3) + 1;
    _periodo = '${now.year}-Q$q';
    _verificarPack();
  }

  Future<void> _verificarPack() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      final packs = (doc.data()?['active_packs'] as List? ?? []).cast<String>();
      setState(() {
        _tienePack = packs.contains('fiscal_ai');
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modelos AEAT'),
        centerTitle: false,
      ),
      body: !_tienePack
          ? _buildSinPack()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPeriodoSelector(),
                const SizedBox(height: 24),
                _buildSeccion('TRIMESTRALES', _modelosTrimestrales),
                const SizedBox(height: 24),
                _buildSeccion('ANUALES', _modelosAnuales),
                const SizedBox(height: 32),
                _buildPrevisionCalendario(),
              ],
            ),
    );
  }

  Widget _buildSinPack() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Pack Fiscal IA no activo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Activa el Pack Fiscal para acceder al cálculo automático de modelos AEAT.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodoSelector() {
    final anio = DateTime.now().year;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Período activo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int q = 1; q <= 4; q++)
                  _chipPeriodo('$anio-Q$q', '${q}T $anio'),
                _chipPeriodo('$anio', 'Anual $anio'),
                _chipPeriodo('${anio - 1}', 'Anual ${anio - 1}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipPeriodo(String value, String label) {
    final selected = _periodo == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _periodo = value),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildSeccion(
      String titulo, List<_ModeloInfo> modelos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titulo,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...modelos.map((m) => _buildModelCard(m)),
      ],
    );
  }

  Widget _buildModelCard(_ModeloInfo m) {
    final isAnual = !_periodo.contains('-Q');
    final modelIsAnual = ['390', '190', '180', '347'].contains(m.code);

    // Grayed out si el tipo no coincide con el período seleccionado
    final activo = isAnual == modelIsAnual;

    return Opacity(
      opacity: activo ? 1.0 : 0.45,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: m.color.withValues(alpha: 0.15),
            child: Text(
              m.code,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: m.color),
            ),
          ),
          title: Text('Modelo ${m.code}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(m.nombre),
          trailing: const Icon(Icons.chevron_right),
          onTap: activo ? () => _abrirModelo(m.code) : null,
        ),
      ),
    );
  }

  void _abrirModelo(String code) {
    final anio = int.tryParse(_periodo.split('-')[0]) ?? DateTime.now().year;

    Widget pantalla;
    switch (code) {
      case '303':
        pantalla = Modelo303Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '111':
        pantalla = Modelo111Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '115':
        pantalla = Modelo115Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '202':
        pantalla = Modelo202Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '390':
        pantalla = Modelo390Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '190':
        pantalla = Modelo190Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '180':
        pantalla = Modelo180Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '347':
        pantalla = Modelo347Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      default:
        return;
    }

    Navigator.push(
        context, MaterialPageRoute(builder: (_) => pantalla));
  }

  Widget _buildPrevisionCalendario() {
    final now = DateTime.now();
    final items = _plazos
        .where((p) => p.vencimiento.isAfter(now))
        .toList()
      ..sort((a, b) => a.vencimiento.compareTo(b.vencimiento));

    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PRÓXIMOS PLAZOS',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          child: Column(
            children: items.take(4).map((p) {
              final dias = p.vencimiento.difference(now).inDays;
              final urgente = dias <= 15;
              return ListTile(
                dense: true,
                leading: Icon(Icons.event,
                    color: urgente ? Colors.red : Colors.grey),
                title: Text(p.modelo),
                subtitle: Text(p.descripcion),
                trailing: Text(
                  DateFormat('dd/MM').format(p.vencimiento),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: urgente ? Colors.red : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static final List<_PlazoFiscal> _plazos = _generarPlazos();

  static List<_PlazoFiscal> _generarPlazos() {
    final anio = DateTime.now().year;
    return [
      _PlazoFiscal('303 / 111 / 115 · 1T', 'Presentación 1er trimestre',
          DateTime(anio, 4, 20)),
      _PlazoFiscal('303 / 111 / 115 · 2T', 'Presentación 2º trimestre',
          DateTime(anio, 7, 20)),
      _PlazoFiscal('303 / 111 / 115 · 3T', 'Presentación 3er trimestre',
          DateTime(anio, 10, 20)),
      _PlazoFiscal('303 / 111 / 115 · 4T', 'Presentación 4º trimestre',
          DateTime(anio, 1, 30).add(const Duration(days: 365))),
      _PlazoFiscal('390 / 190 / 180', 'Resumen anual $anio',
          DateTime(anio + 1, 1, 31)),
      _PlazoFiscal('347', 'Operaciones con terceros $anio',
          DateTime(anio + 1, 2, 28)),
    ];
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _ModeloInfo {
  final String code;
  final String nombre;
  final IconData icon;
  final Color color;

  const _ModeloInfo(this.code, this.nombre, this.icon, this.color);
}

class _PlazoFiscal {
  final String modelo;
  final String descripcion;
  final DateTime vencimiento;

  const _PlazoFiscal(this.modelo, this.descripcion, this.vencimiento);
}




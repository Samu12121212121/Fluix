import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../services/remesa_sepa_service.dart';
import '../../../services/sepa_xml_generator.dart';

/// Formulario para crear una nueva remesa SEPA.
class NuevaRemesaForm extends StatefulWidget {
  final String empresaId;
  final int? mesInicial;
  final int? anioInicial;
  const NuevaRemesaForm({
    super.key,
    required this.empresaId,
    this.mesInicial,
    this.anioInicial,
  });

  @override
  State<NuevaRemesaForm> createState() => _NuevaRemesaFormState();
}

class _NuevaRemesaFormState extends State<NuevaRemesaForm> {
  final RemesaSepaService _svc = RemesaSepaService();

  late int _mes;
  late int _anio;
  DateTime _fechaEjecucion = SepaXmlGenerator.sugerirDiaHabil(DateTime.now());

  List<Nomina> _nominas = [];
  Map<String, DatosNominaEmpleado> _datosEmpleados = {};
  List<String> _errores = [];
  String? _ibanEmpresa;
  bool _cargando = true;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _mes = widget.mesInicial ?? DateTime.now().month;
    _anio = widget.anioInicial ?? DateTime.now().year;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // IBAN empresa
      final ibanBic = await _svc.obtenerIbanBicEmpresa(widget.empresaId);
      _ibanEmpresa = ibanBic['iban'];

      // Nóminas aprobadas
      _nominas = await _svc.obtenerNominasAprobadas(widget.empresaId, _anio, _mes);

      // Datos empleados
      if (_nominas.isNotEmpty) {
        final ids = _nominas.map((n) => n.empleadoId).toList();
        _datosEmpleados = await _svc.obtenerDatosEmpleados(ids);
      }

      _validar();
    } catch (e) {
      _errores = ['Error cargando datos: $e'];
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _validar() {
    if (_nominas.isEmpty) {
      _errores = ['No hay nóminas aprobadas para ${_nombreMes(_mes)} $_anio'];
      return;
    }
    if (_ibanEmpresa == null || _ibanEmpresa!.isEmpty) {
      _errores = ['La empresa no tiene IBAN configurado'];
      return;
    }
    // Crear un ordenante temporal para validar
    final ordenante = DatosOrdenante(
      nif: 'TEMPORAL',
      razonSocial: 'TEMPORAL',
      direccion: '',
      ibanEmpresa: _ibanEmpresa!,
    );
    _errores = SepaXmlGenerator.validarLote(
      nominas: _nominas,
      ordenante: ordenante,
      datosEmpleados: _datosEmpleados,
      fechaEjecucion: _fechaEjecucion,
    );
    // Filtrar errores del NIF/razón social temporal
    _errores.removeWhere((e) => e.contains('NIF empresa') || e.contains('Razón social'));
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaEjecucion,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      selectableDayPredicate: (date) {
        return date.weekday != DateTime.saturday &&
               date.weekday != DateTime.sunday;
      },
    );
    if (picked != null) {
      setState(() {
        _fechaEjecucion = picked;
        _validar();
      });
    }
  }

  Future<void> _generarRemesa() async {
    setState(() => _generando = true);
    try {
      final remesa = await _svc.crearRemesa(
        empresaId: widget.empresaId,
        nominas: _nominas,
        fechaEjecucion: _fechaEjecucion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Remesa SEPA generada · ${remesa.nTransferencias} transferencias · '
              '${remesa.importeTotal.toStringAsFixed(2)}€',
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );

        // Preguntar si compartir
        final compartir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remesa generada'),
            content: Text(
              '${remesa.nTransferencias} transferencias por '
              '${remesa.importeTotal.toStringAsFixed(2)}€\n\n'
              '¿Compartir el fichero XML SEPA?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Compartir XML'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );

        if (compartir == true && mounted) {
          await _svc.compartirXml(context, remesa);
        }

        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _generando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Nueva remesa SEPA'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSelectorMes(),
                  const SizedBox(height: 16),
                  _buildFechaEjecucion(),
                  const SizedBox(height: 16),
                  _buildIbanEmpresa(),
                  const SizedBox(height: 16),
                  _buildListaNominas(),
                  const SizedBox(height: 16),
                  if (_errores.isNotEmpty) _buildErrores(),
                  if (_errores.isNotEmpty) const SizedBox(height: 16),
                  _buildResumen(),
                  const SizedBox(height: 24),
                  _buildBotonGenerar(),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSelectorMes() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Color(0xFF0D47A1)),
            const SizedBox(width: 12),
            const Text('Período:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _mes--;
                  if (_mes < 1) { _mes = 12; _anio--; }
                });
                _cargarDatos();
              },
            ),
            Expanded(
              child: Text(
                '${_nombreMes(_mes)} $_anio',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _mes++;
                  if (_mes > 12) { _mes = 1; _anio++; }
                });
                _cargarDatos();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFechaEjecucion() {
    final esFinDeSemana = _fechaEjecucion.weekday == DateTime.saturday ||
                          _fechaEjecucion.weekday == DateTime.sunday;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          Icons.event,
          color: esFinDeSemana ? Colors.red : const Color(0xFF0D47A1),
        ),
        title: const Text('Fecha de ejecución (pago)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${_fechaEjecucion.day}/${_fechaEjecucion.month}/${_fechaEjecucion.year}'
          '${esFinDeSemana ? '  ⚠️ Fin de semana' : ''}',
          style: TextStyle(
            color: esFinDeSemana ? Colors.red : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.edit_calendar),
        onTap: _seleccionarFecha,
      ),
    );
  }

  Widget _buildIbanEmpresa() {
    final iban = _ibanEmpresa ?? '';
    final errIban = SepaXmlGenerator.validarIBAN(iban);
    final valido = errIban == null && iban.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          valido ? Icons.check_circle : Icons.warning,
          color: valido ? const Color(0xFF2E7D32) : Colors.orange,
        ),
        title: const Text('IBAN empresa (cuenta de cargo)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          iban.isEmpty
              ? 'No configurado — Configúralo para generar remesas'
              : SepaXmlGenerator.formatearIBAN(iban),
          style: TextStyle(
            fontSize: 13,
            color: valido ? null : Colors.orange[800],
            fontFamily: 'monospace',
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editarIbanEmpresa(),
        ),
      ),
    );
  }

  Future<void> _editarIbanEmpresa() async {
    final controller = TextEditingController(text: _ibanEmpresa ?? '');
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('IBAN cuenta empresa'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'IBAN',
            hintText: 'ES00 0000 0000 0000 0000 0000',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
            LengthLimitingTextInputFormatter(29), // 24 + 5 spaces
          ],
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      final clean = SepaXmlGenerator.limpiarIBAN(resultado);
      final err = SepaXmlGenerator.validarIBAN(clean);
      if (err != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('IBAN inválido: $err'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      await _svc.guardarIbanBicEmpresa(widget.empresaId, clean, null);
      setState(() => _ibanEmpresa = clean);
      _validar();
      setState(() {});
    }
  }

  Widget _buildListaNominas() {
    if (_nominas.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No hay nóminas aprobadas para ${_nombreMes(_mes)} $_anio',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF0D47A1), size: 20),
                const SizedBox(width: 8),
                Text('Nóminas aprobadas (${_nominas.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._nominas.map(_buildFilaNomina),
        ],
      ),
    );
  }

  Widget _buildFilaNomina(Nomina n) {
    final datos = _datosEmpleados[n.empleadoId];
    final iban = datos?.cuentaBancaria ?? '';
    final errIban = SepaXmlGenerator.validarIBAN(iban);
    final ibanValido = errIban == null && iban.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            ibanValido ? Icons.check_circle : Icons.warning,
            color: ibanValido ? const Color(0xFF2E7D32) : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.empleadoNombre,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  iban.isEmpty
                      ? 'Sin IBAN'
                      : SepaXmlGenerator.formatearIBAN(iban),
                  style: TextStyle(
                    fontSize: 11,
                    color: ibanValido ? Colors.grey[600] : Colors.orange[800],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${n.salarioNeto.toStringAsFixed(2)} €',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrores() {
    return Card(
      color: const Color(0xFFFFEBEE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Color(0xFFC62828), size: 20),
                SizedBox(width: 8),
                Text('Validaciones pendientes',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC62828),
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            ..._errores.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('❌ ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(e,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFC62828))),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    final totalNeto = _nominas.fold(0.0, (s, n) => s + n.salarioNeto);
    return Card(
      color: const Color(0xFFE3F2FD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.summarize, color: Color(0xFF0D47A1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_nominas.length} transferencias',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Importe total: ${totalNeto.toStringAsFixed(2)} €',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: Color(0xFF0D47A1))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonGenerar() {
    final habilitado = _errores.isEmpty && _nominas.isNotEmpty && !_generando;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: habilitado ? _generarRemesa : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _generando
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.account_balance),
        label: Text(
          _generando ? 'Generando...' : 'Generar XML SEPA',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _nombreMes(int mes) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return meses[mes.clamp(1, 12)];
  }
}


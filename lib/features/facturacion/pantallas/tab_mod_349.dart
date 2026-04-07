import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/modelos/empresa_config.dart';
import '../../../domain/modelos/factura.dart';
import '../../../domain/modelos/factura_recibida.dart';
import '../../../services/exportadores_aeat/mod_349_exporter.dart';
import '../../../services/mod_349_service.dart';

class Mod349Tab extends StatefulWidget {
  final EmpresaConfig empresa;
  final int ejercicio;
  final List<Factura> facturas;
  final List<FacturaRecibida> facturasRecibidas;

  const Mod349Tab({
    super.key,
    required this.empresa,
    required this.ejercicio,
    required this.facturas,
    required this.facturasRecibidas,
  });

  @override
  State<Mod349Tab> createState() => _Mod349TabState();
}

class _Mod349TabState extends State<Mod349Tab> {
  final Mod349Service _service = Mod349Service();
  final Mod349Exporter _exporter = Mod349Exporter();

  String _periodo = '1T';
  bool _mensual = false;
  bool _exportando = false;
  List<Operador349> _operadores = const [];

  @override
  void initState() {
    super.initState();
    _recalcular();
  }

  void _recalcular() {
    final ops = _service.calcularOperadoresPeriodo(
      widget.facturas,
      widget.facturasRecibidas,
      _periodo,
      widget.ejercicio,
    );
    setState(() => _operadores = ops);
  }

  @override
  Widget build(BuildContext context) {
    final alertaVat = _contarVatInvalidos();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _buildSelectorPeriodicidad()),
            const SizedBox(width: 8),
            Expanded(child: _buildSelectorPeriodo()),
          ],
        ),
        if (alertaVat > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
            ),
            child: Text(
              'Hay $alertaVat operador(es) intracomunitario(s) sin NIF-IVA valido.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildTablaOperaciones(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _verRectificaciones,
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('Ver rectificaciones'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _exportando ? null : _exportar,
                icon: _exportando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Exportar MOD 349'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectorPeriodicidad() {
    return DropdownButtonFormField<bool>(
      initialValue: _mensual,
      decoration: const InputDecoration(
        labelText: 'Periodicidad',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: false, child: Text('Trimestral')),
        DropdownMenuItem(value: true, child: Text('Mensual')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _mensual = v;
          _periodo = v ? '01' : '1T';
        });
        _recalcular();
      },
    );
  }

  Widget _buildSelectorPeriodo() {
    final periodos = _mensual
        ? const ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12']
        : const ['1T', '2T', '3T', '4T'];

    if (!periodos.contains(_periodo)) {
      _periodo = periodos.first;
    }

    return DropdownButtonFormField<String>(
      initialValue: _periodo,
      decoration: const InputDecoration(
        labelText: 'Periodo',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: periodos
          .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _periodo = v);
        _recalcular();
      },
    );
  }

  Widget _buildTablaOperaciones() {
    if (_operadores.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay operaciones intracomunitarias para el periodo.'),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Operador')),
            DataColumn(label: Text('NIF')),
            DataColumn(label: Text('Clave')),
            DataColumn(label: Text('Importe')),
            DataColumn(label: Text('Periodo')),
          ],
          rows: _operadores
              .map(
                (o) => DataRow(cells: [
                  DataCell(Text(o.razonSocial)),
                  DataCell(Text('${o.codigoPaisNif}${o.numeroNif}')),
                  DataCell(Text(o.claveOperacion.codigo)),
                  DataCell(Text(o.baseImponible.toStringAsFixed(2))),
                  DataCell(Text(_periodo)),
                ]),
              )
              .toList(),
        ),
      ),
    );
  }

  int _contarVatInvalidos() {
    var invalidos = 0;
    for (final f in widget.facturas) {
      final d = f.datosFiscales;
      if (d == null || !d.esIntracomunitario) continue;
      final vat = d.nifIvaComunitario ?? d.nif ?? '';
      if (!_service.esVatIntracomunitarioValido(vat)) invalidos++;
    }
    for (final r in widget.facturasRecibidas) {
      if (!r.esIntracomunitario) continue;
      final vat = r.nifIvaComunitario ?? r.nifProveedor;
      if (!_service.esVatIntracomunitarioValido(vat)) invalidos++;
    }
    return invalidos;
  }

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    try {
      final bytes = await _exporter.exportar(
        DatosMod349(
          empresa: widget.empresa,
          ejercicio: widget.ejercicio,
          periodo: _periodo,
          operadores: _operadores,
        ),
      );
      await _guardarYCompartir(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MOD 349 exportado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exportando MOD 349: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _guardarYCompartir(Uint8List bytes) async {
    if (kIsWeb) {
      throw UnsupportedError('Exportacion no disponible en web');
    }

    final dir = await getDownloadsDirectory();
    if (dir == null) {
      throw const FileSystemException('No se pudo acceder a la carpeta de descargas');
    }

    final file = File('${dir.path}/MOD349_${widget.ejercicio}_$_periodo.txt');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'MOD 349 ${widget.ejercicio} $_periodo',
      text: 'Fichero posicional oficial AEAT - Modelo 349',
    );
  }

  Future<void> _verRectificaciones() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rectificaciones MOD 349'),
        content: const Text('Gestion de rectificaciones pendiente de integrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}



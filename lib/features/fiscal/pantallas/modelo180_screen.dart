import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/fiscal/mod180_calculator.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 180 — Resumen anual retenciones arrendamientos
// Par anual del Modelo 115. Se presenta en enero del año siguiente.
// ═════════════════════════════════════════════════════════════════════════════

class Modelo180Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo180Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo180Screen> createState() => _Modelo180ScreenState();
}

class _Modelo180ScreenState extends State<Modelo180Screen> {
  final _calc = Mod180Calculator();
  // El 180 se presenta en enero sobre el ejercicio anterior
  late int _anio;
  bool _procesando = false;
  Modelo180Result? _resultado;

  @override
  void initState() {
    super.initState();
    _anio = widget.anioInicial ?? DateTime.now().year - 1;
    _cargarGuardado();
  }

  Future<void> _cargarGuardado() async {
    final r = await _calc.cargar(widget.empresaId, _anio);
    if (r != null && mounted) setState(() => _resultado = r);
  }

  Future<void> _calcular() async {
    setState(() => _procesando = true);
    try {
      final r = await _calc.calcular(
        empresaId: widget.empresaId,
        ejercicio: _anio,
      );
      await _calc.guardar(r);
      setState(() => _resultado = r);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✅ Modelo 180 $_anio calculado — '
            '${r.c01} arrendadores — '
            '${r.c03.toStringAsFixed(2)} € retenciones',
          ),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() => _procesando = false);
    }
  }

  Future<void> _exportarCsv() async {
    if (_resultado == null) return;
    final r = _resultado!;

    final sb = StringBuffer();
    sb.writeln('NIF;NOMBRE;DIRECCION_INMUEBLE;BASE_ANUAL;RETENCION_ANUAL;'
        'RET_Q1;RET_Q2;RET_Q3;RET_Q4');
    for (final a in r.arrendadores) {
      sb.writeln(
        '${a.nif};${a.nombre};${a.direccionInmueble};'
        '${a.baseAnual.toStringAsFixed(2)};${a.retencionAnual.toStringAsFixed(2)};'
        '${a.retencionQ1.toStringAsFixed(2)};${a.retencionQ2.toStringAsFixed(2)};'
        '${a.retencionQ3.toStringAsFixed(2)};${a.retencionQ4.toStringAsFixed(2)}',
      );
    }
    sb.writeln(';;TOTAL;${r.c02.toStringAsFixed(2)};${r.c03.toStringAsFixed(2)};;;;');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/modelo180_${r.ejercicio}.csv');
    await file.writeAsString(sb.toString());
    await Share.shareXFiles([XFile(file.path)],
        text: 'Modelo 180 — Ejercicio ${r.ejercicio}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modelo 180 — Resumen anual arrendamientos'),
        actions: [
          if (_resultado != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Exportar CSV',
              onPressed: _exportarCsv,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selector de ejercicio
          _buildEjercicioSelector(),
          const SizedBox(height: 16),

          // Nota informativa
          _buildNota(),
          const SizedBox(height: 16),

          // Botón calcular
          ElevatedButton.icon(
            onPressed: _procesando ? null : _calcular,
            icon: _procesando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.calculate),
            label: Text(_procesando
                ? 'Calculando...'
                : 'Calcular Modelo 180 — $_anio'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 24),

          // Resultados
          if (_resultado != null) ...[
            _buildResumen(_resultado!),
            const SizedBox(height: 16),
            _buildTablaArrendadores(_resultado!),
          ],
        ],
      ),
    );
  }

  Widget _buildEjercicioSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('Ejercicio fiscal:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            DropdownButton<int>(
              value: _anio,
              items: List.generate(5, (i) {
                final y = DateTime.now().year - i;
                return DropdownMenuItem(value: y, child: Text('$y'));
              }),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _anio = v;
                    _resultado = null;
                  });
                  _cargarGuardado();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNota() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[300]!),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Plazo de presentación: del 1 al 31 de enero del año siguiente. '
              'Declara todos los arrendadores con retención practicada en el ejercicio.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen(Modelo180Result r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen Modelo 180 — ${r.ejercicio}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _fila('Nº arrendadores [01]', '${r.c01}'),
            _fila(
                'Base imponible total [02]',
                '${r.c02.toStringAsFixed(2)} €'),
            _fila(
                'Retenciones practicadas [03]',
                '${r.c03.toStringAsFixed(2)} €',
                bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTablaArrendadores(Modelo180Result r) {
    if (r.arrendadores.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay facturas de arrendamiento con retención en este ejercicio.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalle por arrendador',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...r.arrendadores.map((a) => _buildArrendadorTile(a)),
          ],
        ),
      ),
    );
  }

  Widget _buildArrendadorTile(Arrendador180 a) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(a.nombre,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NIF: ${a.nif}  ·  Facturas: ${a.numFacturas}'),
          if (a.direccionInmueble.isNotEmpty) Text(a.direccionInmueble),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Base: ${a.baseAnual.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 12)),
          Text('Ret.: ${a.retencionAnual.toStringAsFixed(2)} €',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _fila(String label, String valor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(valor,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}


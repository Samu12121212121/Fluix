import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/modelo130.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/services/fiscal/mod130_calculator.dart';
import 'package:planeag_flutter/services/fiscal/mod130_exporter.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 130 — Pago fraccionado IRPF autónomos
// ═════════════════════════════════════════════════════════════════════════════

class Modelo130Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo130Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo130Screen> createState() => _Modelo130ScreenState();
}

class _Modelo130ScreenState extends State<Modelo130Screen> {
  final _svc = Mod130Calculator();
  late int _anio;
  bool _procesando = false;
  EmpresaConfig? _empresaConfig;

  @override
  void initState() {
    super.initState();
    _anio = widget.anioInicial ?? DateTime.now().year;
    _cargarEmpresa();
  }

  Future<void> _cargarEmpresa() async {
    final db = FirebaseFirestore.instance;
    final empDoc = await db.collection('empresas').doc(widget.empresaId).get();
    final fiscalDoc = await db.collection('empresas').doc(widget.empresaId)
        .collection('configuracion').doc('fiscal').get();
    if (mounted) {
      setState(() {
        _empresaConfig = EmpresaConfig.fromSources(
          empresaDoc: empDoc.data(),
          fiscalDoc: fiscalDoc.data(),
        );
      });
    }
  }

  Future<void> _calcularTrimestre(String trimestre) async {
    setState(() => _procesando = true);
    try {
      final modelo = await _svc.calcular(
        empresaId: widget.empresaId,
        ejercicio: _anio,
        trimestre: trimestre,
      );
      await _svc.guardar(widget.empresaId, modelo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Mod.130 $trimestre $_anio calculado — '
              '${modelo.resultadoTexto}'),
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
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _generarPdf(Modelo130 m) async {
    if (_empresaConfig == null) return;
    try {
      final bytes = await Mod130Exporter.generarPDF(
        modelo: m, empresa: _empresaConfig!,
      );
      final dir = await getTemporaryDirectory();
      final nombre = 'Mod130_${m.ejercicio}_${m.trimestre}.pdf';
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(archivo.path)],
          text: 'Modelo 130 — ${m.ejercicio} ${m.trimestre}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _marcarPresentado(String docId) async {
    await _svc.marcarPresentado(widget.empresaId, docId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Marcado como presentado'),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Modelo 130 — IRPF Autónomos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _anio--),
          ),
          Center(child: Text('$_anio',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _anio++),
          ),
        ],
      ),
      body: _procesando
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Modelo130>>(
              stream: _svc.obtenerTodos(widget.empresaId, _anio),
              builder: (context, snap) {
                final modelos = snap.data ?? [];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildResumenAnual(modelos),
                    const SizedBox(height: 16),
                    ...['1T', '2T', '3T', '4T'].map((t) =>
                        _buildTarjetaTrimestre(t, modelos)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildResumenAnual(List<Modelo130> modelos) {
    final totalResultado = modelos.fold(0.0, (s, m) => s + m.c19);
    final presentados = modelos.where((m) => m.estado == EstadoModelo130.presentado).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF283593), Color(0xFF3F51B5)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statAnual('Resultado acum.', '${totalResultado.toStringAsFixed(2)} €', Icons.euro),
          _statAnual('Presentados', '$presentados / 4', Icons.check_circle),
          _statAnual('Ejercicio', '$_anio', Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _statAnual(String label, String valor, IconData icono) {
    return Column(
      children: [
        Icon(icono, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildTarjetaTrimestre(String trimestre, List<Modelo130> modelos) {
    final modelo = modelos.where((m) => m.trimestre == trimestre).firstOrNull;
    final plazo = Modelo130.calcularPlazoLimite(_anio, trimestre);
    final diasRestantes = plazo.difference(DateTime.now()).inDays;
    final rango = Modelo130.rangoMeses(trimestre);
    final meses = _nombreMes(rango.mesInicio).substring(0, 3) + ' — ' +
        _nombreMes(rango.mesFin).substring(0, 3);

    Color colorEstado;
    String estadoTexto;
    if (modelo == null) {
      colorEstado = Colors.grey;
      estadoTexto = 'Pendiente';
    } else if (modelo.estado == EstadoModelo130.presentado) {
      colorEstado = Colors.green;
      estadoTexto = 'Presentado';
    } else {
      colorEstado = Colors.orange;
      estadoTexto = 'Borrador';
    }

    Color? colorPlazo;
    if (diasRestantes < 0) {
      colorPlazo = Colors.red;
    } else if (diasRestantes <= 7) {
      colorPlazo = Colors.red;
    } else if (diasRestantes <= 30) {
      colorPlazo = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF283593),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(trimestre,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meses, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Plazo: ${_fmtDate(plazo)}',
                        style: TextStyle(fontSize: 11,
                            color: colorPlazo ?? Colors.grey.shade600,
                            fontWeight: colorPlazo != null
                                ? FontWeight.w600 : FontWeight.normal)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(estadoTexto, style: TextStyle(
                      color: colorEstado, fontWeight: FontWeight.w600,
                      fontSize: 11)),
                ),
              ],
            ),

            if (modelo != null) ...[
              const Divider(height: 16),
              _datosModelo(modelo),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _botonAccion('Recalcular', Icons.refresh, Colors.indigo,
                        () => _calcularTrimestre(trimestre)),
                    const SizedBox(width: 8),
                    _botonAccion('PDF', Icons.picture_as_pdf, Colors.deepOrange,
                        () => _generarPdf(modelo)),
                    if (modelo.estado == EstadoModelo130.borrador) ...[
                      const SizedBox(width: 8),
                      _botonAccion('Presentado', Icons.check, Colors.green,
                          () => _marcarPresentado(modelo.id)),
                    ],
                  ],
                ),
              ),
            ] else ...[
              const Divider(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _calcularTrimestre(trimestre),
                  icon: const Icon(Icons.calculate, size: 18),
                  label: Text('Calcular $trimestre $_anio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _datosModelo(Modelo130 m) {
    return Column(
      children: [
        _filaDato('Ingresos acumulados', '${m.c01.toStringAsFixed(2)} €', '[01]'),
        _filaDato('Gastos acumulados', '${m.c02.toStringAsFixed(2)} €', '[02]'),
        _filaDato('Rendimiento neto', '${m.c03.toStringAsFixed(2)} €', '[03]', bold: true),
        const Divider(height: 8),
        _filaDato('20% rendimiento', '${m.c04.toStringAsFixed(2)} €', '[04]'),
        _filaDato('Pagos anteriores', '${m.c05.toStringAsFixed(2)} €', '[05]'),
        _filaDato('Retenciones soportadas', '${m.c06.toStringAsFixed(2)} €', '[06]'),
        _filaDato('Resultado previo', '${m.c07.toStringAsFixed(2)} €', '[07]', bold: true),
        const Divider(height: 8),
        _filaDato('RESULTADO FINAL', '${m.c19.toStringAsFixed(2)} €', '[19]',
            bold: true,
            color: m.c19 > 0 ? Colors.green.shade700
                : m.c19 < 0 ? Colors.orange.shade700 : null),
        if (m.esADeducir)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('A deducir: ${(-m.c19).toStringAsFixed(2)} €',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _filaDato(String label, String valor, String casilla,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Text(casilla, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal))),
          Text(valor, style: TextStyle(fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color)),
        ],
      ),
    );
  }

  Widget _botonAccion(String label, IconData icono, Color color,
      VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _nombreMes(int mes) {
    const meses = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[mes];
  }
}


import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/modelo202.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/services/fiscal/mod202_calculator.dart';
import 'package:planeag_flutter/services/fiscal/mod202_exporter.dart';
import 'package:planeag_flutter/services/fiscal/sede_aeat_urls.dart';
import 'package:planeag_flutter/widgets/presentar_aeat_widget.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 202 — Pago fraccionado IS (solo sociedades)
// ═════════════════════════════════════════════════════════════════════════════

class Modelo202Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo202Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo202Screen> createState() => _Modelo202ScreenState();
}

class _Modelo202ScreenState extends State<Modelo202Screen> {
  final _svc = Mod202Calculator();
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
    final fiscalDoc = await db
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('configuracion')
        .doc('fiscal')
        .get();
    if (mounted) {
      setState(() {
        _empresaConfig = EmpresaConfig.fromSources(
          empresaDoc: empDoc.data(),
          fiscalDoc: fiscalDoc.data(),
        );
      });
    }
  }

  Future<void> _calcularPeriodo(PeriodoModelo202 periodo) async {
    setState(() => _procesando = true);
    try {
      final modelo = await _svc.calcular(
        empresaId: widget.empresaId,
        ejercicio: _anio,
        periodo: periodo,
      );
      await _svc.guardar(widget.empresaId, modelo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Mod.202 ${periodo.codigo} $_anio — '
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

  Future<void> _generarPdf(Modelo202 m) async {
    if (_empresaConfig == null) return;
    try {
      final bytes = await Mod202Exporter.generarPDF(
        modelo: m,
        empresa: _empresaConfig!,
      );
      final dir = await getTemporaryDirectory();
      final nombre = 'Mod202_${m.ejercicio}_${m.periodo.codigo}.pdf';
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(archivo.path)],
          text: 'Modelo 202 — ${m.ejercicio} ${m.periodo.nombre}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Error PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _marcarPresentado(String docId) async {
    await _svc.marcarPresentado(widget.empresaId, docId, null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Marcado como presentado'),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Modelo 202 — IS Sociedades'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _anio--),
          ),
          Center(
              child: Text('$_anio',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _anio++),
          ),
        ],
      ),
      body: _procesando
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Modelo202>>(
              stream: _svc.obtenerTodos(widget.empresaId, _anio),
              builder: (context, snap) {
                final modelos = snap.data ?? [];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildResumenAnual(modelos),
                    const SizedBox(height: 16),
                    ...PeriodoModelo202.values
                        .map((p) => _buildTarjetaPeriodo(p, modelos)),
                    const SizedBox(height: 12),
                    PresentarAeatWidget(
                      modelo: '202',
                      urlAeat: SedeAeatUrls.mod202,
                      onJustificanteGuardado: (justificante) {
                        // Guardar justificante en el modelo correspondiente
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildResumenAnual(List<Modelo202> modelos) {
    final totalResultado =
        modelos.fold(0.0, (s, m) => s + m.resultadoIngresar);
    final presentados =
        modelos.where((m) => m.estado == EstadoModelo202.presentado).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statAnual('Total a ingresar',
              '${totalResultado.toStringAsFixed(2)} €', Icons.euro),
          _statAnual('Presentados', '$presentados / 3', Icons.check_circle),
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
        Text(valor,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildTarjetaPeriodo(
      PeriodoModelo202 periodo, List<Modelo202> modelos) {
    final modelo =
        modelos.where((m) => m.periodo == periodo).firstOrNull;
    final plazo = Modelo202.calcularPlazoLimite(_anio, periodo);
    final diasRestantes = plazo.difference(DateTime.now()).inDays;

    Color colorEstado;
    String estadoTexto;
    if (modelo == null) {
      colorEstado = Colors.grey;
      estadoTexto = 'Pendiente';
    } else if (modelo.estado == EstadoModelo202.presentado) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A148C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(periodo.codigo,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(periodo.nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Plazo: ${_fmtDate(plazo)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: colorPlazo ?? Colors.grey.shade600,
                            fontWeight: colorPlazo != null
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorEstado.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(estadoTexto,
                      style: TextStyle(
                          color: colorEstado,
                          fontWeight: FontWeight.w600,
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
                        () => _calcularPeriodo(periodo)),
                    const SizedBox(width: 8),
                    _botonAccion(
                        'PDF', Icons.picture_as_pdf, Colors.deepOrange,
                        () => _generarPdf(modelo)),
                    const SizedBox(width: 8),
                    _botonAccion(
                        'Sede AEAT', Icons.open_in_browser, Colors.teal,
                        () => SedeAeatUrls.abrir(SedeAeatUrls.mod202)),
                    if (modelo.estado == EstadoModelo202.borrador) ...[
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
                  onPressed: () => _calcularPeriodo(periodo),
                  icon: const Icon(Icons.calculate, size: 18),
                  label: Text('Calcular ${periodo.codigo} $_anio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
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

  Widget _datosModelo(Modelo202 m) {
    return Column(
      children: [
        _filaDato(
            'Base pago fraccionado', '${m.c01.toStringAsFixed(2)} €', '[01]'),
        _filaDato('18% de [01]', '${m.c03.toStringAsFixed(2)} €', '[03]',
            bold: true),
        if (m.c04 > 0)
          _filaDato('Deducciones', '${m.c04.toStringAsFixed(2)} €', '[04]'),
        if (m.c05 > 0)
          _filaDato('Retenciones', '${m.c05.toStringAsFixed(2)} €', '[05]'),
        if (m.c06 > 0)
          _filaDato('Pagos anteriores', '${m.c06.toStringAsFixed(2)} €', '[06]'),
        const Divider(height: 8),
        _filaDato('RESULTADO',
            '${m.resultadoIngresar.toStringAsFixed(2)} €', '[08]',
            bold: true,
            color: m.resultadoIngresar > 0
                ? Colors.green.shade700
                : Colors.orange.shade700),
      ],
    );
  }

  Widget _filaDato(String label, String valor, String casilla,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Text(casilla,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          bold ? FontWeight.w600 : FontWeight.normal))),
          Text(valor,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  Widget _botonAccion(
      String label, IconData icono, Color color, VoidCallback onPressed) {
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
}


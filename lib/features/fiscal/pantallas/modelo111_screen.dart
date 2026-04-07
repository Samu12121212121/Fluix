import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/modelo111.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/domain/modelos/nomina.dart';
import 'package:planeag_flutter/services/modelo111_service.dart';
import 'package:planeag_flutter/services/modelo111_pdf_service.dart';
import 'package:planeag_flutter/services/exportadores_aeat/modelo111_aeat_exporter.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 111 — Retenciones IRPF trimestrales
// ═════════════════════════════════════════════════════════════════════════════

class Modelo111Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo111Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo111Screen> createState() => _Modelo111ScreenState();
}

class _Modelo111ScreenState extends State<Modelo111Screen> {
  final _svc = Modelo111Service();
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
      final modelo = await _svc.calcularDesdeNominas(
        empresaId: widget.empresaId,
        ejercicio: _anio,
        trimestre: trimestre,
      );
      await _svc.guardar(widget.empresaId, modelo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Modelo 111 $trimestre $_anio calculado — '
              'Resultado: ${modelo.c30.toStringAsFixed(2)} €'),
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

  Future<void> _generarPdf(Modelo111 m) async {
    if (_empresaConfig == null) return;
    try {
      await Modelo111PdfService.generarYCompartir(context, m, _empresaConfig!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _generarTxt(Modelo111 m) async {
    if (_empresaConfig == null) return;
    try {
      final bytes = Modelo111AeatExporter.exportar(
          modelo: m, empresa: _empresaConfig!);
      final dir = await getTemporaryDirectory();
      final nombre = '111_${m.ejercicio}_${m.trimestre}.txt';
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(archivo.path)],
          text: 'Modelo 111 — ${m.ejercicio} ${m.trimestre} — Fichero AEAT');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error fichero AEAT: $e'), backgroundColor: Colors.red));
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
        title: const Text('Modelo 111 — Retenciones IRPF'),
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
          : StreamBuilder<List<Modelo111>>(
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

  Widget _buildResumenAnual(List<Modelo111> modelos) {
    final totalRetenciones = modelos.fold(0.0, (s, m) => s + m.c28);
    final presentados = modelos.where((m) => m.estado == EstadoModelo111.presentado).length;

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
          _statAnual('Total retenciones', '${totalRetenciones.toStringAsFixed(2)} €', Icons.euro),
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

  Widget _buildTarjetaTrimestre(String trimestre, List<Modelo111> modelos) {
    final modelo = modelos.where((m) => m.trimestre == trimestre).firstOrNull;
    final plazo = Modelo111.calcularPlazoLimite(_anio, trimestre);
    final diasRestantes = plazo.difference(DateTime.now()).inDays;
    final rango = Modelo111.rangoMeses(trimestre);
    final meses = Nomina.nombreMes(rango.mesInicio).substring(0, 3) + ' — ' +
        Nomina.nombreMes(rango.mesFin).substring(0, 3);

    Color colorEstado;
    String estadoTexto;
    if (modelo == null) {
      colorEstado = Colors.grey;
      estadoTexto = 'Pendiente';
    } else if (modelo.estado == EstadoModelo111.presentado) {
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
            // Cabecera
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

            // Datos si existe
            if (modelo != null) ...[
              const Divider(height: 16),
              _datosModelo(modelo),
              const SizedBox(height: 12),
              // Botones acción
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _botonAccion('Recalcular', Icons.refresh, Colors.indigo,
                        () => _calcularTrimestre(trimestre)),
                    const SizedBox(width: 8),
                    _botonAccion('PDF', Icons.picture_as_pdf, Colors.deepOrange,
                        () => _generarPdf(modelo)),
                    const SizedBox(width: 8),
                    _botonAccion('AEAT .txt', Icons.file_download, Colors.teal,
                        () => _generarTxt(modelo)),
                    if (modelo.estado == EstadoModelo111.borrador) ...[
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

  Widget _datosModelo(Modelo111 m) {
    return Column(
      children: [
        _filaDato('Perceptores RT dinerarios', '${m.c01}', '[01]'),
        _filaDato('Percepciones dinerarias', '${m.c02.toStringAsFixed(2)} €', '[02]'),
        _filaDato('Retenciones dinerarias', '${m.c03.toStringAsFixed(2)} €', '[03]'),
        if (m.c04 > 0) ...[
          _filaDato('Perceptores RT especie', '${m.c04}', '[04]'),
          _filaDato('Valor especie', '${m.c05.toStringAsFixed(2)} €', '[05]'),
          _filaDato('Ingresos cta especie', '${m.c06.toStringAsFixed(2)} €', '[06]'),
        ],
        const Divider(height: 8),
        _filaDato('Total retenciones', '${m.c28.toStringAsFixed(2)} €', '[28]',
            bold: true),
        if (m.c29 > 0)
          _filaDato('A deducir complementaria', '${m.c29.toStringAsFixed(2)} €', '[29]'),
        _filaDato('Resultado a ingresar', '${m.c30.toStringAsFixed(2)} €', '[30]',
            bold: true, color: m.c30 > 0 ? Colors.green.shade700 : null),
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
}




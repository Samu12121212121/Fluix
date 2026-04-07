import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/modelo390.dart';
import 'package:planeag_flutter/domain/modelos/empresa_config.dart';
import 'package:planeag_flutter/services/fiscal/mod390_calculator.dart';
import 'package:planeag_flutter/services/fiscal/mod390_exporter.dart';
import 'package:planeag_flutter/services/fiscal/mod390_posicional_service.dart';
import 'package:planeag_flutter/widgets/estado_certificado_widget.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 390 — Resumen Anual IVA
// ═════════════════════════════════════════════════════════════════════════════

class Modelo390Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo390Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo390Screen> createState() => _Modelo390ScreenState();
}

class _Modelo390ScreenState extends State<Modelo390Screen> {
  final _svc = Mod390Calculator();
  late int _anio;
  bool _procesando = false;
  EmpresaConfig? _empresaConfig;

  @override
  void initState() {
    super.initState();
    _anio = widget.anioInicial ?? DateTime.now().year - 1;
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

  Future<void> _calcular() async {
    setState(() => _procesando = true);
    try {
      final modelo = await _svc.calcular(
        empresaId: widget.empresaId,
        ejercicio: _anio,
        epigrafIAE: _empresaConfig?.epigrafIAE ?? '',
      );
      await _svc.guardar(widget.empresaId, modelo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Mod.390 $_anio calculado — '
              'Resultado: ${modelo.c86.toStringAsFixed(2)} €'),
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

  Future<void> _generarPdf(Modelo390 m) async {
    if (_empresaConfig == null) return;
    try {
      final bytes = await Mod390Exporter.generarPDF(
        modelo: m, empresa: _empresaConfig!,
      );
      final dir = await getTemporaryDirectory();
      final nombre = 'Mod390_${m.ejercicio}.pdf';
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(archivo.path)],
          text: 'Modelo 390 — Ejercicio ${m.ejercicio}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _generarCsv(Modelo390 m) async {
    try {
      final bytes = Mod390Exporter.generarCSV(m);
      final dir = await getTemporaryDirectory();
      final nombre = 'Mod390_${m.ejercicio}.csv';
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(archivo.path)],
          text: 'Modelo 390 — Ejercicio ${m.ejercicio} — CSV');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error CSV: $e'), backgroundColor: Colors.red));
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

  Future<void> _generarPosicional(Modelo390 m) async {
    setState(() => _procesando = true);
    try {
      final svcPos = Mod390PosicionalService();
      final result = await svcPos.generar(
        empresaId: widget.empresaId,
        anio: m.ejercicio,
      );
      final dir = await getTemporaryDirectory();
      final archivo = File('${dir.path}/${result.nombreFichero}');
      await archivo.writeAsBytes(result.bytes);
      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: 'Modelo 390 ${m.ejercicio} — Fichero posicional AEAT',
      );
      if (mounted && result.alertas.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ ${result.alertas.first}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Modelo 390 — Resumen Anual IVA'),
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
          : StreamBuilder<Modelo390?>(
              stream: _svc.obtener(widget.empresaId, _anio),
              builder: (context, snap) {
                final modelo = snap.data;
                if (modelo == null) {
                  return _buildSinDatos();
                }
                return _buildConDatos(modelo);
              },
            ),
    );
  }

  Widget _buildSinDatos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.summarize_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No hay Mod.390 para $_anio',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Plazo: 1–30 enero ${_anio + 1}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _calcular,
            icon: const Icon(Icons.calculate),
            label: Text('Calcular Mod.390 $_anio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00695C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConDatos(Modelo390 m) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Estado del certificado digital
        EstadoCertificadoWidget(empresaId: widget.empresaId),
        // Alertas
        if (m.alertas.isNotEmpty)
          ...m.alertas.map((a) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(a, style: TextStyle(fontSize: 12,
                    color: Colors.orange.shade800))),
              ],
            ),
          )),

        // Resultado destacado
        _buildResultado(m),
        const SizedBox(height: 16),

        // IVA Devengado
        _buildSeccion('IVA DEVENGADO', [
          _fila('[01/02]', 'Base / Cuota 4%', m.c01, m.c02),
          _fila('[03/04]', 'Base / Cuota 10%', m.c03, m.c04),
          _fila('[05/06]', 'Base / Cuota 21%', m.c05, m.c06),
          if (m.c22 > 0) _fila('[21/22]', 'Adq. intracom. bienes', m.c21, m.c22),
          if (m.c24 > 0) _fila('[23/24]', 'Adq. intracom. servicios', m.c23, m.c24),
          if (m.c28 > 0) _fila('[27/28]', 'ISP otros supuestos', m.c27, m.c28),
          _filaTotal('[47]', 'TOTAL DEVENGADO', m.c47),
        ]),
        const SizedBox(height: 12),

        // IVA Deducible
        _buildSeccion('IVA DEDUCIBLE', [
          _filaDato2('[49]', 'Cuota deducible interiores', m.c49),
          if (m.c51 > 0) _filaDato2('[51]', 'Cuota deducible inversión', m.c51),
          _filaTotal('[64]', 'TOTAL DEDUCCIONES', m.c64),
          _filaTotal('[65]', 'RESULTADO RÉG. GENERAL', m.c65),
        ]),
        const SizedBox(height: 12),

        // Liquidación
        _buildSeccion('LIQUIDACIÓN ANUAL', [
          _filaDato2('[84]', 'Suma resultados', m.c84),
          _filaDato2('[85]', 'Compensación año anterior', m.c85),
          _filaTotal('[86]', 'RESULTADO', m.c86),
        ]),
        const SizedBox(height: 12),

        // Volumen
        _buildSeccion('VOLUMEN DE OPERACIONES', [
          _filaDato2('[99]', 'Operaciones régimen general', m.c99),
        ]),
        const SizedBox(height: 16),

        // Botones
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _calcular,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Recalcular'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _generarPdf(m),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _generarCsv(m),
                icon: const Icon(Icons.table_chart, size: 18),
                label: const Text('CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Botón fichero posicional AEAT
        ElevatedButton.icon(
          onPressed: _procesando ? null : () => _generarPosicional(m),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Descargar fichero posicional (.390)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
        ),
        if (m.estado == EstadoModelo390.borrador) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _marcarPresentado(m.id),
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Marcar como presentado'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultado(Modelo390 m) {
    final esNeg = m.c86 < 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: esNeg
              ? [Colors.orange.shade700, Colors.orange.shade400]
              : [const Color(0xFF00695C), const Color(0xFF26A69A)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mod.390 — $_anio',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(esNeg ? 'A devolver / compensar' : 'A ingresar',
                  style: const TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text('Estado: ${m.estado.etiqueta}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          Text('${m.c86.toStringAsFixed(2)} €',
              style: const TextStyle(color: Colors.white, fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSeccion(String titulo, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
            const Divider(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _fila(String casilla, String label, double base, double cuota) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 55, child: Text(casilla,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500))),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          SizedBox(width: 80, child: Text('${base.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 11), textAlign: TextAlign.end)),
          SizedBox(width: 80, child: Text('${cuota.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _filaDato2(String casilla, String label, double valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 45, child: Text(casilla,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500))),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          Text('${valor.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _filaTotal(String casilla, String label, double valor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          SizedBox(width: 45, child: Text(casilla,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700))),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Text('${valor.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


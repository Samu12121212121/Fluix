import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../services/mod_303_service.dart';
import '../../../services/fiscal/sede_aeat_urls.dart';
import '../../../widgets/presentar_aeat_widget.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 303 — Autoliquidación IVA trimestral
// ═════════════════════════════════════════════════════════════════════════════

class Modelo303Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo303Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo303Screen> createState() => _Modelo303ScreenState();
}

class _Modelo303ScreenState extends State<Modelo303Screen> {
  final _svc = Mod303Service();
  final _db = FirebaseFirestore.instance;
  late int _anio;
  bool _procesando = false;

  // Datos de empresa para exportación AEAT
  String _nifEmpresa = '';
  String _nombreEmpresa = '';

  @override
  void initState() {
    super.initState();
    _anio = widget.anioInicial ?? DateTime.now().year;
    _cargarEmpresa();
  }

  Future<void> _cargarEmpresa() async {
    final empDoc = await _db.collection('empresas').doc(widget.empresaId).get();
    final data = empDoc.data();
    if (data != null && mounted) {
      final perfil = data['perfil'] as Map<String, dynamic>? ?? {};
      final fiscal = data['datos_fiscales'] as Map<String, dynamic>? ?? {};
      setState(() {
        _nifEmpresa = (fiscal['nif'] ?? fiscal['cif'] ?? '').toString();
        _nombreEmpresa = (perfil['nombre'] ?? data['nombre'] ?? '').toString();
      });
    }
  }

  Future<Map<String, dynamic>?> _calcularTrimestre(int trimestre) async {
    setState(() => _procesando = true);
    try {
      final datos = await _svc.calcularMod303(
        empresaId: widget.empresaId,
        anio: _anio,
        trimestre: trimestre,
      );

      // Guardar resultado en Firestore
      await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('modelos_fiscales')
          .doc('303_${_anio}_${trimestre}T')
          .set({
        ...datos..remove('facturas_emitidas')..remove('facturas_recibidas'),
        'modelo': '303',
        'ejercicio': _anio,
        'trimestre': '${trimestre}T',
        'fecha_calculo': FieldValue.serverTimestamp(),
        'estado': 'calculado',
      }, SetOptions(merge: true));

      if (mounted) {
        final iva = (datos['iva_303'] as num?)?.toDouble() ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Mod.303 ${trimestre}T $_anio — '
              'Resultado: ${iva.toStringAsFixed(2)} €'),
          backgroundColor: Colors.green,
        ));
      }
      return datos;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return null;
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _descargarFichero303(int trimestre, Map<String, dynamic> data) async {
    if (_nifEmpresa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Configura el NIF de la empresa antes de generar el fichero'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _procesando = true);
    try {
      debugPrint('📄 303: iniciando generación — ${trimestre}T $_anio');

      final contenido = await _svc.generarMod303Dr303e26v101(
        empresaId: widget.empresaId,
        nifEmpresa: _nifEmpresa,
        nombreEmpresa: _nombreEmpresa,
        anio: _anio,
        trimestre: trimestre,
      );

      final baseImponible = (data['base_general'] as num?)?.toDouble() ?? 0;
      final cuota = (data['iva_303'] as num?)?.toDouble() ?? 0;
      debugPrint(
          '📄 303: datos calculados OK — base: ${baseImponible.toStringAsFixed(2)}, cuota: ${cuota.toStringAsFixed(2)}');

      final bytes = contenido.codeUnits;
      debugPrint('📄 303: fichero generado — ${bytes.length} bytes');

      final dir = await getTemporaryDirectory();
      final nombre = 'MOD303_${_anio}_${trimestre}T.txt';
      final archivo = File('${dir.path}/$nombre');
      await archivo.writeAsBytes(bytes);

      debugPrint('📄 303: compartiendo fichero — ${archivo.path}');
      await Share.shareXFiles(
        [XFile(archivo.path)],
        subject: 'Modelo 303 — ${trimestre}T $_anio',
        text: 'Fichero posicional AEAT Mod.303 — ${trimestre}T $_anio. '
            'Importa en la Sede Electrónica (Pre303).',
      );
    } catch (e) {
      debugPrint('📄 303: ERROR — $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al generar el Modelo 303: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _marcarPresentado(int trimestre) async {
    await _db
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('modelos_fiscales')
        .doc('303_${_anio}_${trimestre}T')
        .update({'estado': 'presentado', 'fecha_presentacion': FieldValue.serverTimestamp()});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Marcado como presentado'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Modelo 303 — Autoliquidación IVA'),
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: _procesando
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('empresas')
                  .doc(widget.empresaId)
                  .collection('modelos_fiscales')
                  .where('modelo', isEqualTo: '303')
                  .where('ejercicio', isEqualTo: _anio)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildResumenAnual(docs),
                    const SizedBox(height: 16),
                    ...[1, 2, 3, 4].map((t) => _buildTarjetaTrimestre(t, docs)),
                    const SizedBox(height: 12),
                    PresentarAeatWidget(
                      modelo: '303',
                      urlAeat: SedeAeatUrls.mod303,
                      onJustificanteGuardado: (justificante) {
                        // Se guarda desde marcarPresentado
                      },
                    ),
                  ],
                );
              },
            ),
      ),  // GestureDetector
    );
  }

  Widget _buildResumenAnual(List<QueryDocumentSnapshot> docs) {
    double totalIva = 0;
    int presentados = 0;
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      totalIva += (data['iva_303'] as num?)?.toDouble() ?? 0;
      if (data['estado'] == 'presentado') presentados++;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statAnual('IVA acumulado', '${totalIva.toStringAsFixed(2)} €', Icons.euro),
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

  Widget _buildTarjetaTrimestre(int trimestre, List<QueryDocumentSnapshot> docs) {
    final doc = docs.where((d) => (d.data() as Map<String, dynamic>)['trimestre'] == '${trimestre}T').firstOrNull;
    final data = doc?.data() as Map<String, dynamic>?;
    final plazo = _calcularPlazoLimite(_anio, trimestre);
    final diasRestantes = plazo.difference(DateTime.now()).inDays;

    final meses = _rangoMeses(trimestre);
    Color colorEstado;
    String estadoTexto;

    if (data == null) {
      colorEstado = Colors.grey;
      estadoTexto = 'Pendiente';
    } else if (data['estado'] == 'presentado') {
      colorEstado = Colors.green;
      estadoTexto = 'Presentado';
    } else {
      colorEstado = Colors.orange;
      estadoTexto = 'Calculado';
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
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${trimestre}T',
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

            if (data != null) ...[
              const Divider(height: 16),
              _datosModelo(data),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _botonAccion('Recalcular', Icons.refresh, Colors.indigo,
                        () => _calcularTrimestre(trimestre)),
                    const SizedBox(width: 8),
                    _botonAccion('Descargar AEAT', Icons.file_download, Colors.deepOrange,
                        () => _descargarFichero303(trimestre, data)),
                    const SizedBox(width: 8),
                    _botonAccion('Sede AEAT', Icons.open_in_browser, Colors.teal,
                        () => SedeAeatUrls.abrir(SedeAeatUrls.mod303)),
                    if (data['estado'] != 'presentado') ...[
                      const SizedBox(width: 8),
                      _botonAccion('Presentado', Icons.check, Colors.green,
                          () => _marcarPresentado(trimestre)),
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
                  label: Text('Calcular ${trimestre}T $_anio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
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

  Widget _datosModelo(Map<String, dynamic> d) {
    final fmt = NumberFormat('#,##0.00', 'es_ES');
    final baseGen = (d['base_general'] as num?)?.toDouble() ?? 0;
    final cuotaGen = (d['cuota_general'] as num?)?.toDouble() ?? 0;
    final baseRed = (d['base_reducida'] as num?)?.toDouble() ?? 0;
    final cuotaRed = (d['cuota_reducida'] as num?)?.toDouble() ?? 0;
    final baseSup = (d['base_super_reducida'] as num?)?.toDouble() ?? 0;
    final cuotaSup = (d['cuota_super_reducida'] as num?)?.toDouble() ?? 0;
    final totalRep = (d['total_repercutido'] as num?)?.toDouble() ?? 0;
    final ivaSop = (d['iva_soportado'] as num?)?.toDouble() ?? 0;
    final iva303 = (d['iva_303'] as num?)?.toDouble() ?? 0;
    final nEmit = (d['num_facturas_emitidas'] as num?)?.toInt() ?? 0;
    final nRec = (d['num_facturas_recibidas'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        // IVA repercutido
        _seccion('IVA REPERCUTIDO'),
        if (baseGen > 0)
          _filaDato('Base 21%', '${fmt.format(baseGen)} €', '[01]'),
        if (cuotaGen > 0)
          _filaDato('Cuota 21%', '${fmt.format(cuotaGen)} €', '[03]'),
        if (baseRed > 0)
          _filaDato('Base 10%', '${fmt.format(baseRed)} €', '[04]'),
        if (cuotaRed > 0)
          _filaDato('Cuota 10%', '${fmt.format(cuotaRed)} €', '[06]'),
        if (baseSup > 0)
          _filaDato('Base 4%', '${fmt.format(baseSup)} €', '[07]'),
        if (cuotaSup > 0)
          _filaDato('Cuota 4%', '${fmt.format(cuotaSup)} €', '[09]'),
        _filaDato('Total repercutido', '${fmt.format(totalRep)} €', '[27]',
            bold: true),
        const Divider(height: 8),
        // IVA soportado
        _seccion('IVA SOPORTADO DEDUCIBLE'),
        _filaDato('IVA soportado', '${fmt.format(ivaSop)} €', '[29]'),
        const Divider(height: 8),
        // Resultado
        _filaDato('RESULTADO', '${fmt.format(iva303)} €', '[71]',
            bold: true,
            color: iva303 > 0 ? Colors.red.shade700 : Colors.green.shade700),
        const SizedBox(height: 4),
        Text('$nEmit fact. emitidas · $nRec fact. recibidas',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        if (d['criterio_iva'] == 'caja')
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('📋 Criterio de caja aplicado',
                style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
          ),
      ],
    );
  }

  Widget _seccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Text(titulo,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
              color: Colors.grey.shade600, letterSpacing: 0.5)),
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

  static DateTime _calcularPlazoLimite(int anio, int trimestre) {
    // Plazos AEAT: 1T→20 abril, 2T→20 julio, 3T→20 octubre, 4T→30 enero sig.
    switch (trimestre) {
      case 1: return DateTime(anio, 4, 20);
      case 2: return DateTime(anio, 7, 20);
      case 3: return DateTime(anio, 10, 20);
      case 4: return DateTime(anio + 1, 1, 30);
      default: return DateTime(anio, 4, 20);
    }
  }

  static String _rangoMeses(int trimestre) {
    const rangos = {
      1: 'Ene — Mar',
      2: 'Abr — Jun',
      3: 'Jul — Sep',
      4: 'Oct — Dic',
    };
    return rangos[trimestre] ?? '';
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}






import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/fidelizacion_service.dart';

class PantallaQRNegocio extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;

  const PantallaQRNegocio({super.key, required this.negocioId, required this.negocioNombre});

  @override
  State<PantallaQRNegocio> createState() => _PantallaQRNegocioState();
}

class _PantallaQRNegocioState extends State<PantallaQRNegocio> {
  final GlobalKey _qrKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151932),
        title: const Text('QR del Negocio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<String?>(
        future: FidelizacionService.obtenerPrograma(widget.negocioId).then((p) => p?.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC8)));
          }

          final programaId = snapshot.data;
          if (programaId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 80, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text('No hay programa de fidelización activo', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                  ],
                ),
              ),
            );
          }

          final qrData = jsonEncode({'tipo': 'checkin', 'negocio_id': widget.negocioId, 'programa_id': programaId});

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(widget.negocioNombre, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 32),

                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(data: qrData, version: QrVersions.auto, size: 300, backgroundColor: Colors.white),
                        const SizedBox(height: 16),
                        const Text('Escanea para ganar sellos',
                            style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _compartirQR(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFC8),
                      foregroundColor: const Color(0xFF0A0F23),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2139),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2E45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.lightbulb_outline, color: Color(0xFFFFBB00), size: 24),
                          SizedBox(width: 12),
                          Text('Instrucciones', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInstruccion('1', 'Imprime este QR en tamaño A4'),
                      _buildInstruccion('2', 'Colócalo en un lugar visible (mostrador, entrada)'),
                      _buildInstruccion('3', 'Los clientes lo escanean al visitarte'),
                      _buildInstruccion('4', 'Acumulan sellos automáticamente'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstruccion(String numero, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00FFC8)),
            child: Center(child: Text(numero, style: const TextStyle(color: Color(0xFF0A0F23), fontSize: 12, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14))),
        ],
      ),
    );
  }

  Future<void> _compartirQR() async {
    try {
      final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_${widget.negocioId}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Escanea este QR para ganar sellos en ${widget.negocioNombre}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e'), backgroundColor: const Color(0xFFFF2850)),
        );
      }
    }
  }
}


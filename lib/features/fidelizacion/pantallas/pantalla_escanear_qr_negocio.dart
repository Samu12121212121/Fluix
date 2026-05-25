import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:confetti/confetti.dart';
import '../../../services/fidelizacion_service.dart';

class PantallaEscanearQRNegocio extends StatefulWidget {
  final String negocioId;
  const PantallaEscanearQRNegocio({super.key, required this.negocioId});
  @override
  State<PantallaEscanearQRNegocio> createState() => _PantallaEscanearQRNegocioState();
}

class _PantallaEscanearQRNegocioState extends State<PantallaEscanearQRNegocio> {
  late MobileScannerController _camera;
  late ConfettiController _confetti;
  bool _scanning = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _camera = MobileScannerController();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _camera.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text('Escanear QR Negocio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _camera.toggleTorch())],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: (c) {
              if (!_scanning || _processing) return;
              final code = c.barcodes.firstOrNull?.rawValue;
              if (code != null) _procesarQR(code);
            },
          ),
          Positioned(
            bottom: 60, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner, color: Color(0xFF00FFC8), size: 48),
                  const SizedBox(height: 12),
                  const Text('Apunta al QR del negocio', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('El QR está en el mostrador o entrada', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            ),
          ),
          Center(child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            colors: const [Color(0xFFFFBB00), Color(0xFF00FFC8), Color(0xFFFF3296), Colors.white],
            numberOfParticles: 50,
            gravity: 0.3,
          )),
        ],
      ),
    );
  }

  Future<void> _procesarQR(String qrData) async {
    setState(() { _processing = true; _scanning = false; });
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      if (data['tipo'] != 'checkin') { _mostrarError('QR no válido para check-in'); return; }
      
      final negocioId = data['negocio_id'] as String?;
      final programaId = data['programa_id'] as String?;
      
      if (negocioId == null || programaId == null) { _mostrarError('QR incompleto'); return; }
      if (negocioId != widget.negocioId) { _mostrarError('Este QR es de otro negocio'); return; }
      
      final resultado = await FidelizacionService.hacerCheckin(negocioId: negocioId, programaId: programaId);
      if (!mounted) return;
      
      if (resultado.exito) {
        if (resultado.recompensaDesbloqueada) _confetti.play();
        _mostrarExito(resultado.mensaje, resultado.recompensaDesbloqueada);
      } else {
        _mostrarError(resultado.mensaje);
      }
    } catch (e) {
      _mostrarError('Error al procesar QR');
    } finally {
      setState(() => _processing = false);
    }
  }

  void _mostrarExito(String msg, bool recompensa) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2139),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: recompensa ? 
                    [const Color(0xFFFFBB00), const Color(0xFFFF8800)] :
                    [const Color(0xFF00FFC8), const Color(0xFF00CCB8)]),
              ),
              child: Icon(recompensa ? Icons.card_giftcard : Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context, recompensa); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarError(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2139),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF2850), size: 64),
            const SizedBox(height: 16),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); setState(() => _scanning = true); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


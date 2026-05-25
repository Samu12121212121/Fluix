import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/qr_canje_model.dart';
import '../../../services/fidelizacion_service.dart';

class PantallaEscanearQRCanje extends StatefulWidget {
  final String negocioId;

  const PantallaEscanearQRCanje({super.key, required this.negocioId});

  @override
  State<PantallaEscanearQRCanje> createState() => _PantallaEscanearQRCanjeState();
}

class _PantallaEscanearQRCanjeState extends State<PantallaEscanearQRCanje> {
  late MobileScannerController _camera;
  bool _scanning = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _camera = MobileScannerController();
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text('Escanear Canje Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                  const Icon(Icons.qr_code_scanner, color: Color(0xFFFFBB00), size: 48),
                  const SizedBox(height: 12),
                  const Text('Escanea el QR del cliente', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('El cliente te mostrará su QR de canje', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarQR(String qrId) async {
    setState(() { _processing = true; _scanning = false; });

    try {
      // Obtener QR de canje
      final qrSnap = await FidelizacionService.escucharQrCanje(widget.negocioId, qrId).first;
      
      if (qrSnap == null) {
        _mostrarError('QR no encontrado');
        return;
      }

      if (qrSnap.estaExpirado) {
        _mostrarError('QR expirado');
        return;
      }

      if (qrSnap.estaCanjeado) {
        _mostrarError('Ya fue canjeado');
        return;
      }

      // Mostrar confirmación
      _mostrarConfirmacion(qrSnap);
    } catch (e) {
      _mostrarError('Error al procesar QR');
    } finally {
      setState(() => _processing = false);
    }
  }

  void _mostrarConfirmacion(QrCanjeModel qr) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2139),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (qr.clienteFoto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: CachedNetworkImage(
                  imageUrl: qr.clienteFoto!,
                  width: 80, height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF2A2E45)),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF2A2E45),
                    child: const Icon(Icons.person, size: 40, color: Colors.white70),
                  ),
                ),
              )
            else
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2A2E45)),
                child: Center(
                  child: Text(qr.clienteNombre[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                ),
              ),
            const SizedBox(height: 16),
            Text(qr.clienteNombre, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F23),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFBB00), width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(_getRecompensaIcon(qr.recompensaTipo), color: const Color(0xFFFFBB00), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(qr.recompensaTitulo,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(qr.recompensaDescripcion,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFBB00).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      qr.textoValor,
                      style: const TextStyle(color: Color(0xFFFFBB00), fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('¿Confirmar canje de esta recompensa?', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () { Navigator.pop(context); setState(() => _scanning = true); },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6B6E82)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B6E82), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmarCanje(qr.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFC8),
                      foregroundColor: const Color(0xFF0A0F23),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarCanje(String qrId) async {
    Navigator.pop(context);

    final resultado = await FidelizacionService.confirmarCanje(negocioId: widget.negocioId, qrId: qrId);

    if (!mounted) return;

    if (resultado.exito) {
      _mostrarExito(resultado.mensaje);
    } else {
      _mostrarError(resultado.mensaje);
    }
  }

  void _mostrarExito(String msg) {
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF00FFC8), Color(0xFF00CCB8)]),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
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

  IconData _getRecompensaIcon(String tipo) {
    switch (tipo) {
      case 'descuento_porcentaje': return Icons.percent;
      case 'visita_gratis': return Icons.free_breakfast;
      case 'producto': return Icons.redeem;
      default: return Icons.card_giftcard;
    }
  }
}


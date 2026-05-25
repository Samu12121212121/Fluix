import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../models/programa_fidelizacion_model.dart';
import '../../../models/qr_canje_model.dart';
import '../../../services/fidelizacion_service.dart';

class PantallaQRCanje extends StatefulWidget {
  final String negocioId;
  final String qrId;
  final RecompensaPrograma recompensa;

  const PantallaQRCanje({
    super.key,
    required this.negocioId,
    required this.qrId,
    required this.recompensa,
  });

  @override
  State<PantallaQRCanje> createState() => _PantallaQRCanjeState();
}

class _PantallaQRCanjeState extends State<PantallaQRCanje> {
  Timer? _timer;
  int _segundosRestantes = 600;

  @override
  void initState() {
    super.initState();
    _iniciarContador();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarContador() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 0) {
        setState(() => _segundosRestantes--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151932),
        title: const Text('QR de Canje', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QrCanjeModel?>(
        stream: FidelizacionService.escucharQrCanje(widget.negocioId, widget.qrId),
        builder: (context, snapshot) {
          final qrCanje = snapshot.data;

          if (qrCanje?.estaCanjeado == true) {
            return _buildCanjeado();
          }

          if (qrCanje?.estaExpirado == true || _segundosRestantes == 0) {
            return _buildExpirado();
          }

          return _buildQRActivo();
        },
      ),
    );
  }

  Widget _buildQRActivo() {
    final minutos = _segundosRestantes ~/ 60;
    final segundos = _segundosRestantes % 60;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2139),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFFBB00), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Color(0xFFFFBB00), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Expira en ${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Color(0xFFFFBB00), fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Text(
            widget.recompensa.titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            widget.recompensa.descripcion,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFC8).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: QrImageView(
              data: widget.qrId,
              version: QrVersions.auto,
              size: 280,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
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
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF00FFC8), size: 32),
                const SizedBox(height: 12),
                const Text(
                  'Muéstrale este QR al negocio para confirmar tu canje',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'El negocio escaneará este QR desde su app',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanjeado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00FFC8), Color(0xFF00CCB8)],
                ),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 80),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Recompensa canjeada!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Disfruta de tu ${widget.recompensa.titulo}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Volver', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, color: Color(0xFFFF2850), size: 80),
            const SizedBox(height: 24),
            const Text(
              'QR Expirado',
              style: TextStyle(color: Color(0xFFFF2850), fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'El código QR ha expirado.\nGenera uno nuevo desde tu tarjeta de sellos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Volver', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


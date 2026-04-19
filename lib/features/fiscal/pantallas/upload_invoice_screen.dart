import 'package:flutter/material.dart';
import '../../../services/fiscal/fiscal_capture_service.dart';
import '../../../services/fiscal/fiscal_upload_service.dart';
import 'invoice_result_screen.dart';

class UploadInvoiceScreen extends StatefulWidget {
  final String empresaId;

  const UploadInvoiceScreen({super.key, required this.empresaId});

  @override
  State<UploadInvoiceScreen> createState() => _UploadInvoiceScreenState();
}

class _UploadInvoiceScreenState extends State<UploadInvoiceScreen> {
  final _captureService = FiscalCaptureService();
  final _uploadService = FiscalUploadService();

  UploadProgress? _progress;
  String? _errorMessage;
  String _tipoDocumento = 'gasto'; // 'gasto' | 'ingreso'

  Future<void> _handleCapture(CaptureSource source) async {
    setState(() {
      _errorMessage = null;
      _progress = UploadProgress(step: 'Abriendo...', percent: 0);
    });

    try {
      final captured = await _captureService.capture(source);
      if (captured == null) {
        setState(() => _progress = null);
        return;
      }

      final result = await _uploadService.uploadAndProcess(
        empresaId: widget.empresaId,
        captured: captured,
        tipoDocumento: _tipoDocumento,
        onProgress: (p) => setState(() => _progress = p),
      );

      if (!mounted) return;

      final resultStatus = result['status'] as String? ?? '';

      // Si la CF detectó duplicado confirmado, mostrar aviso sin navegar
      if (resultStatus == 'duplicate') {
        setState(() {
          _progress = null;
          _errorMessage =
              '⚠️ Factura duplicada: ya existe una factura con el mismo '
              'NIF y número de factura. No se ha creado una nueva.';
        });
        return;
      }

      // Extraer transaction_id del resultado de la CF
      final txId = result['transaction_id'] as String?
          ?? result['txId'] as String?
          ?? '';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceResultScreen(
            empresaId: widget.empresaId,
            transactionId: txId,
            cfResult: result,
          ),
        ),
      );
    } on DuplicateDocumentException catch (e) {
      setState(() {
        _progress = null;
        _errorMessage = e.message;
      });
    } on FileTooLargeException catch (e) {
      setState(() {
        _progress = null;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _progress = null;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva factura')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _progress != null
              ? _buildProgressView()
              : _buildCaptureOptions(),
        ),
      ),
    );
  }

  Widget _buildCaptureOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.receipt_long, size: 80, color: Colors.blue[300]),
        const SizedBox(height: 16),
        const Text(
          '¿Cómo quieres añadir la factura?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'La IA la leerá y contabilizará sola',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Selector gasto / ingreso
        _buildTipoSelector(),
        const SizedBox(height: 20),

        _buildOption(
          icon: Icons.camera_alt,
          title: 'Hacer foto',
          subtitle: 'Para tickets o facturas en papel',
          color: Colors.blue,
          onTap: () => _handleCapture(CaptureSource.cameraPhoto),
        ),
        const SizedBox(height: 12),
        _buildOption(
          icon: Icons.picture_as_pdf,
          title: 'Subir PDF',
          subtitle: 'Facturas recibidas por email',
          color: Colors.red,
          onTap: () => _handleCapture(CaptureSource.pdfFromFiles),
        ),
        const SizedBox(height: 12),
        _buildOption(
          icon: Icons.photo_library,
          title: 'Elegir imagen',
          subtitle: 'De la galería del teléfono',
          color: Colors.purple,
          onTap: () => _handleCapture(CaptureSource.gallery),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 20),
          _buildErrorBanner(_errorMessage!),
        ],
      ],
    );
  }

  Widget _buildTipoSelector() {
    return Row(
      children: [
        Expanded(
          child: _chipTipo('gasto', 'Gasto / compra', Icons.arrow_downward,
              Colors.red),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _chipTipo('ingreso', 'Ingreso / venta', Icons.arrow_upward,
              Colors.green),
        ),
      ],
    );
  }

  Widget _chipTipo(
      String value, String label, IconData icon, Color color) {
    final selected = _tipoDocumento == value;
    return GestureDetector(
      onTap: () => setState(() => _tipoDocumento = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : Colors.grey[300]!, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: selected ? color : Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red[900])),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _progress!.percent,
                  strokeWidth: 6,
                ),
                Text(
                  '${(_progress!.percent * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(_progress!.step, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _tipoDocumento == 'gasto'
                ? 'Contabilizando gasto...'
                : 'Contabilizando ingreso...',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}



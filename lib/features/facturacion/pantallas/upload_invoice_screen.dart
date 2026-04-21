import 'package:flutter/material.dart';
import '../../../services/fiscal/fiscal_capture_service.dart';
import '../../../services/fiscal/fiscal_upload_service.dart';
import '../../fiscal/pantallas/review_transaction_screen.dart';

/// Tipo de documento: gasto (factura recibida) o ingreso (factura emitida)
enum TipoDocumento { gasto, ingreso }

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
  _ResultadoIA? _resultado;

  // Paso 1: elegir gasto o ingreso
  TipoDocumento? _tipoDocumento;

  Future<void> _handleCapture(CaptureSource source) async {
    setState(() {
      _errorMessage = null;
      _resultado = null;
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
        tipoDocumento: _tipoDocumento!.name, // 'gasto' o 'ingreso'
        onProgress: (p) => setState(() => _progress = p),
      );

      if (!mounted) return;

      final txId = result['transaction_id']?.toString();
      final status = (result['status'] ?? 'needs_review').toString();
      final autoPublished = result['auto_published'] == true;

      setState(() {
        _progress = null;
        _resultado = _ResultadoIA(
          transactionId: txId,
          status: status,
          autoPublished: autoPublished,
          warnings: (result['warnings'] as List?)?.map((e) => e.toString()).toList() ?? [],
          errors: (result['errors'] as List?)?.map((e) => e.toString()).toList() ?? [],
        );
      });

      // Si fue auto-aprobado (≥92% confianza), volver directamente tras 2s
      if (status == 'posted') {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pop(context, true);
      }
      // Si needs_review, se queda en pantalla para que el usuario decida
    } on DuplicateDocumentException catch (e) {
      setState(() { _progress = null; _errorMessage = e.message; });
    } on FileTooLargeException catch (e) {
      setState(() { _progress = null; _errorMessage = e.message; });
    } catch (e) {
      setState(() { _progress = null; _errorMessage = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir documento'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _resultado != null
              ? _buildResultView()
              : _progress != null
                  ? _buildProgressView()
                  : _tipoDocumento == null
                      ? _buildSelectorTipo()
                      : _buildCaptureOptions(),
        ),
      ),
    );
  }

  // ── PASO 1: Selector Gasto / Ingreso ────────────────────────────────────

  Widget _buildSelectorTipo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.document_scanner, size: 72, color: Color(0xFF0D47A1)),
        const SizedBox(height: 20),
        const Text(
          '¿Qué tipo de documento es?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'La IA lo clasificará y contabilizará automáticamente',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        _buildTipoCard(
          tipo: TipoDocumento.gasto,
          icon: Icons.arrow_downward_rounded,
          title: 'Gasto / Compra',
          subtitle: 'Facturas de proveedores, tickets, suministros...',
          color: Colors.red[700]!,
          bgColor: Colors.red[50]!,
        ),
        const SizedBox(height: 16),
        _buildTipoCard(
          tipo: TipoDocumento.ingreso,
          icon: Icons.arrow_upward_rounded,
          title: 'Ingreso / Venta',
          subtitle: 'Facturas emitidas a clientes, albaranes...',
          color: Colors.green[700]!,
          bgColor: Colors.green[50]!,
        ),
      ],
    );
  }

  Widget _buildTipoCard({
    required TipoDocumento tipo,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _tipoDocumento = tipo),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: color,
                    )),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // ── PASO 2: Elegir formato ───────────────────────────────────────────────

  Widget _buildCaptureOptions() {
    final esGasto = _tipoDocumento == TipoDocumento.gasto;
    final color = esGasto ? Colors.red[700]! : Colors.green[700]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header con indicador del tipo seleccionado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(esGasto ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                esGasto ? 'Gasto / Compra' : 'Ingreso / Venta',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _tipoDocumento = null),
                child: Text('Cambiar', style: TextStyle(color: color, fontSize: 12, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '¿Cómo quieres subir el documento?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'La IA lo leerá y contabilizará sola',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildOption(
          icon: Icons.camera_alt,
          title: 'Hacer foto',
          subtitle: 'Tickets o facturas en papel',
          color: Colors.blue,
          onTap: () => _handleCapture(CaptureSource.cameraPhoto),
        ),
        const SizedBox(height: 10),
        _buildOption(
          icon: Icons.picture_as_pdf,
          title: 'Subir PDF',
          subtitle: 'Facturas recibidas por email',
          color: Colors.red[800]!,
          onTap: () => _handleCapture(CaptureSource.pdfFromFiles),
        ),
        const SizedBox(height: 10),
        _buildOption(
          icon: Icons.photo_library,
          title: 'Elegir imagen',
          subtitle: 'De la galería del teléfono',
          color: Colors.purple,
          onTap: () => _handleCapture(CaptureSource.gallery),
        ),
        const SizedBox(height: 10),
        _buildOption(
          icon: Icons.table_chart,
          title: 'Importar CSV / Excel',
          subtitle: 'Importación masiva de facturas',
          color: Colors.teal,
          onTap: () => _handleCapture(CaptureSource.csvFromFiles),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 20),
          _buildErrorBanner(_errorMessage!),
        ],
      ],
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
          Expanded(child: Text(message, style: TextStyle(color: Colors.red[900]))),
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
                CircularProgressIndicator(value: _progress!.percent, strokeWidth: 6),
                Text('${(_progress!.percent * 100).toInt()}%',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(_progress!.step, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final ok = _resultado!.status == 'posted';
    final needsReview = _resultado!.status == 'needs_review';
    final autoPublished = _resultado!.autoPublished;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 80,
            color: ok ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),

          // Título principal
          Text(
            ok
                ? autoPublished
                    ? '✅ Contabilizado automáticamente'
                    : '✅ Documento registrado'
                : '⚠️ Pendiente de revisión',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),

          // Badge de confianza si fue auto-aprobado
          if (ok && autoPublished) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '🤖 Confianza IA ≥ 92% — aprobado automáticamente',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ),
          ],

          if (_resultado!.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._resultado!.warnings.map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('⚠️ $w',
                      style: TextStyle(color: Colors.orange[800], fontSize: 13),
                      textAlign: TextAlign.center),
                )),
          ],
          if (_resultado!.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._resultado!.errors.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('❌ $e',
                      style: TextStyle(color: Colors.red[800], fontSize: 13),
                      textAlign: TextAlign.center),
                )),
          ],

          const SizedBox(height: 24),

          // Botón de revisar si needs_review y tenemos transactionId
          if (needsReview && _resultado!.transactionId != null) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewTransactionScreen(
                      empresaId: widget.empresaId,
                      transactionId: _resultado!.transactionId!,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('Revisar y confirmar ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Revisar más tarde',
                  style: TextStyle(color: Colors.grey[600])),
            ),
          ],

          if (ok) ...[
            const SizedBox(height: 8),
            Text('Volviendo...', style: TextStyle(color: Colors.grey[500])),
          ],
        ],
      ),
    );
  }
}

class _ResultadoIA {
  final String? transactionId;
  final String status;
  final bool autoPublished;
  final List<String> warnings;
  final List<String> errors;
  _ResultadoIA({
    this.transactionId,
    required this.status,
    this.autoPublished = false,
    required this.warnings,
    required this.errors,
  });
}





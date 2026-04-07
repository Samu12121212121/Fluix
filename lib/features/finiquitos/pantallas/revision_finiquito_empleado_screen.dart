import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/modelos/finiquito.dart';
import '../../../services/firma_finiquito_service.dart';
import '../widgets/firma_finiquito_canvas.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE REVISIÓN Y FIRMA DEL FINIQUITO (vista del empleado)
// ═══════════════════════════════════════════════════════════════════════════════

class RevisionFiniquitoEmpleadoScreen extends StatefulWidget {
  final Finiquito finiquito;
  final String empresaId;

  const RevisionFiniquitoEmpleadoScreen({
    super.key,
    required this.finiquito,
    required this.empresaId,
  });

  @override
  State<RevisionFiniquitoEmpleadoScreen> createState() =>
      _RevisionFiniquitoEmpleadoScreenState();
}

class _RevisionFiniquitoEmpleadoScreenState
    extends State<RevisionFiniquitoEmpleadoScreen> {
  final FirmaFiniquitoService _svc = FirmaFiniquitoService();
  final _canvasKey = GlobalKey<FirmaCanvasState>();
  final _ciudadCtrl = TextEditingController(text: 'Guadalajara');

  bool _firmando = false;
  bool _aceptaConformidad = false;

  @override
  void dispose() {
    _ciudadCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarFirma() async {
    final estado = _canvasKey.currentState;
    if (estado == null || estado.estaVacio) {
      _mostrarError('Por favor, realice su firma en el área habilitada.');
      return;
    }
    if (!_aceptaConformidad) {
      _mostrarError('Debe confirmar que está de acuerdo con la liquidación.');
      return;
    }

    // Confirmar con el empleado
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar firma'),
        content: Text(
          'Al confirmar, su firma quedará registrada en el sistema '
          'y el finiquito no podrá modificarse.\n\n'
          '¿Confirma que ha leído y está conforme con la liquidación de '
          '${widget.finiquito.liquidoPercibir.toStringAsFixed(2)} €?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar de nuevo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white),
            child: const Text('Firmar y confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _firmando = true);

    try {
      final f = widget.finiquito;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? f.empleadoId;

      // Convertir trazos a PNG
      final firmaBytes = await FirmaFiniquitoService.trazosAPng(
        trazos: estado.trazos,
        ancho: 400,
        alto: 200,
      );

      if (firmaBytes == null) throw Exception('No se pudo generar la imagen de firma');

      // Subir firma a Storage
      final firmaUrl = await _svc.guardarFirma(
        empresaId: widget.empresaId,
        finiquitoId: f.id,
        firmaBytes: firmaBytes,
        empleadoNombre: f.empleadoNombre,
      );

      // Regenerar PDF con firma
      final pdfUrl = await _svc.regenerarPDFConFirma(
        finiquito: f,
        firmaUrl: firmaUrl,
        firmaBytes: firmaBytes,
        ciudad: _ciudadCtrl.text,
      );

      // Marcar como firmado (inmutable)
      await _svc.marcarComoFirmado(
        empresaId: widget.empresaId,
        finiquitoId: f.id,
        firmaUrl: firmaUrl,
        pdfFirmadoUrl: pdfUrl,
        firmaUid: uid,
      );

      if (mounted) {
        Navigator.pop(context, true); // true = firmado
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Finiquito firmado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al firmar: $e');
    } finally {
      if (mounted) setState(() => _firmando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.finiquito;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Revisión del finiquito'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Aviso importante ─────────────────────────────────────────────
            _buildAvisoLegal(),
            const SizedBox(height: 16),

            // ── Resumen del finiquito ─────────────────────────────────────────
            _buildResumen(f),
            const SizedBox(height: 16),

            // ── Conceptos principales ─────────────────────────────────────────
            _buildConceptos(f),
            const SizedBox(height: 16),

            // ── Datos de firma ────────────────────────────────────────────────
            _buildDatosFirma(),
            const SizedBox(height: 16),

            // ── Texto legal de conformidad ────────────────────────────────────
            _buildTextoConformidad(f),
            const SizedBox(height: 16),

            // ── Canvas de firma ───────────────────────────────────────────────
            _buildAreaFirma(),
            const SizedBox(height: 16),

            // ── Checkbox conformidad ──────────────────────────────────────────
            CheckboxListTile(
              value: _aceptaConformidad,
              onChanged: (v) =>
                  setState(() => _aceptaConformidad = v ?? false),
              title: const Text(
                'He leído y estoy conforme con la liquidación anterior',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              activeColor: Colors.indigo,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // ── Botón confirmar ───────────────────────────────────────────────
            _firmando
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _confirmarFirma,
                    icon: const Icon(Icons.draw, size: 20),
                    label: const Text(
                      'CONFIRMAR FIRMA',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAvisoLegal() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Lea detenidamente el documento antes de firmar. '
              'Una vez firmado, el finiquito no podrá modificarse.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen(Finiquito f) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text('LIQUIDACIÓN FINAL',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('${f.liquidoPercibir.toStringAsFixed(2)} €',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Líquido a percibir',
              style: TextStyle(color: Colors.indigo.shade100, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chipBlanco(f.causaBaja.etiqueta),
              const SizedBox(width: 8),
              _chipBlanco('${_fmtDate(f.fechaBaja)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConceptos(Finiquito f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Desglose de conceptos',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            _fila('Salario pendiente', f.salarioPendiente),
            _fila('Vacaciones pendientes (${f.diasVacacionesPendientes} días)',
                f.importeVacaciones),
            ...f.prorrataPagasExtra.map(
                (p) => _fila('${p.nombre} (prorrata)', p.importe)),
            if (f.indemnizacion > 0)
              _fila('Indemnización', f.indemnizacion,
                  color: Colors.green.shade700),
            const Divider(height: 16),
            _fila('Total bruto', f.totalBruto, bold: true),
            _fila('(-) IRPF ${f.porcentajeIrpf.toStringAsFixed(1)}%',
                -f.importeIrpf,
                color: Colors.red),
            _fila('(-) Cuota SS', -f.cuotaObreraSSFiniquito,
                color: Colors.red),
            const Divider(height: 8, thickness: 2),
            _fila('LÍQUIDO', f.liquidoPercibir,
                bold: true, fontSize: 16,
                color: Colors.indigo),
          ],
        ),
      ),
    );
  }

  Widget _buildDatosFirma() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Datos de firma',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: _ciudadCtrl,
              decoration: const InputDecoration(
                labelText: 'Lugar de firma',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16,
                    color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Fecha: ${_fmtDate(DateTime.now())}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextoConformidad(Finiquito f) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '"Declaro haber recibido la cantidad de '
        '${f.liquidoPercibir.toStringAsFixed(2)} euros '
        'en concepto de liquidación final, quedando saldadas '
        'todas las deudas entre las partes.\n\n'
        'Conforme y en prueba de conformidad con la liquidación '
        'anterior, firmo el presente finiquito en ${_ciudadCtrl.text}, '
        'a ${_fmtDate(DateTime.now())}."',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade800,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildAreaFirma() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Firma del trabajador',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        FirmaFiniquitoCanvas(key: _canvasKey),
      ],
    );
  }

  Widget _fila(String label, double valor,
      {bool bold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight:
                          bold ? FontWeight.w700 : FontWeight.w400))),
          Text('${valor.toStringAsFixed(2)} €',
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  Widget _chipBlanco(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}


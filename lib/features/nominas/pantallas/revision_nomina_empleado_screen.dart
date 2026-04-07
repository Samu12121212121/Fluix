import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../domain/modelos/nomina.dart';
import '../../../services/firma_service.dart';
import '../../../services/nomina_pdf_service.dart';
import '../widgets/firma_digital_canvas.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA REVISIÓN Y FIRMA DE NÓMINA (empleado)
// ═══════════════════════════════════════════════════════════════════════════════

class RevisionNominaEmpleadoScreen extends StatefulWidget {
  final Nomina nomina;
  final String empresaId;
  final String empleadoId;

  const RevisionNominaEmpleadoScreen({
    super.key,
    required this.nomina,
    required this.empresaId,
    required this.empleadoId,
  });

  @override
  State<RevisionNominaEmpleadoScreen> createState() => _RevisionNominaEmpleadoScreenState();
}

class _RevisionNominaEmpleadoScreenState extends State<RevisionNominaEmpleadoScreen> {
  final FirmaService _firmaSvc = FirmaService();
  bool _firmando = false;
  bool _firmada = false;

  @override
  void initState() {
    super.initState();
    _firmada = widget.nomina.estadoFirma == 'firmada';
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nomina;

    // Control de permisos: solo puede ver sus propias nóminas
    if (n.empleadoId != widget.empleadoId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso denegado')),
        body: const Center(
          child: Text('No tienes permiso para ver esta nómina.',
            style: TextStyle(fontSize: 16, color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Nómina — ${n.periodo}'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Ver PDF',
            onPressed: () => NominaPdfService.verNominaPdf(context, n, widget.empresaId),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Resumen ─────────────────────────────────────────────────
            _resumenCard(n),
            const SizedBox(height: 16),

            // ── Devengos ────────────────────────────────────────────────
            _seccion('Devengos', [
              _linea('Salario base', n.salarioBrutoMensual),
              if (n.complementos > 0) _linea('Complementos', n.complementos),
              if (n.importeHorasExtra > 0) _linea('Horas extra', n.importeHorasExtra),
              if (n.pagaExtra > 0) _linea('Paga extraordinaria', n.pagaExtra),
              if (n.importeIT > 0) _linea('Prestación IT (${n.diasIT} días)', n.importeIT),
              if (n.descuentoSalarioPorIT > 0) _linea('Descuento por IT', -n.descuentoSalarioPorIT),
              _lineaTotal('Total devengos', n.totalDevengos),
            ]),
            const SizedBox(height: 12),

            // ── Deducciones ─────────────────────────────────────────────
            _seccion('Deducciones', [
              _linea('SS Trabajador', n.totalSSTrabajador),
              _linea('IRPF (${n.porcentajeIrpf.toStringAsFixed(2)}%)', n.retencionIrpf),
              if (n.regularizacionIrpf != 0)
                _linea('Regularización IRPF', n.regularizacionIrpf),
              if (n.embargoJudicial > 0) _linea('Embargo judicial', n.embargoJudicial),
              _lineaTotal('Total deducciones', n.totalDeducciones + n.embargoJudicial),
            ]),
            const SizedBox(height: 12),

            // ── Líquido ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('LÍQUIDO A PERCIBIR',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('${n.liquidoFinal.toStringAsFixed(2)} €',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Firma ───────────────────────────────────────────────────
            if (_firmada)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Color(0xFF4CAF50)),
                    SizedBox(width: 8),
                    Text('Nómina firmada ✓',
                      style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              )
            else if (n.estadoFirma == 'pendiente') ...[
              const Text('Firmar recibo de nómina',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Firme para confirmar que ha recibido y revisado su nómina.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Center(
                child: FirmaDigitalCanvas(
                  width: MediaQuery.of(context).size.width - 48,
                  height: 180,
                  onFirmaConfirmada: _firmar,
                ),
              ),
              if (_firmando)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Esta nómina aún no está lista para firmar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resumenCard(Nomina n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.empleadoNombre,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Periodo: ${n.periodo}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          if (n.empleadoNif != null)
            Text('NIF: ${n.empleadoNif}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> lineas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const Divider(),
          ...lineas,
        ],
      ),
    );
  }

  Widget _linea(String concepto, double importe) {
    final esNegativo = importe < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(concepto, style: const TextStyle(fontSize: 13))),
          Text(
            '${esNegativo ? '−' : ''}${importe.abs().toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: esNegativo ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineaTotal(String concepto, double importe) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(concepto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text('${importe.toStringAsFixed(2)} €',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _firmar(dynamic pngBytes) async {
    if (_firmando || pngBytes is! Uint8List) return;
    setState(() => _firmando = true);

    try {
      await _firmaSvc.firmarNomina(
        empresaId: widget.empresaId,
        nominaId: widget.nomina.id,
        empleadoId: widget.empleadoId,
        pngBytes: pngBytes,
      );
      setState(() {
        _firmada = true;
        _firmando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Nómina firmada correctamente'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      setState(() => _firmando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al firmar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}




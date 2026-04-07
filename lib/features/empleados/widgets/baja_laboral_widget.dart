import 'package:flutter/material.dart';
import '../../../domain/modelos/baja_laboral.dart';
import '../../../services/it_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET BAJA LABORAL — Registro y visualización de IT
// ═══════════════════════════════════════════════════════════════════════════════

class BajaLaboralWidget extends StatefulWidget {
  final String empleadoId;
  final double baseCotizacionMesAnterior;
  final bool esPropietario;

  const BajaLaboralWidget({
    super.key,
    required this.empleadoId,
    required this.baseCotizacionMesAnterior,
    this.esPropietario = false,
  });

  @override
  State<BajaLaboralWidget> createState() => _BajaLaboralWidgetState();
}

class _BajaLaboralWidgetState extends State<BajaLaboralWidget> {
  final ITService _itSvc = ITService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BajaLaboral>>(
      stream: _itSvc.streamBajas(widget.empleadoId),
      builder: (ctx, snap) {
        final bajas = snap.data ?? [];
        final bajasActivas = bajas.where((b) => b.activa).toList();
        final bajasHistorial = bajas.where((b) => !b.activa).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.local_hospital, color: Color(0xFFE53935)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Incapacidad Temporal (IT)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (widget.esPropietario)
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Registrar baja'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _mostrarDialogoRegistrarBaja(context),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Bajas activas ─────────────────────────────────────────
            if (bajasActivas.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                    SizedBox(width: 8),
                    Text('Sin bajas activas', style: TextStyle(color: Color(0xFF2E7D32))),
                  ],
                ),
              )
            else
              ...bajasActivas.map((b) => _tarjetaBajaActiva(b)),

            // ── Historial ─────────────────────────────────────────────
            if (bajasHistorial.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Historial de bajas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              ...bajasHistorial.map((b) => _tarjetaBajaHistorial(b)),
            ],
          ],
        );
      },
    );
  }

  Widget _tarjetaBajaActiva(BajaLaboral baja) {
    final diasTotal = baja.diasTotales();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8F00)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: baja.tipo.esProfesional
                      ? const Color(0xFFE53935)
                      : const Color(0xFFFF8F00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(baja.tipo.etiqueta,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('BAJA ACTIVA · $diasTotal días',
                  style: const TextStyle(color: Color(0xFFE53935), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (widget.esPropietario)
                TextButton.icon(
                  icon: const Icon(Icons.check, size: 14, color: Color(0xFF2E7D32)),
                  label: const Text('Dar alta', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
                  onPressed: () => _registrarAlta(baja),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Inicio: ${_formatFecha(baja.fechaInicio)}',
            style: const TextStyle(fontSize: 13)),
          if (baja.diagnostico != null && baja.diagnostico!.isNotEmpty)
            Text('Diagnóstico: ${baja.diagnostico}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (baja.numeroParteMedico != null && baja.numeroParteMedico!.isNotEmpty)
            Text('Parte médico: ${baja.numeroParteMedico}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('Base reguladora diaria: ${baja.baseReguladoraDiaria.toStringAsFixed(2)} €',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tarjetaBajaHistorial(BajaLaboral baja) {
    final diasTotal = baja.diasTotales();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(baja.tipo.esProfesional ? Icons.warning : Icons.medical_services,
            size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${baja.tipo.etiqueta} · $diasTotal días',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${_formatFecha(baja.fechaInicio)} → ${_formatFecha(baja.fechaFin!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoRegistrarBaja(BuildContext context) {
    TipoContingencia tipoSeleccionado = TipoContingencia.enfermedadComun;
    DateTime fechaInicio = DateTime.now();
    final parteCtrl = TextEditingController();
    final diagCtrl  = TextEditingController();
    bool mejoraConvenio = false;
    double pctMejora = 60;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Registrar baja laboral'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<TipoContingencia>(
                  initialValue: tipoSeleccionado,
                  decoration: const InputDecoration(labelText: 'Tipo de contingencia'),
                  items: TipoContingencia.values.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t.etiqueta)),
                  ).toList(),
                  onChanged: (v) => setDialogState(() => tipoSeleccionado = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de inicio'),
                  subtitle: Text(_formatFecha(fechaInicio)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: fechaInicio,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => fechaInicio = picked);
                  },
                ),
                TextField(
                  controller: parteCtrl,
                  decoration: const InputDecoration(labelText: 'Nº parte médico (opcional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: diagCtrl,
                  decoration: const InputDecoration(labelText: 'Diagnóstico (opcional)'),
                ),
                if (tipoSeleccionado.esComun) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mejora voluntaria días 1-3', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('El convenio complementa los primeros 3 días', style: TextStyle(fontSize: 11)),
                    value: mejoraConvenio,
                    onChanged: (v) => setDialogState(() => mejoraConvenio = v),
                  ),
                  if (mejoraConvenio)
                    Slider(
                      value: pctMejora,
                      min: 0, max: 100,
                      divisions: 10,
                      label: '${pctMejora.toInt()}%',
                      onChanged: (v) => setDialogState(() => pctMejora = v),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                await _itSvc.registrarBaja(
                  empleadoId: widget.empleadoId,
                  tipo: tipoSeleccionado,
                  fechaInicio: fechaInicio,
                  baseCotizacionMesAnterior: widget.baseCotizacionMesAnterior,
                  numeroParteMedico: parteCtrl.text.isEmpty ? null : parteCtrl.text,
                  diagnostico: diagCtrl.text.isEmpty ? null : diagCtrl.text,
                  mejoraConvenioDias1a3: mejoraConvenio,
                  porcentajeMejoraDias1a3: mejoraConvenio ? pctMejora : 0,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registrarAlta(BajaLaboral baja) async {
    final fechaAlta = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: baja.fechaInicio,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fechaAlta != null) {
      await _itSvc.registrarAlta(widget.empleadoId, baja.id, fechaAlta);
    }
  }

  String _formatFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}




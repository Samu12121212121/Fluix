import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/modelos/complemento_nomina.dart';
import '../../../services/complementos_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET COMPLEMENTOS DEL MES — Añadir/editar complementos variables
// ═══════════════════════════════════════════════════════════════════════════════

class ComplementosMesWidget extends StatefulWidget {
  final List<ComplementoNomina> complementos;
  final ValueChanged<List<ComplementoNomina>> onChanged;
  final double transporteAcumuladoAnual;

  const ComplementosMesWidget({
    super.key,
    required this.complementos,
    required this.onChanged,
    this.transporteAcumuladoAnual = 0,
  });

  @override
  State<ComplementosMesWidget> createState() => _ComplementosMesWidgetState();
}

class _ComplementosMesWidgetState extends State<ComplementosMesWidget> {
  final _compSvc = ComplementosService();
  late List<ComplementoNomina> _complementos;

  @override
  void initState() {
    super.initState();
    _complementos = List.from(widget.complementos);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.add_chart, color: Color(0xFF1976D2), size: 20),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Complementos del mes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF1976D2)),
              tooltip: 'Añadir complemento',
              onPressed: _mostrarDialogoAnadir,
            ),
          ],
        ),
        if (_complementos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin complementos variables este mes',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
        else
          ..._complementos.asMap().entries.map((e) => _tarjetaComplemento(e.key, e.value)),

        if (_complementos.isNotEmpty) ...[
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total complementos:', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('${_total.toStringAsFixed(2)} €',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ],
      ],
    );
  }

  double get _total => _complementos.fold(0.0, (s, c) => s + c.importe);

  Widget _tarjetaComplemento(int idx, ComplementoNomina comp) {
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
          _iconoTipo(comp.tipo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comp.descripcion.isEmpty ? comp.tipo.etiqueta : comp.descripcion,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    if (comp.importeCotizaSS > 0)
                      _badge('SS', Colors.blue),
                    if (comp.importeTributaIRPF > 0) ...[
                      const SizedBox(width: 4),
                      _badge('IRPF', Colors.orange),
                    ],
                    if (comp.importeCotizaSS == 0 && comp.importeTributaIRPF == 0) ...[
                      _badge('Exento', Colors.green),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text('${comp.importe.toStringAsFixed(2)} €',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () {
              setState(() => _complementos.removeAt(idx));
              widget.onChanged(_complementos);
            },
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _iconoTipo(TipoComplemento tipo) {
    IconData icon;
    Color color;
    switch (tipo) {
      case TipoComplemento.productividad:
        icon = Icons.trending_up; color = const Color(0xFF1976D2); break;
      case TipoComplemento.horasExtra:
        icon = Icons.access_time; color = const Color(0xFF7B1FA2); break;
      case TipoComplemento.plusTransporte:
        icon = Icons.directions_car; color = const Color(0xFF388E3C); break;
      case TipoComplemento.plusMantencion:
        icon = Icons.restaurant; color = const Color(0xFFE65100); break;
      case TipoComplemento.comisionVentas:
        icon = Icons.percent; color = const Color(0xFF0097A7); break;
      case TipoComplemento.pagaExtraProrrateada:
        icon = Icons.card_giftcard; color = const Color(0xFFC62828); break;
      case TipoComplemento.otro:
        icon = Icons.more_horiz; color = Colors.grey; break;
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  void _mostrarDialogoAnadir() {
    TipoComplemento tipo = TipoComplemento.productividad;
    final descCtrl = TextEditingController();
    final importeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Añadir complemento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<TipoComplemento>(
                  value: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: TipoComplemento.values.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t.etiqueta)),
                  ).toList(),
                  onChanged: (v) => setDialogState(() => tipo = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: importeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Importe (€)',
                    prefixIcon: Icon(Icons.euro),
                  ),
                ),
                const SizedBox(height: 8),
                // Info exenciones
                if (tipo == TipoComplemento.plusTransporte)
                  _infoExencion('Exento hasta ${ConstantesComplementos2026.transporteExentoAnual.toStringAsFixed(0)}€/año. '
                    'Acumulado este año: ${widget.transporteAcumuladoAnual.toStringAsFixed(2)}€'),
                if (tipo == TipoComplemento.plusMantencion)
                  _infoExencion('Exento hasta ${ConstantesComplementos2026.manutencionSinPernoctaEspana.toStringAsFixed(2)}€/día sin pernocta'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final importe = double.tryParse(importeCtrl.text.replaceAll(',', '.')) ?? 0;
                if (importe <= 0) return;

                final comp = _compSvc.calcularFiscalidad(
                  tipo: tipo,
                  descripcion: descCtrl.text.isEmpty ? tipo.etiqueta : descCtrl.text,
                  importe: importe,
                  transporteAcumuladoAnual: widget.transporteAcumuladoAnual,
                );
                final compConId = ComplementoNomina(
                  id: const Uuid().v4(),
                  tipo: comp.tipo,
                  descripcion: comp.descripcion,
                  importe: comp.importe,
                  importeCotizaSS: comp.importeCotizaSS,
                  importeTributaIRPF: comp.importeTributaIRPF,
                );

                setState(() => _complementos.add(compConId));
                widget.onChanged(_complementos);
                Navigator.pop(ctx);
              },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoExencion(String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)))),
        ],
      ),
    );
  }
}



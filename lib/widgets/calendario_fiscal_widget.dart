import 'package:flutter/material.dart';
import '../services/fiscal/calendario_fiscal_service.dart';
import '../domain/modelos/empresa_config.dart';

/// Widget que muestra los próximos vencimientos fiscales según forma jurídica.
/// Pensado para incluirlo en el dashboard fiscal o en tab_modelos_fiscales.
class CalendarioFiscalWidget extends StatefulWidget {
  final String empresaId;
  final FormaJuridica formaJuridica;
  final int? ejercicio;

  const CalendarioFiscalWidget({
    super.key,
    required this.empresaId,
    required this.formaJuridica,
    this.ejercicio,
  });

  @override
  State<CalendarioFiscalWidget> createState() => _CalendarioFiscalWidgetState();
}

class _CalendarioFiscalWidgetState extends State<CalendarioFiscalWidget> {
  final _svc = CalendarioFiscalService();
  List<DeadlineFiscal>? _deadlines;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(CalendarioFiscalWidget old) {
    super.didUpdateWidget(old);
    if (old.empresaId != widget.empresaId ||
        old.formaJuridica != widget.formaJuridica ||
        old.ejercicio != widget.ejercicio) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final deadlines = await _svc.obtenerProximos(
        empresaId: widget.empresaId,
        ejercicio: widget.ejercicio ?? DateTime.now().year,
        forma: widget.formaJuridica,
        cantidad: 3,
      );
      if (mounted) setState(() {
        _deadlines = deadlines;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final deadlines = _deadlines ?? [];
    if (deadlines.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10), Expanded(
                child: Text('🎉 Todo presentado — sin vencimientos pendientes',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.indigo.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Próximos vencimientos fiscales',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700,
                      )),
                ),
              ],
            ),
            const Divider(height: 16),
            ...deadlines.map(_buildDeadline),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadline(DeadlineFiscal d) {
    Color colorEstado;
    IconData iconoEstado;
    String estadoTexto;

    switch (d.estado) {
      case EstadoDeadline.presentado:
        colorEstado = Colors.grey;
        iconoEstado = Icons.check_circle;
        estadoTexto = 'PRESENTADO';
      case EstadoDeadline.vencido:
        colorEstado = Colors.red;
        iconoEstado = Icons.error;
        estadoTexto = 'VENCIDO';
      case EstadoDeadline.pendiente:
        if (d.esUrgente) {
          colorEstado = Colors.red;
          iconoEstado = Icons.warning_amber;
          estadoTexto = '${d.diasRestantes} días';
        } else if (d.diasRestantes <= 30) {
          colorEstado = Colors.orange;
          iconoEstado = Icons.timer_outlined;
          estadoTexto = '${d.diasRestantes} días';
        } else {
          colorEstado = Colors.green;
          iconoEstado = Icons.schedule;
          estadoTexto = 'PENDIENTE';
        }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorEstado.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorEstado.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(d.modelo,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.descripcion,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                Text(
                  'Hasta: ${_fmtDate(d.fechaLimite)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Icon(iconoEstado, color: colorEstado, size: 18),
          const SizedBox(width: 4),
          Text(estadoTexto,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorEstado)),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}



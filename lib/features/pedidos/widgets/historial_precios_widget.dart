import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/services/precio_service.dart';

/// Timeline visual del historial de precios de un producto.
/// Se usa en el detalle del producto como sección expandible.
class HistorialPreciosWidget extends StatefulWidget {
  final String empresaId;
  final String productoId;
  final double precioActual;

  const HistorialPreciosWidget({
    super.key,
    required this.empresaId,
    required this.productoId,
    required this.precioActual,
  });

  @override
  State<HistorialPreciosWidget> createState() => _HistorialPreciosWidgetState();
}

class _HistorialPreciosWidgetState extends State<HistorialPreciosWidget> {
  final _svc = PrecioService();
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.history, color: Color(0xFF1976D2), size: 22),
          title: const Text(
            'Historial de precios',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            'Precio actual: ${widget.precioActual.toStringAsFixed(2)} €',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          initiallyExpanded: _expandido,
          onExpansionChanged: (v) => setState(() => _expandido = v),
          children: [
            StreamBuilder<List<EntradaHistorialPrecio>>(
              stream: _svc.historialStream(widget.empresaId, widget.productoId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final lista = snap.data ?? [];
                if (lista.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Sin cambios de precio registrados',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: lista
                        .asMap()
                        .entries
                        .map((e) => _EntradaTimeline(
                              entrada: e.value,
                              esUltima: e.key == lista.length - 1,
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── ENTRADA TIMELINE ──────────────────────────────────────────────────────────

class _EntradaTimeline extends StatelessWidget {
  final EntradaHistorialPrecio entrada;
  final bool esUltima;

  const _EntradaTimeline({required this.entrada, required this.esUltima});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final color = entrada.esSubida ? Colors.red[700]! : Colors.green[700]!;
    final icon = entrada.esSubida ? Icons.trending_up : Icons.trending_down;
    final signo = entrada.esSubida ? '+' : '';
    final pct =
        '${signo}${entrada.variacionPct.toStringAsFixed(1)}%';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea de tiempo
          Column(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 12, color: color),
              ),
              if (!esUltima)
                Container(width: 2, height: 40, color: Colors.grey[200]),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${entrada.precioAnterior.toStringAsFixed(2)} €  →  ${entrada.precioNuevo.toStringAsFixed(2)} €',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(pct,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.schedule, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      'Efectivo: ${fmt.format(entrada.fechaEfectividad)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Registrado: ${fmt.format(entrada.fechaRegistro)}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    entrada.motivoLibre != null && entrada.motivoLibre!.isNotEmpty
                        ? '${entrada.motivo.etiqueta}: ${entrada.motivoLibre}'
                        : entrada.motivo.etiqueta,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── DIÁLOGO REGISTRAR CAMBIO DE PRECIO ───────────────────────────────────────

/// Dialog para pedir motivo y fecha de efectividad al cambiar el precio.
class DialogCambioPrecio extends StatefulWidget {
  final double precioAnterior;
  final double precioNuevo;

  const DialogCambioPrecio({
    super.key,
    required this.precioAnterior,
    required this.precioNuevo,
  });

  static Future<({MotivoCambioPrecio motivo, String? motivoLibre, DateTime fecha})?> mostrar(
    BuildContext context, {
    required double precioAnterior,
    required double precioNuevo,
  }) {
    return showDialog(
      context: context,
      builder: (_) => DialogCambioPrecio(
          precioAnterior: precioAnterior, precioNuevo: precioNuevo),
    );
  }

  @override
  State<DialogCambioPrecio> createState() => _DialogCambioPrecioState();
}

class _DialogCambioPrecioState extends State<DialogCambioPrecio> {
  MotivoCambioPrecio _motivo = MotivoCambioPrecio.otro;
  final _motivoLibreCtrl = TextEditingController();
  DateTime _fechaEfectividad = DateTime.now();

  @override
  void dispose() {
    _motivoLibreCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fechaEfectividad,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _fechaEfectividad = d);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final variacion = widget.precioNuevo - widget.precioAnterior;
    final esSubida = variacion > 0;

    return AlertDialog(
      title: const Text('Registrar cambio de precio'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Resumen del cambio
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: esSubida
                  ? Colors.red[50]
                  : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(esSubida ? Icons.trending_up : Icons.trending_down,
                    color: esSubida ? Colors.red : Colors.green),
                const SizedBox(width: 8),
                Text(
                  '${widget.precioAnterior.toStringAsFixed(2)} € → ${widget.precioNuevo.toStringAsFixed(2)} €',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Motivo
          DropdownButtonFormField<MotivoCambioPrecio>(
            value: _motivo,
            decoration: InputDecoration(
              labelText: 'Motivo del cambio',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            items: MotivoCambioPrecio.values
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.etiqueta),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _motivo = v!),
          ),
          const SizedBox(height: 10),

          // Motivo libre
          TextField(
            controller: _motivoLibreCtrl,
            decoration: InputDecoration(
              labelText: 'Descripción (opcional)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),

          // Fecha de efectividad
          GestureDetector(
            onTap: _seleccionarFecha,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Efectivo desde: ${fmt.format(_fechaEfectividad)}'),
                ),
              ]),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (
            motivo: _motivo,
            motivoLibre: _motivoLibreCtrl.text.trim().isEmpty
                ? null
                : _motivoLibreCtrl.text.trim(),
            fecha: _fechaEfectividad,
          )),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}




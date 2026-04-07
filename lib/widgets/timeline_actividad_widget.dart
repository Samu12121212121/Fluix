import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../domain/modelos/actividad_cliente.dart';
import '../../services/actividad_cliente_service.dart';

/// Timeline vertical del historial de actividad de un cliente.
/// Muestra eventos automáticos y notas manuales con paginación.
class TimelineActividadWidget extends StatefulWidget {
  final String empresaId;
  final String clienteId;
  final bool puedeAgregarNota;
  final String? usuarioId;
  final String? usuarioNombre;
  final void Function(String documentoId, String tipo)? onVerDocumento;

  const TimelineActividadWidget({
    super.key,
    required this.empresaId,
    required this.clienteId,
    this.puedeAgregarNota = false,
    this.usuarioId,
    this.usuarioNombre,
    this.onVerDocumento,
  });

  @override
  State<TimelineActividadWidget> createState() =>
      _TimelineActividadWidgetState();
}

class _TimelineActividadWidgetState extends State<TimelineActividadWidget> {
  final _svc = ActividadClienteService();
  final _items = <ActividadCliente>[];
  bool _cargando = true;
  bool _hayMas = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final nuevos = await _svc.obtenerHistorial(
      empresaId: widget.empresaId,
      clienteId: widget.clienteId,
      limit: 20,
    );
    setState(() {
      _items.clear();
      _items.addAll(nuevos);
      _hayMas = nuevos.length >= 20;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.puedeAgregarNota)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _mostrarFormularioNota(context),
                icon: const Icon(Icons.note_add, size: 16),
                label: const Text('Añadir nota'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00796B),
                  side: const BorderSide(color: Color(0xFF00796B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? _buildVacio()
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: _items.length + (_hayMas ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _items.length) {
                            return Center(
                              child: TextButton(
                                onPressed: () {/* TODO: cargar más */},
                                child: const Text('Cargar más...'),
                              ),
                            );
                          }
                          return _TimelineItem(
                            item: _items[i],
                            isLast: i == _items.length - 1,
                            onVerDocumento: widget.onVerDocumento,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Sin actividad registrada',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Las transacciones aparecerán aquí\nautomáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioNota(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotaManualSheet(
        onGuardar: (texto, tipo) async {
          await _svc.registrarNotaManual(
            empresaId: widget.empresaId,
            clienteId: widget.clienteId,
            texto: texto,
            tipoNota: tipo,
            usuarioId: widget.usuarioId ?? '',
            usuarioNombre: widget.usuarioNombre ?? '',
          );
          _cargar();
        },
      ),
    );
  }
}

// ── ITEM DEL TIMELINE ─────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final ActividadCliente item;
  final bool isLast;
  final void Function(String documentoId, String tipo)? onVerDocumento;

  const _TimelineItem({
    required this.item,
    this.isLast = false,
    this.onVerDocumento,
  });

  Color get _color => switch (item.tipo) {
        TipoEventoActividad.facturaEmitida  => const Color(0xFF0D47A1),
        TipoEventoActividad.facturaCobrada  => const Color(0xFF388E3C),
        TipoEventoActividad.citaCreada      => const Color(0xFF7B1FA2),
        TipoEventoActividad.citaCompletada  => const Color(0xFF00796B),
        TipoEventoActividad.citaCancelada   => const Color(0xFFD32F2F),
        TipoEventoActividad.pedidoCreado    => const Color(0xFFF57C00),
        TipoEventoActividad.pedidoEntregado => const Color(0xFF388E3C),
        TipoEventoActividad.emailEnviado    => const Color(0xFF1565C0),
        TipoEventoActividad.notaManual      => const Color(0xFF607D8B),
        TipoEventoActividad.tareaCreada     => const Color(0xFF1976D2),
        TipoEventoActividad.tareaCompletada => const Color(0xFF4CAF50),
        TipoEventoActividad.tareaVencida    => const Color(0xFFE53935),
      };

  IconData get _icono => switch (item.tipo) {
        TipoEventoActividad.facturaEmitida  => Icons.receipt_long,
        TipoEventoActividad.facturaCobrada  => Icons.paid,
        TipoEventoActividad.citaCreada      => Icons.calendar_month,
        TipoEventoActividad.citaCompletada  => Icons.event_available,
        TipoEventoActividad.citaCancelada   => Icons.event_busy,
        TipoEventoActividad.pedidoCreado    => Icons.shopping_bag,
        TipoEventoActividad.pedidoEntregado => Icons.local_shipping,
        TipoEventoActividad.emailEnviado    => Icons.email,
        TipoEventoActividad.tareaCreada     => Icons.task_alt,
        TipoEventoActividad.tareaCompletada => Icons.check_circle,
        TipoEventoActividad.tareaVencida    => Icons.warning_amber,
        TipoEventoActividad.notaManual      => switch (item.tipoNota) {
            TipoNotaManual.llamada => Icons.phone,
            TipoNotaManual.visita  => Icons.storefront,
            TipoNotaManual.email   => Icons.email_outlined,
            _                      => Icons.note,
          },
      };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea del timeline
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icono, size: 14, color: _color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[200],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Contenido
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.descripcion,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (item.importe != null)
                        Text(
                          '${item.importe!.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _color,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(
                        timeago.format(item.fecha, locale: 'es'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (item.documentoId != null && onVerDocumento != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => onVerDocumento!(
                            item.documentoId!,
                            item.tipo.name,
                          ),
                          child: Text(
                            'Ver →',
                            style: TextStyle(
                              fontSize: 11,
                              color: _color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
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

// ── BOTTOM SHEET NOTA MANUAL ──────────────────────────────────────────────────

class _NotaManualSheet extends StatefulWidget {
  final Future<void> Function(String texto, TipoNotaManual tipo) onGuardar;

  const _NotaManualSheet({required this.onGuardar});

  @override
  State<_NotaManualSheet> createState() => _NotaManualSheetState();
}

class _NotaManualSheetState extends State<_NotaManualSheet> {
  final _ctrl = TextEditingController();
  TipoNotaManual _tipo = TipoNotaManual.notaInterna;
  bool _guardando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Añadir nota',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          // Selector de tipo
          Wrap(
            spacing: 8,
            children: TipoNotaManual.values.map((t) {
              final sel = _tipo == t;
              final label = switch (t) {
                TipoNotaManual.llamada => '📞 Llamada',
                TipoNotaManual.visita => '🏠 Visita',
                TipoNotaManual.email => '📧 Email',
                TipoNotaManual.notaInterna => '📝 Nota',
              };
              return ChoiceChip(
                label: Text(label),
                selected: sel,
                onSelected: (_) => setState(() => _tipo = t),
                selectedColor: const Color(0xFF00796B).withValues(alpha: 0.14),
                checkmarkColor: const Color(0xFF00796B),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Escribe tu nota...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _guardando || _ctrl.text.trim().isEmpty
                  ? null
                  : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Guardar nota',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await widget.onGuardar(_ctrl.text.trim(), _tipo);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}


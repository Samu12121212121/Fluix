import 'dart:async';
import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';
import 'package:planeag_flutter/widgets/cliente_selector_rapido.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FormularioNuevoPedidoScreen extends StatefulWidget {
  final String empresaId;
  const FormularioNuevoPedidoScreen({super.key, required this.empresaId});

  @override
  State<FormularioNuevoPedidoScreen> createState() => _FormularioNuevoPedidoScreenState();
}

class _FormularioNuevoPedidoScreenState extends State<FormularioNuevoPedidoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _notasClienteCtrl = TextEditingController();
  final _notasInternasCtrl = TextEditingController();
  final PedidosService _svc = PedidosService();

  OrigenPedido _origen = OrigenPedido.app;
  MetodoPago _metodoPago = MetodoPago.efectivo;
  final List<LineaPedido> _lineas = [];
  bool _guardando = false;

  // Fecha y hora de entrega (opcional)
  DateTime? _fechaEntrega;
  TimeOfDay? _horaEntrega;
  bool _tieneHoraEntrega = false;

  double get _total => _lineas.fold(0, (s, l) => s + l.subtotal);
  String get _usuarioId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _usuarioNombre => FirebaseAuth.instance.currentUser?.displayName ?? 'Admin';

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _telCtrl, _correoCtrl, _notasClienteCtrl, _notasInternasCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Nuevo pedido'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Crear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Cliente (opcional)
            _card('Datos del cliente (opcional)', [
              ClienteSelectorRapido(
                empresaId: widget.empresaId,
                valorInicial: _nombreCtrl.text,
                hint: 'Buscar o crear cliente...',
                onSeleccionado: (cliente) {
                  _nombreCtrl.text = cliente.nombre;
                  if (cliente.telefono != null && _telCtrl.text.isEmpty) {
                    _telCtrl.text = cliente.telefono!;
                  }
                  if (cliente.correo != null && _correoCtrl.text.isEmpty) {
                    _correoCtrl.text = cliente.correo!;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(labelText: 'Correo (opcional)', prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
            ]),
            const SizedBox(height: 12),

            // Productos
            _card('Productos del pedido', [
              if (_lineas.isNotEmpty) ...[
                ..._lineas.asMap().entries.map((e) {
                  final l = e.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text('${l.cantidad}x',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1976D2)))),
                    ),
                    title: Text(l.productoNombre, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: l.variante != null ? Text(l.variante!.nombre) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${l.subtotal.toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _lineas.removeAt(e.key)),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${_total.toStringAsFixed(2)} €',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1976D2))),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _mostrarSelectorProductos(),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Añadir producto del catálogo',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Fecha y hora de entrega ──────────────────────────────
            _card('Fecha de entrega (opcional)', [
              Row(
                children: [
                  Switch(
                    value: _tieneHoraEntrega,
                    onChanged: (v) => setState(() {
                      _tieneHoraEntrega = v;
                      if (!v) { _fechaEntrega = null; _horaEntrega = null; }
                    }),
                    activeColor: const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tieneHoraEntrega ? 'Con fecha/hora de entrega' : 'Para ahora (sin fecha específica)',
                      style: TextStyle(
                        fontSize: 13,
                        color: _tieneHoraEntrega ? const Color(0xFF1976D2) : Colors.grey[600],
                        fontWeight: _tieneHoraEntrega ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              if (_tieneHoraEntrega) ...[
                const SizedBox(height: 12),
                // Fila fecha + hora
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _seleccionarFecha,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _fechaEntrega != null ? const Color(0xFF1976D2) : Colors.grey[400]!,
                              width: _fechaEntrega != null ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: _fechaEntrega != null ? const Color(0xFF1976D2).withValues(alpha: 0.05) : null,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18,
                                  color: _fechaEntrega != null ? const Color(0xFF1976D2) : Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _fechaEntrega != null
                                      ? '${_fechaEntrega!.day.toString().padLeft(2,'0')}/${_fechaEntrega!.month.toString().padLeft(2,'0')}/${_fechaEntrega!.year}'
                                      : 'Seleccionar fecha',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _fechaEntrega != null ? const Color(0xFF1976D2) : Colors.grey,
                                    fontWeight: _fechaEntrega != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _seleccionarHora,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _horaEntrega != null ? const Color(0xFF1976D2) : Colors.grey[400]!,
                              width: _horaEntrega != null ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: _horaEntrega != null ? const Color(0xFF1976D2).withValues(alpha: 0.05) : null,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 18,
                                  color: _horaEntrega != null ? const Color(0xFF1976D2) : Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                _horaEntrega != null
                                    ? '${_horaEntrega!.hour.toString().padLeft(2,'0')}:${_horaEntrega!.minute.toString().padLeft(2,'0')}'
                                    : 'Hora',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _horaEntrega != null ? const Color(0xFF1976D2) : Colors.grey,
                                  fontWeight: _horaEntrega != null ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_fechaEntrega != null || _horaEntrega != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Color(0xFF1976D2)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Entrega: ${_resumenFechaEntrega()}',
                            style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ]),
            const SizedBox(height: 12),

            // Pago y origen
            _card('Pago y origen', [
              DropdownButtonFormField<OrigenPedido>(
                value: _origen,
                decoration: const InputDecoration(labelText: 'Origen del pedido', prefixIcon: Icon(Icons.source)),
                items: OrigenPedido.values.map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(_nombreOrigen(o)),
                )).toList(),
                onChanged: (v) { if (v != null) setState(() => _origen = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MetodoPago>(
                value: _metodoPago,
                decoration: const InputDecoration(labelText: 'Método de pago', prefixIcon: Icon(Icons.payment)),
                items: MetodoPago.values.map((m) => DropdownMenuItem(
                  value: m,
                  child: Row(
                    children: [
                      Icon(_iconoPago(m), size: 18, color: const Color(0xFF1976D2)),
                      const SizedBox(width: 8),
                      Text(_nombrePago(m)),
                    ],
                  ),
                )).toList(),
                onChanged: (v) { if (v != null) setState(() => _metodoPago = v); },
              ),
            ]),
            const SizedBox(height: 12),

            // Notas
            _card('Notas', [
              TextFormField(
                controller: _notasClienteCtrl,
                decoration: const InputDecoration(labelText: 'Notas del cliente', prefixIcon: Icon(Icons.message), alignLabelWithHint: true),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notasInternasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas internas (privadas)',
                  prefixIcon: Icon(Icons.lock_outline),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _card(String titulo, List<Widget> children) => Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1976D2))),
          const Divider(height: 16),
          ...children,
        ],
      ),
    ),
  );

  void _mostrarSelectorProductos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorProductosSheet(
        empresaId: widget.empresaId,
        onSeleccionado: (linea) {
          setState(() => _lineas.add(linea));
        },
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un producto'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await _svc.crearPedido(
        empresaId: widget.empresaId,
        clienteNombre: _nombreCtrl.text.trim().isNotEmpty ? _nombreCtrl.text.trim() : 'Sin nombre',
        clienteTelefono: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        clienteCorreo: _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
        lineas: _lineas,
        origen: _origen,
        metodoPago: _metodoPago,
        notasCliente: _notasClienteCtrl.text.trim().isEmpty ? null : _notasClienteCtrl.text.trim(),
        notasInternas: _notasInternasCtrl.text.trim().isEmpty ? null : _notasInternasCtrl.text.trim(),
        usuarioId: _usuarioId,
        usuarioNombre: _usuarioNombre,
        fechaEntrega: _fechaEntregaFinal,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Helpers fecha entrega ──────────────────────────────────────────────────

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final picked = await _mostrarSelectorFecha(context, _fechaEntrega ?? hoy);
    if (picked != null && mounted) setState(() => _fechaEntrega = picked);
  }

  Future<void> _seleccionarHora() async {
    final picked = await _mostrarSelectorHora(context, _horaEntrega ?? const TimeOfDay(hour: 12, minute: 0));
    if (picked != null && mounted) setState(() => _horaEntrega = picked);
  }

  Future<DateTime?> _mostrarSelectorFecha(BuildContext ctx, DateTime inicial) {
    final completer = Completer<DateTime?>();
    DateTime seleccionado = inicial;
    int mes = inicial.month;
    int anio = inicial.year;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx2, setS) {
            final hoy = DateTime.now();
            final hoyNorm = DateTime(hoy.year, hoy.month, hoy.day);
            final primerDia = DateTime(anio, mes, 1);
            final diasEnMes = DateTime(anio, mes + 1, 0).day;
            // Lunes=1..Domingo=7 → offset para que empiece en Lunes
            final offsetInicio = (primerDia.weekday - 1) % 7;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 10),
                  // Cabecera mes/año
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setS(() {
                          if (mes == 1) { mes = 12; anio--; } else { mes--; }
                        }),
                      ),
                      Text('${_nombreMes(mes)} $anio',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setS(() {
                          if (mes == 12) { mes = 1; anio++; } else { mes++; }
                        }),
                      ),
                    ],
                  ),
                  // Cabecera días semana (empieza en Lunes)
                  Row(
                    children: ['L','M','X','J','V','S','D'].map((d) => Expanded(
                      child: Center(child: Text(d,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[600]))),
                    )).toList(),
                  ),
                  const SizedBox(height: 4),
                  // Grid días — altura fija para evitar overflow
                  SizedBox(
                    height: 270,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7, childAspectRatio: 1,
                      ),
                      itemCount: offsetInicio + diasEnMes,
                      itemBuilder: (_, i) {
                        if (i < offsetInicio) return const SizedBox();
                        final dia = i - offsetInicio + 1;
                        final fecha = DateTime(anio, mes, dia);
                        final esPasado = fecha.isBefore(hoyNorm);
                        final esSel = seleccionado.year == anio && seleccionado.month == mes && seleccionado.day == dia;
                        final esHoy = hoy.year == anio && hoy.month == mes && hoy.day == dia;
                        return GestureDetector(
                          onTap: esPasado ? null : () => setS(() => seleccionado = fecha),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: esSel
                                  ? const Color(0xFF1976D2)
                                  : esHoy
                                      ? const Color(0xFF1976D2).withValues(alpha: 0.12)
                                      : null,
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text('$dia',
                              style: TextStyle(
                                color: esSel ? Colors.white : esPasado ? Colors.grey[300] : Colors.black87,
                                fontWeight: esSel || esHoy ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ))),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () { completer.complete(null); Navigator.pop(ctx2); },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () { completer.complete(seleccionado); Navigator.pop(ctx2); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirmar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).then((_) { if (!completer.isCompleted) completer.complete(null); });

    return completer.future;
  }

  Future<TimeOfDay?> _mostrarSelectorHora(BuildContext ctx, TimeOfDay inicial) {
    final completer = Completer<TimeOfDay?>();
    int hora = inicial.hour;
    int minuto = inicial.minute;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx2, setS) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                const Text('Hora de entrega', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _columnaHoraMinuto(valor: hora, min: 0, max: 23, label: 'horas',
                        onCambio: (v) => setS(() => hora = v)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(':', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                    ),
                    _columnaHoraMinuto(valor: minuto, min: 0, max: 55, label: 'min',
                        paso: 5, onCambio: (v) => setS(() => minuto = v)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () { completer.complete(null); Navigator.pop(ctx2); },
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          completer.complete(TimeOfDay(hour: hora, minute: minuto));
                          Navigator.pop(ctx2);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white,
                        ),
                        child: Text('${hora.toString().padLeft(2,'0')}:${minuto.toString().padLeft(2,'0')} ✓'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) { if (!completer.isCompleted) completer.complete(null); });

    return completer.future;
  }

  Widget _columnaHoraMinuto({
    required int valor, required int min, required int max,
    required String label, required void Function(int) onCambio, int paso = 1,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, size: 32),
          onPressed: () { final n = valor + paso; onCambio(n > max ? min : n); },
        ),
        Container(
          width: 68, height: 58,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1976D2), width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(valor.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () { final n = valor - paso; onCambio(n < min ? max : n); },
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  String _nombreMes(int m) => const ['','Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'][m];

  String _resumenFechaEntrega() {
    final partes = <String>[];
    if (_fechaEntrega != null) {
      final hoy = DateTime.now();
      final diff = _fechaEntrega!.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
      if (diff == 0) partes.add('Hoy');
      else if (diff == 1) partes.add('Mañana');
      else partes.add('${_fechaEntrega!.day.toString().padLeft(2,'0')}/${_fechaEntrega!.month.toString().padLeft(2,'0')}/${_fechaEntrega!.year}');
    }
    if (_horaEntrega != null) {
      partes.add('a las ${_horaEntrega!.hour.toString().padLeft(2,'0')}:${_horaEntrega!.minute.toString().padLeft(2,'0')}');
    }
    return partes.join(' ');
  }

  DateTime? get _fechaEntregaFinal {
    if (!_tieneHoraEntrega || _fechaEntrega == null) return null;
    final h = _horaEntrega ?? const TimeOfDay(hour: 12, minute: 0);
    return DateTime(_fechaEntrega!.year, _fechaEntrega!.month, _fechaEntrega!.day, h.hour, h.minute);
  }

  String _nombreOrigen(OrigenPedido o) => switch (o) {
    OrigenPedido.web        => '🌐 Web',
    OrigenPedido.app        => '📱 App',
    OrigenPedido.whatsapp   => '💬 WhatsApp',
    OrigenPedido.presencial => '🏪 Presencial',
    OrigenPedido.tpvExterno => '🖥️ TPV Externo',
  };

  String _nombrePago(MetodoPago m) => switch (m) {
    MetodoPago.tarjeta  => 'Tarjeta (Visa/MasterCard)',
    MetodoPago.paypal   => 'PayPal',
    MetodoPago.bizum    => 'Bizum',
    MetodoPago.efectivo => 'Efectivo en recogida',
    MetodoPago.mixto    => 'Mixto (Efectivo + Tarjeta)',
  };

  IconData _iconoPago(MetodoPago m) => switch (m) {
    MetodoPago.tarjeta  => Icons.credit_card,
    MetodoPago.paypal   => Icons.account_balance_wallet,
    MetodoPago.bizum    => Icons.smartphone,
    MetodoPago.efectivo => Icons.money,
    MetodoPago.mixto    => Icons.compare_arrows,
  };
}

// ── SELECTOR DE PRODUCTOS (Bottom Sheet) ──────────────────────────────────────

class _SelectorProductosSheet extends StatefulWidget {
  final String empresaId;
  final void Function(LineaPedido) onSeleccionado;
  const _SelectorProductosSheet({required this.empresaId, required this.onSeleccionado});

  @override
  State<_SelectorProductosSheet> createState() => _SelectorProductosSheetState();
}

class _SelectorProductosSheetState extends State<_SelectorProductosSheet> {
  final PedidosService _svc = PedidosService();
  final TextEditingController _busCtrl = TextEditingController();
  String _busqueda = '';
  Producto? _seleccionado;
  int _cantidad = 1;
  VarianteProducto? _varianteSeleccionada;

  @override
  void dispose() {
    _busCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),

            // Cabecera
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_seleccionado != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => setState(() { _seleccionado = null; _cantidad = 1; _varianteSeleccionada = null; }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (_seleccionado != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _seleccionado == null ? 'Selecciona un producto' : _seleccionado!.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),

            if (_seleccionado == null) ...[
              // ── LISTA DE PRODUCTOS ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _busCtrl,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _busCtrl.clear(); setState(() => _busqueda = ''); })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Producto>>(
                  // Cargamos TODOS (activos e inactivos) para que se vean siempre
                  stream: _svc.productosStream(widget.empresaId, soloActivos: false),
                  builder: (context, snap) {
                    // Estado de carga
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Cargando productos...', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    // Error
                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text('Error: ${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      );
                    }

                    var prods = snap.data ?? [];

                    // Filtrar por búsqueda
                    if (_busqueda.isNotEmpty) {
                      prods = prods.where((p) =>
                        p.nombre.toLowerCase().contains(_busqueda) ||
                        p.categoria.toLowerCase().contains(_busqueda) ||
                        (p.descripcion?.toLowerCase().contains(_busqueda) ?? false)
                      ).toList();
                    }

                    // Sin productos en absoluto
                    if ((snap.data ?? []).isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay productos en el catálogo',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ve a Catálogo de Productos y añade los primeros productos para poder incluirlos en pedidos.',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                                label: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Sin resultados de búsqueda
                    if (prods.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Sin resultados para "$_busqueda"', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: prods.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = prods[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: p.activo
                                  ? const Color(0xFF1976D2).withValues(alpha: 0.1)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: p.imagenUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(p.imagenUrl!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _iconoCategoria(p.categoria),
                                    ),
                                  )
                                : _iconoCategoria(p.categoria),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(p.nombre,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: p.activo ? Colors.black87 : Colors.grey,
                                    )),
                              ),
                              if (!p.activo)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Inactivo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1976D2).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(p.categoria, style: const TextStyle(fontSize: 11, color: Color(0xFF1976D2))),
                              ),
                              if (p.variantes.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('${p.variantes.length} variantes', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ],
                            ],
                          ),
                          trailing: Text(
                            '${p.precio.toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2), fontSize: 15),
                          ),
                          onTap: () => setState(() {
                            _seleccionado = p;
                            _varianteSeleccionada = null;
                            _cantidad = 1;
                          }),
                        );
                      },
                    );
                  },
                ),
              ),
            ] else ...[
              // ── CONFIGURAR LÍNEA ────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info producto seleccionado
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_seleccionado!.nombre,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                  if (_seleccionado!.descripcion != null)
                                    Text(_seleccionado!.descripcion!,
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('${_seleccionado!.precio.toStringAsFixed(2)} €',
                                      style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(() { _seleccionado = null; _cantidad = 1; }),
                              icon: const Icon(Icons.swap_horiz, size: 16),
                              label: const Text('Cambiar'),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1976D2)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Variantes
                      if (_seleccionado!.variantes.isNotEmpty) ...[
                        const Text('Variante', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _seleccionado!.variantes.map((v) => ChoiceChip(
                            label: Text('${v.nombre}${v.precioDiferencia != null && v.precioDiferencia! != 0 ? ' (+${v.precioDiferencia!.toStringAsFixed(2)}€)' : ''}'),
                            selected: _varianteSeleccionada?.id == v.id,
                            onSelected: (_) => setState(() => _varianteSeleccionada = v),
                            selectedColor: const Color(0xFF1976D2),
                            labelStyle: TextStyle(color: _varianteSeleccionada?.id == v.id ? Colors.white : Colors.black87),
                          )).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Cantidad
                      const Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                            icon: const Icon(Icons.remove_circle_outline, size: 30),
                            color: const Color(0xFF1976D2),
                          ),
                          Container(
                            width: 56, height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF1976D2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text('$_cantidad',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _cantidad++),
                            icon: const Icon(Icons.add_circle_outline, size: 30),
                            color: const Color(0xFF1976D2),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Subtotal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${((_seleccionado!.precio + (_varianteSeleccionada?.precioDiferencia ?? 0)) * _cantidad).toStringAsFixed(2)} €',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1976D2)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _confirmarSeleccion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Añadir al pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconoCategoria(String categoria) {
    final icono = switch (categoria.toLowerCase()) {
      String c when c.contains('bebida') => Icons.local_cafe,
      String c when c.contains('comida') || c.contains('menú') || c.contains('menu') => Icons.restaurant,
      String c when c.contains('desayuno') => Icons.free_breakfast,
      String c when c.contains('postre') => Icons.cake,
      _ => Icons.inventory_2,
    };
    return Icon(icono, color: const Color(0xFF1976D2), size: 22);
  }

  void _confirmarSeleccion() {
    final p = _seleccionado!;
    final precioFinal = p.precio + (_varianteSeleccionada?.precioDiferencia ?? 0);
    final linea = LineaPedido(
      productoId: p.id,
      productoNombre: p.nombre,
      precioUnitario: precioFinal,
      cantidad: _cantidad,
      variante: _varianteSeleccionada,
    );
    widget.onSeleccionado(linea);
    Navigator.pop(context);
  }
}



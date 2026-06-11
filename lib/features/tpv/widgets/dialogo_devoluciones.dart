// dialogo_devoluciones.dart — Widget standalone para devoluciones (TPV Tienda + Bar)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';

class DialogoDevoluciones extends StatefulWidget {
  final String empresaId;
  final Color colorPrimario;

  const DialogoDevoluciones({
    super.key,
    required this.empresaId,
    required this.colorPrimario,
  });

  @override
  State<DialogoDevoluciones> createState() => _DialogoDevolucionesState();
}

class _DialogoDevolucionesState extends State<DialogoDevoluciones> {
  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;

  // Ticket seleccionado
  Map<String, dynamic>? _ticketSeleccionado;
  List<Map<String, dynamic>> _lineasDevolucion = [];

  // Método de reembolso
  String _metodoReembolso = 'efectivo';
  bool _procesando = false;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BÚSQUEDA DE TICKETS
  // ═══════════════════════════════════════════════════════════════════════════

  void _buscar(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _ticketSeleccionado = null;
        _lineasDevolucion = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _buscando = true);

      try {
        QuerySnapshot snap;
        final numTicket = int.tryParse(query.trim());

        if (numTicket != null) {
          // Búsqueda exacta por número de ticket
          snap = await FirebaseFirestore.instance
              .collection('empresas')
              .doc(widget.empresaId)
              .collection('pedidos')
              .where('numero_ticket', isEqualTo: numTicket)
              .where('estado_pago', isEqualTo: 'pagado')
              .limit(5)
              .get();
        } else {
          // Búsqueda por nombre de cliente
          final busq = query.trim().toLowerCase();
          snap = await FirebaseFirestore.instance
              .collection('empresas')
              .doc(widget.empresaId)
              .collection('pedidos')
              .where('cliente_nombre', isGreaterThanOrEqualTo: busq)
              .where('cliente_nombre', isLessThan: '${busq}z')
              .where('estado_pago', isEqualTo: 'pagado')
              .orderBy('cliente_nombre')
              .orderBy('fecha_hora', descending: true)
              .limit(10)
              .get();
        }

        if (mounted) {
          setState(() {
            _resultados = snap.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return {
                'id': d.id,
                'numero_ticket': data['numero_ticket'],
                'cliente_nombre': data['cliente_nombre'],
                'fecha_hora': data['fecha_hora'],
                'importe_total': data['importe_total'],
                'lineas': data['lineas'],
                'metodo_pago': data['metodo_pago'] ?? 'efectivo',
              };
            }).toList();
            _buscando = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _buscando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al buscar: $e')),
          );
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SELECCIONAR TICKET Y PREPARAR LÍNEAS
  // ═══════════════════════════════════════════════════════════════════════════

  void _seleccionarTicket(Map<String, dynamic> ticket) {
    final lineas = (ticket['lineas'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];

    setState(() {
      _ticketSeleccionado = ticket;
      _lineasDevolucion = lineas.map((l) {
        final cantidadOriginal = (l['cantidad'] as num?)?.toInt() ?? 1;
        return {
          'producto_id': l['producto_id'] as String? ?? '',
          'producto_nombre': l['producto_nombre'] as String? ?? '',
          'cantidad_original': cantidadOriginal,
          'cantidad_devolver': cantidadOriginal,
          'precio_unitario': (l['precio_unitario'] as num?)?.toDouble() ?? 0.0,
          'seleccionado': true,
        };
      }).toList();
      _resultados = [];
      _busquedaCtrl.clear();
    });
  }

  double get _importeDevolver {
    return _lineasDevolucion
        .where((l) => l['seleccionado'] == true)
        .fold(0.0, (sum, l) {
          final cant = (l['cantidad_devolver'] as int?) ?? 0;
          final precio = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
          return sum + (cant * precio);
        });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIRMAR DEVOLUCIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmarDevolucion() async {
    if (_ticketSeleccionado == null || _importeDevolver <= 0) return;

    setState(() => _procesando = true);

    try {
      final db = FirebaseFirestore.instance;
      final lineasSeleccionadas = _lineasDevolucion
          .where((l) => l['seleccionado'] == true && (l['cantidad_devolver'] as int) > 0)
          .toList();

      // 1. Crear documento en devoluciones/
      final devolucionRef = await db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('devoluciones')
          .add({
        'pedido_id': _ticketSeleccionado!['id'],
        'numero_ticket_original': _ticketSeleccionado!['numero_ticket'],
        'cliente_nombre': _ticketSeleccionado!['cliente_nombre'],
        'fecha': FieldValue.serverTimestamp(),
        'metodo_reembolso': _metodoReembolso,
        'importe_devuelto': _importeDevolver,
        'camarero_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'lineas_devueltas': lineasSeleccionadas.map((l) => {
          'producto_id': l['producto_id'],
          'producto_nombre': l['producto_nombre'],
          'cantidad': l['cantidad_devolver'],
          'precio_unitario': l['precio_unitario'],
        }).toList(),
      });

      // 2. Registro VeriFactu de anulación (RD 1007/2023 — inmutable, encadenado)
      try {
        await db
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('registros_verifactu')
            .add({
          'tipo': 'anulacion',
          'pedido_id_original': _ticketSeleccionado!['id'],
          'numero_ticket_original': _ticketSeleccionado!['numero_ticket'],
          'importe_devuelto': _importeDevolver,
          'metodo_reembolso': _metodoReembolso,
          'fecha_anulacion': FieldValue.serverTimestamp(),
          'anulado_por_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
          'motivo': 'devolucion_tpv',
          'devolucion_id': devolucionRef.id,
        });
      } catch (_) {}

      // 3. Incrementar stock de productos devueltos (solo si no es libre_)
      for (final linea in lineasSeleccionadas) {
        final productoId = linea['producto_id'] as String?;
        if (productoId == null || productoId.isEmpty || productoId.startsWith('libre_')) {
          continue;
        }
        try {
          await db
              .collection('empresas')
              .doc(widget.empresaId)
              .collection('catalogo')
              .doc(productoId)
              .update({
            'stock': FieldValue.increment(linea['cantidad_devolver'] as int),
          });
        } catch (_) {
          // El producto puede no existir en catálogo (productos antiguos)
        }
      }

      // 4. Crear vale si el método es vale de tienda
      if (_metodoReembolso == 'vale') {
        final codigoVale = _generarCodigoVale();
        await db
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('vales')
            .add({
          'codigo': codigoVale,
          'importe': _importeDevolver,
          'fecha_emision': FieldValue.serverTimestamp(),
          'fecha_caducidad': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 365)),
          ),
          'usado': false,
          'cliente_nombre': _ticketSeleccionado!['cliente_nombre'],
          'origen_devolucion_id': devolucionRef.id,
        });
      }

      // 5. Imprimir ticket de devolución
      try {
        final empresaSnap = await db
            .collection('empresas')
            .doc(widget.empresaId)
            .get();
        final nombreEmpresa = empresaSnap.data()?['nombre'] as String? ?? '';

        await ImpressoraBluetooth().imprimirTicket(TicketData(
          nombreEmpresa: '*** DEVOLUCIÓN *** $nombreEmpresa',
          numeroTicket: _ticketSeleccionado!['numero_ticket'] as int,
          fecha: DateTime.now(),
          lineas: lineasSeleccionadas.map((l) => LineaTicket(
            nombre: '-${l['producto_nombre']}',
            cantidad: l['cantidad_devolver'] as int,
            precioUnitario: (l['precio_unitario'] as num?)?.toDouble() ?? 0.0,
          )).toList(),
          total: -_importeDevolver, // Negativo
          metodoPago: 'Reembolso $_metodoReembolso',
        ));
      } catch (_) {}

      if (mounted) {
        setState(() => _procesando = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Devolución registrada: ${_importeDevolver.toStringAsFixed(2)} € (${_metodoReembolso})',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar devolución: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generarCodigoVale() {
    final now = DateTime.now();
    return 'VALE-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Dialog(
      backgroundColor: Colors.white,
      child: Container(
        width: 600,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.keyboard_return, color: widget.colorPrimario, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Devoluciones',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Búsqueda de ticket ─────────────────────────────────────────
            if (_ticketSeleccionado == null) ...[
              TextField(
                controller: _busquedaCtrl,
                autofocus: true,
                onChanged: _buscar,
                decoration: InputDecoration(
                  hintText: 'Buscar por número de ticket o nombre de cliente...',
                  prefixIcon: Icon(Icons.search, color: widget.colorPrimario),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Resultados de búsqueda
              if (_resultados.isEmpty && !_buscando && _busquedaCtrl.text.isNotEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No se encontraron tickets',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_resultados.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _resultados.length,
                    itemBuilder: (context, idx) {
                      final ticket = _resultados[idx];
                      final numTicket = ticket['numero_ticket'] as int?;
                      final cliente = ticket['cliente_nombre'] as String? ?? 'Sin nombre';
                      final fecha = (ticket['fecha_hora'] as Timestamp?)?.toDate();
                      final importe = (ticket['importe_total'] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: widget.colorPrimario.withValues(alpha: 0.15),
                            child: Text(
                              '#$numTicket',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.colorPrimario,
                              ),
                            ),
                          ),
                          title: Text(
                            cliente,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            fecha != null
                                ? DateFormat('dd/MM/yyyy HH:mm').format(fecha)
                                : 'Fecha desconocida',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                fmt.format(importe),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                ticket['metodo_pago'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _seleccionarTicket(ticket),
                        ),
                      );
                    },
                  ),
                ),
            ],

            // ── Ticket seleccionado - selección de líneas ─────────────────
            if (_ticketSeleccionado != null) ...[
              // Info del ticket
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.colorPrimario.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.colorPrimario.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Ticket #${_ticketSeleccionado!['numero_ticket']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: widget.colorPrimario,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _ticketSeleccionado = null;
                            _lineasDevolucion = [];
                          }),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Buscar otro'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ticketSeleccionado!['cliente_nombre'] as String? ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Total original: ${fmt.format(_ticketSeleccionado!['importe_total'])}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Líneas del pedido
              const Text(
                'Selecciona los artículos a devolver:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView.builder(
                  itemCount: _lineasDevolucion.length,
                  itemBuilder: (context, idx) {
                    final linea = _lineasDevolucion[idx];
                    final seleccionado = linea['seleccionado'] as bool;
                    final cantOriginal = linea['cantidad_original'] as int;
                    final cantDevolver = linea['cantidad_devolver'] as int;
                    final precio = (linea['precio_unitario'] as num?)?.toDouble() ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: seleccionado ? Colors.orange.shade50 : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: seleccionado,
                                  activeColor: Colors.orange.shade700,
                                  onChanged: (val) => setState(() {
                                    _lineasDevolucion[idx]['seleccionado'] = val ?? false;
                                  }),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        linea['producto_nombre'] as String? ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Precio unitario: ${fmt.format(precio)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Selector de cantidad
                                if (seleccionado) ...[
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: cantDevolver > 1
                                        ? () => setState(() {
                                              _lineasDevolucion[idx]['cantidad_devolver'] = cantDevolver - 1;
                                            })
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$cantDevolver / $cantOriginal',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: cantDevolver < cantOriginal
                                        ? () => setState(() {
                                              _lineasDevolucion[idx]['cantidad_devolver'] = cantDevolver + 1;
                                            })
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    fmt.format(precio * cantDevolver),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Método de reembolso
              const Divider(),
              const Text(
                'Método de reembolso:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Efectivo'),
                        ],
                      ),
                      selected: _metodoReembolso == 'efectivo',
                      selectedColor: Colors.green.shade100,
                      onSelected: (_) => setState(() => _metodoReembolso = 'efectivo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.card_giftcard, size: 16),
                          SizedBox(width: 6),
                          Text('Vale de tienda'),
                        ],
                      ),
                      selected: _metodoReembolso == 'vale',
                      selectedColor: Colors.orange.shade100,
                      onSelected: (_) => setState(() => _metodoReembolso = 'vale'),
                    ),
                  ),
                ],
              ),
            ],

            // ── Footer ─────────────────────────────────────────────────────
            if (_ticketSeleccionado != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Importe a devolver:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      fmt.format(_importeDevolver),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _procesando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _procesando || _importeDevolver <= 0
                          ? null
                          : _confirmarDevolucion,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _procesando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Confirmar devolución',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


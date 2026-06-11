import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO: CREAR/EDITAR MESA
// ═════════════════════════════════════════════════════════════════════════════

Future<void> mostrarDialogoCrearMesa(BuildContext context, String empresaId) async {
  await showDialog(
    context: context,
    builder: (_) => _DialogoCrearMesa(empresaId: empresaId),
  );
}

Future<void> mostrarDialogoEditarMesa(
  BuildContext context,
  String empresaId,
  Map<String, dynamic> mesaData,
  String mesaId,
) async {
  await showDialog(
    context: context,
    builder: (_) => _DialogoCrearMesa(
      empresaId: empresaId,
      mesaId: mesaId,
      mesaData: mesaData,
    ),
  );
}

class _DialogoCrearMesa extends StatefulWidget {
  final String empresaId;
  final String? mesaId;
  final Map<String, dynamic>? mesaData;

  const _DialogoCrearMesa({
    required this.empresaId,
    this.mesaId,
    this.mesaData,
  });

  @override
  State<_DialogoCrearMesa> createState() => _DialogoCrearMesaState();
}

class _DialogoCrearMesaState extends State<_DialogoCrearMesa> {
  final _nombreCtrl = TextEditingController();
  String _zonaSeleccionada = 'Salón';
  int _capacidad = 4;
  bool _guardando = false;

  final List<String> _zonas = ['Salón', 'Terraza', 'Barra', 'VIP', 'Reservado'];

  @override
  void initState() {
    super.initState();
    if (widget.mesaData != null) {
      _nombreCtrl.text = widget.mesaData!['nombre'] ?? '';
      _zonaSeleccionada = widget.mesaData!['zona'] ?? 'Salón';
      _capacidad = widget.mesaData!['capacidad'] ?? 4;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.mesaId != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            esEdicion ? Icons.edit : Icons.add_business,
            color: const Color(0xFF00FFC8),
          ),
          const SizedBox(width: 8),
          Text(esEdicion ? 'Editar mesa' : 'Nueva mesa'),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreCtrl,
              autofocus: !esEdicion,
              decoration: const InputDecoration(
                labelText: 'Nombre o número *',
                hintText: 'Ej: Mesa 1, T1, Barra 3',
                prefixIcon: Icon(Icons.table_restaurant),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Zona', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _zonas.map((zona) {
                final seleccionada = _zonaSeleccionada == zona;
                return ChoiceChip(
                  label: Text(zona),
                  selected: seleccionada,
                  onSelected: (_) => setState(() => _zonaSeleccionada = zona),
                  selectedColor: const Color(0xFF00FFC8).withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: seleccionada ? const Color(0xFF00FFC8) : null,
                    fontWeight: seleccionada ? FontWeight.bold : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Capacidad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _capacidad > 1 ? () => setState(() => _capacidad--) : null,
                ),
                Text('$_capacidad personas', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _capacidad < 20 ? () => setState(() => _capacidad++) : null,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (esEdicion)
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF2850)),
            label: const Text('Eliminar', style: TextStyle(color: Color(0xFFFF2850))),
            onPressed: _guardando ? null : () => _eliminarMesa(),
          ),
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardarMesa,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FFC8)),
          child: _guardando
              ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
              : Text(esEdicion ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  Future<void> _guardarMesa() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre para la mesa')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final mesasRef = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('mesas');

      final data = {
        'nombre': _nombreCtrl.text.trim(),
        'zona': _zonaSeleccionada,
        'capacidad': _capacidad,
        'estado': widget.mesaData?['estado'] ?? 'libre',
        'comensales_actuales': widget.mesaData?['comensales_actuales'] ?? 0,
        'actualizado_en': FieldValue.serverTimestamp(),
      };

      if (widget.mesaId != null) {
        // Editar mesa existente
        await mesasRef.doc(widget.mesaId).update(data);
      } else {
        // Crear nueva mesa
        data['creado_en'] = FieldValue.serverTimestamp();
        await mesasRef.add(data);
      }

      if (!mounted) return;
      final messengerMesa = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messengerMesa.showSnackBar(
        SnackBar(
          content: Text(widget.mesaId != null ? 'Mesa actualizada' : 'Mesa creada'),
          backgroundColor: const Color(0xFF00FFC8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminarMesa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar la mesa "${_nombreCtrl.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF2850)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);

    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('mesas')
          .doc(widget.mesaId)
          .delete();

      if (!mounted) return;
      final messengerElim = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messengerElim.showSnackBar(
        const SnackBar(
          content: Text('Mesa eliminada'),
          backgroundColor: Color(0xFFFF2850),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO: NÚMERO DE COMENSALES
// ═════════════════════════════════════════════════════════════════════════════

Future<void> mostrarDialogoComensales(
  BuildContext context,
  String empresaId,
  String mesaId,
  int comensalesActuales,
) async {
  await showDialog(
    context: context,
    builder: (_) => _DialogoComensales(
      empresaId: empresaId,
      mesaId: mesaId,
      comensalesActuales: comensalesActuales,
    ),
  );
}

class _DialogoComensales extends StatefulWidget {
  final String empresaId;
  final String mesaId;
  final int comensalesActuales;

  const _DialogoComensales({
    required this.empresaId,
    required this.mesaId,
    required this.comensalesActuales,
  });

  @override
  State<_DialogoComensales> createState() => _DialogoComensalesState();
}

class _DialogoComensalesState extends State<_DialogoComensales> {
  late int _comensales;

  @override
  void initState() {
    super.initState();
    _comensales = widget.comensalesActuales > 0 ? widget.comensalesActuales : 2;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.people, color: Color(0xFFFF3296)),
          SizedBox(width: 8),
          Text('Comensales'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('¿Cuántas personas hay en la mesa?'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                icon: const Icon(Icons.remove),
                onPressed: _comensales > 1 ? () => setState(() => _comensales--) : null,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2139),
                ),
              ),
              const SizedBox(width: 24),
              Text(
                '$_comensales',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 24),
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: _comensales < 50 ? () => setState(() => _comensales++) : null,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [1, 2, 3, 4, 5, 6, 8, 10].map((n) {
              return ActionChip(
                label: Text('$n'),
                onPressed: () => setState(() => _comensales = n),
                backgroundColor: _comensales == n
                    ? const Color(0xFF00FFC8).withValues(alpha: 0.3)
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => _guardarComensales(),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FFC8)),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }

  Future<void> _guardarComensales() async {
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('mesas')
          .doc(widget.mesaId)
          .update({
        'comensales_actuales': _comensales,
        'estado': 'ocupada',
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO: PRODUCTO MANUAL (precio libre)
// ═════════════════════════════════════════════════════════════════════════════

Future<Map<String, dynamic>?> mostrarDialogoProductoManual(BuildContext context) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _DialogoProductoManual(),
  );
}

class _DialogoProductoManual extends StatefulWidget {
  const _DialogoProductoManual();

  @override
  State<_DialogoProductoManual> createState() => _DialogoProductoManualState();
}

class _DialogoProductoManualState extends State<_DialogoProductoManual> {
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_note, color: Color(0xFFFF4678)),
          SizedBox(width: 8),
          Text('Producto manual'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                hintText: 'Ej: Menú del día, Consumición especial',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _precioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio (€) *',
                prefixIcon: Icon(Icons.euro),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notaCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Sin gluten, poco hecho...',
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_nombreCtrl.text.trim().isEmpty || _precioCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Completa nombre y precio')),
              );
              return;
            }

            final precio = double.tryParse(_precioCtrl.text.trim());
            if (precio == null || precio <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Precio inválido')),
              );
              return;
            }

            Navigator.pop(context, {
              'nombre': _nombreCtrl.text.trim(),
              'precio': precio,
              'nota': _notaCtrl.text.trim(),
              'es_manual': true,
            });
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FFC8)),
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO: EDITAR PRECIO DE LÍNEA
// ═════════════════════════════════════════════════════════════════════════════

Future<double?> mostrarDialogoEditarPrecio(
  BuildContext context,
  String nombreProducto,
  double precioActual,
) async {
  return await showDialog<double>(
    context: context,
    builder: (_) => _DialogoEditarPrecio(
      nombreProducto: nombreProducto,
      precioActual: precioActual,
    ),
  );
}

class _DialogoEditarPrecio extends StatefulWidget {
  final String nombreProducto;
  final double precioActual;

  const _DialogoEditarPrecio({
    required this.nombreProducto,
    required this.precioActual,
  });

  @override
  State<_DialogoEditarPrecio> createState() => _DialogoEditarPrecioState();
}

class _DialogoEditarPrecioState extends State<_DialogoEditarPrecio> {
  late final TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    _precioCtrl = TextEditingController(
      text: widget.precioActual.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: Color(0xFFFF3296)),
          SizedBox(width: 8),
          Text('Editar precio'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.nombreProducto,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _precioCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Nuevo precio (€)',
              prefixIcon: Icon(Icons.euro),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nuevoPrecio = double.tryParse(_precioCtrl.text.trim());
            if (nuevoPrecio == null || nuevoPrecio <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Precio inválido')),
              );
              return;
            }
            Navigator.pop(context, nuevoPrecio);
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FFC8)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO: APLICAR DESCUENTO
// ═════════════════════════════════════════════════════════════════════════════

Future<Map<String, dynamic>?> mostrarDialogoDescuento(
  BuildContext context, {
  double? precioLinea, // Si es null, es descuento sobre el total
}) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _DialogoDescuento(precioLinea: precioLinea),
  );
}

class _DialogoDescuento extends StatefulWidget {
  final double? precioLinea;

  const _DialogoDescuento({this.precioLinea});

  @override
  State<_DialogoDescuento> createState() => _DialogoDescuentoState();
}

class _DialogoDescuentoState extends State<_DialogoDescuento> {
  final _valorCtrl = TextEditingController();
  bool _esPorcentaje = true;

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esTotal = widget.precioLinea == null;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.discount, color: Color(0xFFFF4678)),
          const SizedBox(width: 8),
          Text(esTotal ? 'Descuento sobre total' : 'Descuento en este producto'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!esTotal)
            Text(
              'Precio original: ${widget.precioLinea!.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valorCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _esPorcentaje ? 'Porcentaje' : 'Import (€)',
                    prefixIcon: Icon(_esPorcentaje ? Icons.percent : Icons.euro),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('%'), icon: Icon(Icons.percent, size: 16)),
                  ButtonSegment(value: false, label: Text('€'), icon: Icon(Icons.euro, size: 16)),
                ],
                selected: {_esPorcentaje},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() => _esPorcentaje = newSelection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: (_esPorcentaje
                ? [5.0, 10.0, 15.0, 20.0, 25.0, 50.0]
                : [1.0, 2.0, 5.0, 10.0])
                    .map((val) => ActionChip(
                          label: Text(_esPorcentaje ? '$val%' : '$val €'),
                          onPressed: () => setState(() => _valorCtrl.text = val.toString()),
                        ))
                    .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final valor = double.tryParse(_valorCtrl.text.trim());
            if (valor == null || valor <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Valor inválido')),
              );
              return;
            }

            if (_esPorcentaje && valor > 100) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('El porcentaje no puede ser mayor al 100%')),
              );
              return;
            }

            Navigator.pop(context, {
              'es_porcentaje': _esPorcentaje,
              'valor': valor,
            });
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FFC8)),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO: AÑADIR NOTA A PRODUCTO
// ═════════════════════════════════════════════════════════════════════════════

Future<String?> mostrarDialogoNota(BuildContext context, String nombreProducto, {String? notaActual}) async {
  return await showDialog<String>(
    context: context,
    builder: (_) => _DialogoNota(
      nombreProducto: nombreProducto,
      notaActual: notaActual,
    ),
  );
}

class _DialogoNota extends StatefulWidget {
  final String nombreProducto;
  final String? notaActual;

  const _DialogoNota({
    required this.nombreProducto,
    this.notaActual,
  });

  @override
  State<_DialogoNota> createState() => _DialogoNotaState();
}

class _DialogoNotaState extends State<_DialogoNota> {
  late final TextEditingController _notaCtrl;

  final List<String> _notasRapidas = [
    'Sin gluten',
    'Sin lactosa',
    'Poco hecho',
    'Muy hecho',
    'Sin cebolla',
    'Sin ajo',
    'Picante',
    'Sin sal',
  ];

  @override
  void initState() {
    super.initState();
    _notaCtrl = TextEditingController(text: widget.notaActual ?? '');
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.sticky_note_2, color: Color(0xFFFF3296)),
          SizedBox(width: 8),
          Text('Nota para cocina'),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nombreProducto,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notaCtrl,
              autofocus: true,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota',
                hintText: 'Instrucciones especiales para la cocina',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Sugerencias:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _notasRapidas.map((nota) {
                return ActionChip(
                  label: Text(nota, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final textoActual = _notaCtrl.text.trim();
                    if (textoActual.isEmpty) {
                      setState(() => _notaCtrl.text = nota);
                    } else if (!textoActual.contains(nota)) {
                      setState(() => _notaCtrl.text = '$textoActual, $nota');
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.notaActual != null && widget.notaActual!.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Borrar nota'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _notaCtrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FFC8)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}






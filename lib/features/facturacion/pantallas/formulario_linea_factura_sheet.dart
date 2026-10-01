import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/domain/modelos/producto.dart';
import 'package:planeag_flutter/domain/modelos/servicio.dart';

const _kPrimario = Color(0xFF0D47A1);
const _kFondo = Color(0xFFF5F7FA);

Future<LineaFactura?> mostrarLineaSheet(
  BuildContext context, {
  required double ivaDefault,
  required bool esComercio,
  LineaFactura? editar,
  String? empresaId,
}) {
  return showModalBottomSheet<LineaFactura>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LineaSheet(
      ivaDefault: ivaDefault,
      esComercio: esComercio,
      editar: editar,
      empresaId: empresaId,
    ),
  );
}

class _LineaSheet extends StatefulWidget {
  final double ivaDefault;
  final bool esComercio;
  final LineaFactura? editar;
  final String? empresaId;

  const _LineaSheet({
    required this.ivaDefault,
    required this.esComercio,
    this.editar,
    this.empresaId,
  });

  @override
  State<_LineaSheet> createState() => _LineaSheetState();
}

class _LineaSheetState extends State<_LineaSheet> {
  late final TextEditingController _desc;
  late final TextEditingController _precio;
  late final TextEditingController _cantidad;
  late final TextEditingController _descuento;
  late final TextEditingController _referencia;
  late double? _iva;
  late String _unidad;
  late double _recargo;
  bool _mostrarErrorIva = false;
  bool _precioConIva = false; // true = el precio que teclea ya incluye IVA

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    _desc = TextEditingController(text: e?.descripcion ?? '');
    _precio = TextEditingController(
        text: e != null ? e.precioUnitario.toStringAsFixed(2) : '');
    _cantidad =
        TextEditingController(text: e?.cantidad.toString() ?? '1');
    _descuento = TextEditingController(
        text: e != null && e.descuento > 0
            ? e.descuento.toStringAsFixed(0)
            : '0');
    _referencia = TextEditingController(text: e?.referencia ?? '');
    _iva = e?.porcentajeIva ?? (widget.esComercio ? null : widget.ivaDefault);
    _unidad =
        e?.unidad.isNotEmpty == true ? e!.unidad : 'ud';
    _recargo = e?.recargoEquivalencia ?? 0;
  }

  @override
  void dispose() {
    _desc.dispose();
    _precio.dispose();
    _cantidad.dispose();
    _descuento.dispose();
    _referencia.dispose();
    super.dispose();
  }

  // Precio neto efectivo (sin IVA) según el toggle
  double get _precioNeto {
    final p =
        double.tryParse(_precio.text.replaceAll(',', '.')) ?? 0;
    if (!_precioConIva || _iva == null) return p;
    return p / (1 + _iva! / 100);
  }

  double get _subtotalPreview {
    final p = _precioNeto;
    final c = int.tryParse(_cantidad.text) ?? 1;
    final d =
        double.tryParse(_descuento.text.replaceAll(',', '.')) ?? 0;
    final base = p * c * (1 - d / 100);
    return base * (1 + (_iva ?? 0) / 100 + _recargo / 100);
  }

  // Rellena los campos desde un item del catálogo (producto o servicio)
  void _rellenarDesdeItem(_ItemCatalogo item) {
    setState(() {
      _desc.text = item.nombre;
      _precio.text = item.precio.toStringAsFixed(2);
      _precioConIva = false;
      _iva = item.ivaPorcentaje;
      _unidad = item.unidadDefecto;
      if (item.sku != null && item.sku!.isNotEmpty) {
        _referencia.text = item.sku!;
      }
      _mostrarErrorIva = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Text(
                  widget.editar == null ? 'Añadir línea' : 'Editar línea',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_precio, _cantidad, _descuento]),
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kPrimario.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_subtotalPreview.toStringAsFixed(2)}€',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _kPrimario,
                          fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Selector de producto/servicio del catálogo ──────────────
            if (widget.empresaId != null) ...[
              _CatalogoBuscador(
                empresaId: widget.empresaId!,
                ivaDefault: widget.ivaDefault,
                onSeleccionado: _rellenarDesdeItem,
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
            ],

            _input('Descripción *', _desc,
                hint: 'Producto o servicio prestado'),
            const SizedBox(height: 12),

            // ── Precio + toggle IVA incluido ─────────────────────────────
            Row(children: [
              Expanded(
                  flex: 3,
                  child: _inputNum('Precio unitario *', _precio)),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildUnidadPicker()),
            ]),
            const SizedBox(height: 8),
            _buildPrecioIvaToggle(),

            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _inputNum('Cantidad', _cantidad, decimal: false)),
              const SizedBox(width: 10),
              Expanded(
                  child: _inputNum('Descuento línea (%)', _descuento)),
            ]),
            const SizedBox(height: 16),
            _buildIvaPicker(),
            if (_mostrarErrorIva)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Selecciona el tipo de IVA',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            _buildRecargoPicker(),
            const SizedBox(height: 12),
            _input('Referencia / SKU (opcional)', _referencia),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  widget.editar == null
                      ? 'Añadir línea'
                      : 'Actualizar línea',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Toggle precio con/sin IVA ────────────────────────────────────────────

  Widget _buildPrecioIvaToggle() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _precioConIva = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: !_precioConIva
                  ? _kPrimario
                  : Colors.grey[100],
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20)),
              border: Border.all(
                  color:
                      !_precioConIva ? _kPrimario : Colors.grey[300]!),
            ),
            child: Text(
              'Sin IVA (neto)',
              style: TextStyle(
                color: !_precioConIva ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _precioConIva = true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _precioConIva ? _kPrimario : Colors.grey[100],
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(20)),
              border: Border.all(
                  color:
                      _precioConIva ? _kPrimario : Colors.grey[300]!),
            ),
            child: Text(
              'Con IVA (bruto)',
              style: TextStyle(
                color: _precioConIva ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Hint contextual
        Expanded(
          child: AnimatedBuilder(
            animation: _precio,
            builder: (_, __) {
              if (_iva == null) return const SizedBox.shrink();
              final p = double.tryParse(
                      _precio.text.replaceAll(',', '.')) ??
                  0;
              if (p <= 0) return const SizedBox.shrink();
              final neto = _precioConIva
                  ? p / (1 + _iva! / 100)
                  : p;
              final bruto = _precioConIva
                  ? p
                  : p * (1 + _iva! / 100);
              return Text(
                _precioConIva
                    ? '= ${neto.toStringAsFixed(2)}€ s/IVA'
                    : '= ${bruto.toStringAsFixed(2)}€ c/IVA',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnidadPicker() {
    return DropdownButtonFormField<String>(
      value: _unidad,
      decoration: _deco('Unidad'),
      items: const [
        DropdownMenuItem(value: 'ud', child: Text('ud')),
        DropdownMenuItem(value: 'h', child: Text('h — hora')),
        DropdownMenuItem(value: 'día', child: Text('día')),
        DropdownMenuItem(value: 'mes', child: Text('mes')),
        DropdownMenuItem(value: 'año', child: Text('año')),
        DropdownMenuItem(value: 'kg', child: Text('kg')),
        DropdownMenuItem(value: 'm', child: Text('m')),
        DropdownMenuItem(value: 'm²', child: Text('m²')),
        DropdownMenuItem(value: 'm³', child: Text('m³')),
        DropdownMenuItem(value: 'l', child: Text('l — litro')),
        DropdownMenuItem(value: 'servicio', child: Text('servicio')),
        DropdownMenuItem(value: '', child: Text('— ninguna')),
      ],
      onChanged: (v) => setState(() => _unidad = v ?? 'ud'),
    );
  }

  Widget _buildIvaPicker() {
    final opciones = widget.esComercio
        ? <(String, double, String)>[
            ('4%', 4.0, 'Alimentación básica, medicamentos'),
            ('10%', 10.0, 'Alimentación general'),
            ('21%', 21.0, 'Ropa, electrónica, resto'),
          ]
        : <(String, double, String)>[
            ('0% — Exento', 0.0, ''),
            ('4%', 4.0, ''),
            ('10%', 10.0, ''),
            ('21%', 21.0, ''),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IVA aplicable${widget.esComercio ? ' *' : ''}',
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opciones.map((item) {
            final selected = _iva == item.$2;
            return Tooltip(
              message: item.$3,
              child: GestureDetector(
                onTap: () => setState(() {
                  _iva = item.$2;
                  _mostrarErrorIva = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? _kPrimario : Colors.grey[100],
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: selected
                            ? _kPrimario
                            : Colors.grey[300]!),
                  ),
                  child: Text(
                    item.$1,
                    style: TextStyle(
                      color:
                          selected ? Colors.white : Colors.grey[700],
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecargoPicker() {
    return DropdownButtonFormField<double>(
      value: _recargo,
      decoration: _deco('Recargo equivalencia'),
      items: const [
        DropdownMenuItem(value: 0.0, child: Text('Sin recargo')),
        DropdownMenuItem(value: 0.5, child: Text('0.5% (IVA 4%)')),
        DropdownMenuItem(value: 1.4, child: Text('1.4% (IVA 10%)')),
        DropdownMenuItem(value: 5.2, child: Text('5.2% (IVA 21%)')),
      ],
      onChanged: (v) => setState(() => _recargo = v ?? 0),
    );
  }

  Widget _input(String label, TextEditingController ctrl,
          {String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: TextFormField(
          controller: ctrl,
          textInputAction: TextInputAction.next,
          decoration: _deco(label, hint: hint),
        ),
      );

  Widget _inputNum(String label, TextEditingController ctrl,
          {bool decimal = true}) =>
      TextFormField(
        controller: ctrl,
        keyboardType:
            TextInputType.numberWithOptions(decimal: decimal),
        textInputAction: TextInputAction.next,
        decoration: _deco(label),
      );

  InputDecoration _deco(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _kFondo,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kPrimario)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      );

  void _confirmar() {
    if (_desc.text.trim().isEmpty) return;
    final precio =
        double.tryParse(_precio.text.replaceAll(',', '.'));
    if (precio == null || precio <= 0) return;
    if (_iva == null) {
      setState(() => _mostrarErrorIva = true);
      return;
    }
    Navigator.pop(
      context,
      LineaFactura(
        descripcion: _desc.text.trim(),
        precioUnitario: _precioNeto,
        cantidad: int.tryParse(_cantidad.text) ?? 1,
        porcentajeIva: _iva!,
        descuento:
            double.tryParse(_descuento.text.replaceAll(',', '.')) ??
                0,
        recargoEquivalencia: _recargo,
        referencia: _referencia.text.trim().isEmpty
            ? null
            : _referencia.text.trim(),
        unidad: _unidad,
      ),
    );
  }
}

// ── Item unificado de catálogo (producto o servicio) ─────────────────────────

class _ItemCatalogo {
  final String nombre;
  final double precio;
  final double ivaPorcentaje;
  final String? sku;
  final String unidadDefecto;
  final bool esServicio;
  final String? etiquetaExtra; // duración para servicios, SKU para productos

  const _ItemCatalogo({
    required this.nombre,
    required this.precio,
    required this.ivaPorcentaje,
    this.sku,
    required this.unidadDefecto,
    required this.esServicio,
    this.etiquetaExtra,
  });

  static _ItemCatalogo desdeProducto(Producto p) => _ItemCatalogo(
    nombre: p.nombre,
    precio: p.precio,
    ivaPorcentaje: p.ivaPorcentaje,
    sku: p.sku,
    unidadDefecto: 'ud',
    esServicio: false,
    etiquetaExtra: p.sku?.isNotEmpty == true ? p.sku : null,
  );

  static _ItemCatalogo desdeServicio(Servicio s, double ivaDefault) {
    final h = s.duracion.inHours;
    final m = s.duracion.inMinutes % 60;
    final durStr = h > 0 ? (m > 0 ? '${h}h ${m}min' : '${h}h') : '${m}min';
    return _ItemCatalogo(
      nombre: s.nombre,
      precio: s.precio,
      ivaPorcentaje: ivaDefault,
      sku: null,
      unidadDefecto: 'servicio',
      esServicio: true,
      etiquetaExtra: durStr != '0min' ? durStr : null,
    );
  }
}

// ── Buscador unificado productos + servicios ──────────────────────────────────

class _CatalogoBuscador extends StatefulWidget {
  final String empresaId;
  final double ivaDefault;
  final void Function(_ItemCatalogo) onSeleccionado;

  const _CatalogoBuscador({
    required this.empresaId,
    required this.ivaDefault,
    required this.onSeleccionado,
  });

  @override
  State<_CatalogoBuscador> createState() => _CatalogoBuscadorState();
}

class _CatalogoBuscadorState extends State<_CatalogoBuscador> {
  final _ctrl = TextEditingController();
  List<_ItemCatalogo> _todos = [];
  List<_ItemCatalogo> _resultados = [];
  bool _abierto = false;
  bool _cargando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_todos.isNotEmpty) {
      setState(() => _abierto = true);
      return;
    }
    setState(() => _cargando = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId);

      // Carga productos y servicios en paralelo
      final results = await Future.wait([
        ref.collection('productos').where('activo', isEqualTo: true).limit(300).get(),
        ref.collection('servicios').where('activo', isEqualTo: true).limit(100).get(),
      ]);

      final productos = results[0].docs
          .map((d) => _ItemCatalogo.desdeProducto(Producto.fromFirestore(d)))
          .toList();
      final servicios = results[1].docs.map((d) {
        final data = d.data();
        final s = Servicio.fromFirestore(data, d.id);
        return _ItemCatalogo.desdeServicio(s, widget.ivaDefault);
      }).toList();

      final todos = [...productos, ...servicios]
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

      _todos = todos;
      _resultados = todos;
    } catch (_) {
      _todos = [];
      _resultados = [];
    } finally {
      if (mounted) setState(() { _cargando = false; _abierto = true; });
    }
  }

  void _buscar(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _resultados = lower.isEmpty
          ? _todos
          : _todos.where((i) =>
              i.nombre.toLowerCase().contains(lower) ||
              (i.sku?.toLowerCase().contains(lower) ?? false)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          onTap: () { if (!_abierto) _cargar(); },
          onChanged: _buscar,
          decoration: InputDecoration(
            hintText: 'Buscar producto o servicio...',
            prefixIcon: _cargando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimario)),
                  )
                : const Icon(Icons.search, size: 20, color: _kPrimario),
            suffixIcon: _abierto && _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () { _ctrl.clear(); setState(() => _resultados = _todos); },
                  )
                : null,
            filled: true,
            fillColor: _kPrimario.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _kPrimario.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _kPrimario.withValues(alpha: 0.25))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kPrimario, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
        if (_abierto) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kPrimario.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: _resultados.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Sin productos ni servicios configurados',
                        style: TextStyle(color: Colors.grey, fontSize: 13))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _resultados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (_, i) {
                      final item = _resultados[i];
                      final color = item.esServicio
                          ? const Color(0xFF7C3AED)
                          : _kPrimario;
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item.esServicio
                                ? Icons.design_services_outlined
                                : Icons.inventory_2_outlined,
                            size: 18, color: color),
                        ),
                        title: Text(item.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(
                          '${item.precio.toStringAsFixed(2)}€ s/IVA  ·  IVA ${item.ivaPorcentaje.toInt()}%'
                          '${item.etiquetaExtra != null ? '  ·  ${item.etiquetaExtra}' : ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        trailing: const Icon(Icons.north_west, size: 14, color: Colors.grey),
                        onTap: () {
                          widget.onSeleccionado(item);
                          setState(() { _ctrl.clear(); _abierto = false; _resultados = _todos; });
                        },
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

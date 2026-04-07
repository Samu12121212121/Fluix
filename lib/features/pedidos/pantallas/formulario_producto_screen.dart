import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';
import 'package:planeag_flutter/services/precio_service.dart';
import 'package:planeag_flutter/widgets/producto_imagen_widgets.dart';
import 'package:planeag_flutter/features/pedidos/widgets/variantes_editor_widget.dart';
import 'package:planeag_flutter/features/pedidos/widgets/historial_precios_widget.dart';
import 'package:uuid/uuid.dart';

class FormularioProductoScreen extends StatefulWidget {
  final String empresaId;
  final String? usuarioId;
  final Producto? productoEditar;

  const FormularioProductoScreen({
    super.key,
    required this.empresaId,
    this.usuarioId,
    this.productoEditar,
  });

  @override
  State<FormularioProductoScreen> createState() =>
      _FormularioProductoScreenState();
}

class _FormularioProductoScreenState extends State<FormularioProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barrasCtrl = TextEditingController();
  final _duracionCustomCtrl = TextEditingController();
  final PedidosService _svc = PedidosService();
  final PrecioService _precioSvc = PrecioService();
  static const _uuid = Uuid();

  late final String _productoId;

  List<VarianteProducto> _variantes = [];
  List<String> _etiquetas = [];
  final _etiquetaCtrl = TextEditingController();
  bool _destacado = false;
  bool _tieneVariantes = false;
  bool _guardando = false;
  double _ivaPorcentaje = 21;
  int? _duracionMinutos;
  bool _duracionCustom = false;
  String? _imagenUrl;

  // Opciones de duración predefinidas
  static const _duracionOpciones = [15, 30, 45, 60, 90, 120, 180];

  bool get _esEdicion => widget.productoEditar != null;

  @override
  void initState() {
    super.initState();
    _productoId = widget.productoEditar?.id ?? _uuid.v4();
    if (_esEdicion) {
      final p = widget.productoEditar!;
      _nombreCtrl.text = p.nombre;
      _descCtrl.text = p.descripcion ?? '';
      _precioCtrl.text = p.precio.toStringAsFixed(2);
      _stockCtrl.text = p.stock?.toString() ?? '';
      _categoriaCtrl.text = p.categoria;
      _skuCtrl.text = p.sku ?? '';
      _barrasCtrl.text = p.codigoBarras ?? '';
      _destacado = p.destacado;
      _tieneVariantes = p.tieneVariantes;
      _variantes = List.from(p.variantes);
      _etiquetas = List.from(p.etiquetas);
      _ivaPorcentaje = p.ivaPorcentaje;
      _imagenUrl = p.imagenUrl;
      _duracionMinutos = p.duracionMinutos;
      if (p.duracionMinutos != null &&
          !_duracionOpciones.contains(p.duracionMinutos)) {
        _duracionCustom = true;
        _duracionCustomCtrl.text = p.duracionMinutos.toString();
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _descCtrl, _precioCtrl, _stockCtrl, _categoriaCtrl,
      _skuCtrl, _barrasCtrl, _etiquetaCtrl, _duracionCustomCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── VALIDACIONES ──────────────────────────────────────────────────────────

  bool _variantesValidas() {
    if (!_tieneVariantes) return true;
    return _variantes.any((v) => v.disponible && v.precio != null);
  }

  // ── GUARDAR ───────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_variantesValidas()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Añade al menos una variante disponible con precio'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final precioNuevo =
        double.parse(_precioCtrl.text.replaceAll(',', '.'));
    final stock = int.tryParse(_stockCtrl.text);

    // Si es edición y el precio cambió, registrar en historial
    if (_esEdicion &&
        precioNuevo != widget.productoEditar!.precio &&
        !_tieneVariantes) {
      final resultado = await DialogCambioPrecio.mostrar(
        context,
        precioAnterior: widget.productoEditar!.precio,
        precioNuevo: precioNuevo,
      );
      if (resultado == null) return; // Canceló

      setState(() => _guardando = true);
      try {
        await _precioSvc.registrarCambio(
          empresaId: widget.empresaId,
          productoId: _productoId,
          precioAnterior: widget.productoEditar!.precio,
          precioNuevo: precioNuevo,
          motivo: resultado.motivo,
          motivoLibre: resultado.motivoLibre,
          usuarioId: widget.usuarioId ?? '',
          fechaEfectividad: resultado.fecha,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al registrar historial: $e'),
            backgroundColor: Colors.red,
          ));
        }
        setState(() => _guardando = false);
        return;
      }
    } else {
      setState(() => _guardando = true);
    }

    try {
      final datos = {
        'nombre': _nombreCtrl.text.trim(),
        'descripcion':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'categoria': _categoriaCtrl.text.trim(),
        'precio': precioNuevo,
        'stock': stock,
        'destacado': _destacado,
        'tiene_variantes': _tieneVariantes,
        'variantes': _variantes.map((v) => v.toMap()).toList(),
        'etiquetas': _etiquetas,
        'iva_porcentaje': _ivaPorcentaje,
        'duracion_minutos': _duracionMinutos,
        'sku': _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        'codigo_barras':
            _barrasCtrl.text.trim().isEmpty ? null : _barrasCtrl.text.trim(),
        if (_imagenUrl != null) 'imagen_url': _imagenUrl,
      };

      if (_esEdicion) {
        await _svc.actualizarProducto(
            widget.empresaId, _productoId, datos);
      } else {
        // Crear con ID pre-generado
        await _svc.crearProductoConId(
          empresaId: widget.empresaId,
          id: _productoId,
          datos: datos,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar producto' : 'Nuevo producto'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Guardar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── IMAGEN ──────────────────────────────────────────────────────
            _card('Imagen', [
              ProductoImagenPicker(
                empresaId: widget.empresaId,
                productoId: _productoId,
                imagenUrl: _imagenUrl,
                onImagenCambiada: (url) => setState(() => _imagenUrl = url),
              ),
            ]),
            const SizedBox(height: 12),

            // ── INFORMACIÓN BÁSICA ───────────────────────────────────────────
            _card('Información básica', [
              TextFormField(
                controller: _nombreCtrl,
                decoration: _deco('Nombre del producto *', Icons.inventory_2),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Nombre obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: _deco('Descripción', Icons.notes),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoriaCtrl,
                decoration: _deco('Categoría *', Icons.category),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Categoría obligatoria' : null,
              ),
            ]),
            const SizedBox(height: 12),

            // ── PRECIO Y VARIANTES ───────────────────────────────────────────
            _card('Precio', [
              SwitchListTile(
                value: _tieneVariantes,
                onChanged: (v) => setState(() => _tieneVariantes = v),
                title: const Text('Este producto tiene variantes',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Carnicería (pesos), peluquería (duraciones), restaurante (raciones)…',
                    style: TextStyle(fontSize: 11)),
                activeThumbColor: const Color(0xFF1976D2),
                contentPadding: EdgeInsets.zero,
              ),
              if (!_tieneVariantes) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _precioCtrl,
                  decoration: _deco('Precio base (€) *', Icons.euro),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (_tieneVariantes) return null;
                    if (v == null || v.trim().isEmpty) return 'Precio obligatorio';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                      return 'Precio inválido';
                    }
                    return null;
                  },
                ),
              ] else ...[
                const SizedBox(height: 8),
                // Precio oculto pero necesario para el rango
                TextFormField(
                  controller: _precioCtrl,
                  decoration: _deco('Precio referencia (€)', Icons.euro),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (_) => null,
                ),
                const SizedBox(height: 4),
                Text(
                  'El precio final lo determina cada variante',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                const SizedBox(height: 12),
                VariantesEditorWidget(
                  variantes: _variantes,
                  esServicio: _duracionMinutos != null,
                  onCambiadas: (v) => setState(() => _variantes = v),
                ),
              ],
              const SizedBox(height: 12),

              // IVA
              DropdownButtonFormField<double>(
                value: _ivaPorcentaje,
                decoration: _deco('IVA (%)', Icons.receipt_long),
                items: [0, 4, 10, 21]
                    .map((v) => DropdownMenuItem(
                        value: v.toDouble(),
                        child: Text('$v% IVA')))
                    .toList(),
                onChanged: (v) => setState(() => _ivaPorcentaje = v!),
              ),
            ]),
            const SizedBox(height: 12),

            // ── DURACIÓN (SERVICIOS) ─────────────────────────────────────────
            _card('Duración del servicio', [
              const Text(
                'Si es un servicio (no producto físico), configura la duración',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  // Sin duración
                  _chipDuracion(null, 'Sin duración'),
                  ..._duracionOpciones.map((m) =>
                      _chipDuracion(m, _formatDuracion(m))),
                  // Personalizado
                  FilterChip(
                    label: const Text('Personalizado'),
                    selected: _duracionCustom,
                    onSelected: (s) {
                      setState(() {
                        _duracionCustom = s;
                        if (!s) {
                          _duracionMinutos = null;
                          _duracionCustomCtrl.clear();
                        }
                      });
                    },
                    selectedColor:
                        const Color(0xFF1976D2).withValues(alpha: 0.15),
                    checkmarkColor: const Color(0xFF1976D2),
                    labelStyle: TextStyle(
                      color: _duracionCustom
                          ? const Color(0xFF1976D2)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_duracionCustom) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _duracionCustomCtrl,
                  decoration: _deco('Duración en minutos', Icons.timer),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _duracionMinutos = int.tryParse(v)),
                  validator: (v) {
                    if (!_duracionCustom) return null;
                    if (v == null || v.isEmpty) return 'Introduce los minutos';
                    if (int.tryParse(v) == null || int.parse(v) <= 0) {
                      return 'Valor inválido';
                    }
                    return null;
                  },
                ),
              ],
            ]),
            const SizedBox(height: 12),

            // ── STOCK Y DATOS ADICIONALES ────────────────────────────────────
            _card('Stock y referencias', [
              TextFormField(
                controller: _stockCtrl,
                decoration: _deco('Stock disponible (opcional)', Icons.inventory),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _skuCtrl,
                decoration:
                    _deco('SKU (referencia interna, opcional)', Icons.qr_code),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barrasCtrl,
                decoration:
                    _deco('Código de barras (opcional)', Icons.barcode_reader),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _destacado,
                onChanged: (v) => setState(() => _destacado = v),
                title: const Text('Producto destacado'),
                subtitle:
                    const Text('Aparece primero en el catálogo web'),
                activeThumbColor: const Color(0xFF1976D2),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 12),

            // ── ETIQUETAS ────────────────────────────────────────────────────
            _card('Etiquetas', [
              Wrap(
                spacing: 6, runSpacing: 6,
                children: _etiquetas
                    .map((e) => Chip(
                          label: Text(e,
                              style: const TextStyle(fontSize: 12)),
                          onDeleted: () =>
                              setState(() => _etiquetas.remove(e)),
                          backgroundColor: const Color(0xFF1976D2)
                              .withValues(alpha: 0.1),
                          deleteIconColor: const Color(0xFF1976D2),
                          labelStyle: const TextStyle(
                              color: Color(0xFF1976D2)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _etiquetaCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Nueva etiqueta...', isDense: true),
                    onSubmitted: (_) => _agregarEtiqueta(),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF1976D2)),
                    onPressed: _agregarEtiqueta),
              ]),
            ]),
            const SizedBox(height: 12),

            // ── HISTORIAL DE PRECIOS (solo en edición) ───────────────────────
            if (_esEdicion)
              HistorialPreciosWidget(
                empresaId: widget.empresaId,
                productoId: _productoId,
                precioActual:
                    double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ??
                        widget.productoEditar!.precio,
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _chipDuracion(int? minutos, String label) {
    final sel = !_duracionCustom && _duracionMinutos == minutos;
    return FilterChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) {
        setState(() {
          _duracionMinutos = minutos;
          _duracionCustom = false;
          _duracionCustomCtrl.clear();
        });
      },
      selectedColor: const Color(0xFF1976D2).withValues(alpha: 0.15),
      checkmarkColor: const Color(0xFF1976D2),
      labelStyle: TextStyle(
          color: sel ? const Color(0xFF1976D2) : Colors.black87),
    );
  }

  String _formatDuracion(int mins) {
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }
    return '${mins}min';
  }

  void _agregarEtiqueta() {
    final texto = _etiquetaCtrl.text.trim();
    if (texto.isEmpty || _etiquetas.contains(texto)) return;
    setState(() {
      _etiquetas.add(texto);
      _etiquetaCtrl.clear();
    });
  }

  Widget _card(String titulo, List<Widget> children) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1976D2))),
              const Divider(height: 16),
              ...children,
            ],
          ),
        ),
      );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      );
}



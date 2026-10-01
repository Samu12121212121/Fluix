import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/albaran_recibido.dart';
import 'package:planeag_flutter/domain/modelos/contabilidad.dart';
import 'package:planeag_flutter/services/contabilidad_service.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';

class FormularioAlbaranRecibidoScreen extends StatefulWidget {
  final String empresaId;
  final AlbaranRecibido? existente;

  const FormularioAlbaranRecibidoScreen({
    super.key,
    required this.empresaId,
    this.existente,
  });

  @override
  State<FormularioAlbaranRecibidoScreen> createState() =>
      _FormularioAlbaranRecibidoScreenState();
}

class _FormularioAlbaranRecibidoScreenState
    extends State<FormularioAlbaranRecibidoScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _svc      = ContabilidadService();
  bool _guardando = false;

  bool get _esEdicion => widget.existente != null;

  // Proveedor
  final _ctrlNombre   = TextEditingController();
  final _ctrlNif      = TextEditingController();
  final _ctrlTelefono = TextEditingController();

  // Autocomplete
  List<Proveedor> _proveedores = [];
  List<Proveedor> _sugerencias = [];

  // Documento
  final _ctrlNumero    = TextEditingController();
  DateTime _fechaAlbaran   = DateTime.now();
  DateTime _fechaRecepcion = DateTime.now();

  // Líneas
  final List<_LineaEditable> _lineas = [];

  // Estado
  EstadoAlbaranRecibido _estado = EstadoAlbaranRecibido.pendiente;

  // Notas
  final _ctrlNotas = TextEditingController();

  static const _primary = Color(0xFF1565C0);
  static const _bg      = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _cargarProveedores();
    final e = widget.existente;
    if (e != null) {
      _ctrlNombre.text   = e.nombreProveedor;
      _ctrlNif.text      = e.nifProveedor;
      _ctrlTelefono.text = e.telefonoProveedor;
      _ctrlNumero.text   = e.numeroAlbaran;
      _fechaAlbaran      = e.fechaAlbaran;
      _fechaRecepcion    = e.fechaRecepcion;
      _estado            = e.estado;
      _ctrlNotas.text    = e.notas;
      _lineas.addAll(e.lineas.map(_LineaEditable.fromLinea));
    }
    if (_lineas.isEmpty) _lineas.add(_LineaEditable());

    _ctrlNombre.addListener(_filtrarSugerencias);
  }

  Future<void> _cargarProveedores() async {
    _svc.obtenerProveedores(widget.empresaId).first.then((lista) {
      if (mounted) setState(() => _proveedores = lista);
    });
  }

  void _filtrarSugerencias() {
    final q = _ctrlNombre.text.trim().toLowerCase();
    setState(() {
      _sugerencias = q.length < 2
          ? []
          : _proveedores
              .where((p) =>
                  p.nombre.toLowerCase().contains(q) ||
                  (p.nif?.toLowerCase().contains(q) ?? false))
              .take(5)
              .toList();
    });
  }

  void _seleccionarProveedor(Proveedor p) {
    setState(() {
      _ctrlNombre.text   = p.nombre;
      _ctrlNif.text      = p.nif ?? '';
      _ctrlTelefono.text = p.telefono ?? '';
      _sugerencias       = [];
    });
    // quitar foco del campo nombre
    FocusScope.of(context).nextFocus();
  }

  @override
  void dispose() {
    _ctrlNombre.removeListener(_filtrarSugerencias);
    _ctrlNombre.dispose();
    _ctrlNif.dispose();
    _ctrlTelefono.dispose();
    _ctrlNumero.dispose();
    _ctrlNotas.dispose();
    for (final l in _lineas) { l.dispose(); }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: FluixAppBar(
        titulo: _esEdicion ? 'Editar albarán' : 'Nuevo albarán recibido',
        showLeading: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _seccionProveedor(),
            const SizedBox(height: 16),
            _seccion('Documento', Icons.receipt_long, [
              _campo(_ctrlNumero, 'Nº albarán del proveedor *',
                  validator: _requerido),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _selectorFecha('Fecha albarán', _fechaAlbaran,
                    (d) => setState(() => _fechaAlbaran = d))),
                const SizedBox(width: 12),
                Expanded(child: _selectorFecha('Fecha recepción', _fechaRecepcion,
                    (d) => setState(() => _fechaRecepcion = d))),
              ]),
            ]),
            const SizedBox(height: 16),
            _seccionLineas(),
            const SizedBox(height: 16),
            _seccion('Estado', Icons.flag_outlined, [_estadoPicker()]),
            const SizedBox(height: 16),
            _seccion('Notas', Icons.notes, [
              _campo(_ctrlNotas, 'Observaciones, incidencias...', maxLines: 3),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _botonGuardar(),
    );
  }

  // ── Sección proveedor con autocomplete ────────────────────────────────────

  Widget _seccionProveedor() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.business, color: _primary, size: 18),
            SizedBox(width: 8),
            Text('Proveedor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),

          // Campo nombre con sugerencias
          _campo(_ctrlNombre, 'Nombre del proveedor *', validator: _requerido),

          // Sugerencias desplegables
          if (_sugerencias.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _sugerencias.map((p) => _itemSugerencia(p)).toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),
          _campo(_ctrlNif, 'NIF/CIF (opcional)',
              hint: 'Se rellena solo si eliges un proveedor guardado'),
          const SizedBox(height: 12),
          _campo(_ctrlTelefono, 'Teléfono (opcional)',
              tipo: TextInputType.phone),
        ]),
      ),
    );
  }

  Widget _itemSugerencia(Proveedor p) {
    return InkWell(
      onTap: () => _seleccionarProveedor(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.business, size: 16, color: _primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (p.nif != null)
                Text(p.nif!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          )),
          const Icon(Icons.north_west, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }

  // ── Sección líneas ────────────────────────────────────────────────────────

  Widget _seccionLineas() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.list_alt, color: _primary, size: 20),
            const SizedBox(width: 8),
            const Text('Artículos / líneas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _lineas.add(_LineaEditable())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir'),
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
          ]),
          const SizedBox(height: 8),
          ..._lineas.asMap().entries.map((e) => _tarjetaLinea(e.key, e.value)),
        ]),
      ),
    );
  }

  Widget _tarjetaLinea(int idx, _LineaEditable linea) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBD0ED)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
            child: Center(child: Text('${idx + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold))),
          ),
          const Spacer(),
          if (_lineas.length > 1)
            GestureDetector(
              onTap: () => setState(() {
                _lineas[idx].dispose();
                _lineas.removeAt(idx);
              }),
              child: const Icon(Icons.close, size: 18, color: Colors.red),
            ),
        ]),
        const SizedBox(height: 8),
        _campo(linea.ctrlDescripcion, 'Descripción / nombre *',
            validator: _requerido),
        const SizedBox(height: 8),
        _campo(linea.ctrlReferencia, 'Referencia (opcional)',
            hint: 'Código del proveedor, EAN...'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _campo(linea.ctrlCantPedida, 'Cant. pedida',
              tipo: const TextInputType.numberWithOptions(decimal: true),
              hint: '0')),
          const SizedBox(width: 8),
          Expanded(child: _campo(linea.ctrlCantRecibida, 'Cant. recibida *',
              tipo: const TextInputType.numberWithOptions(decimal: true),
              validator: _requerido)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _campo(linea.ctrlPrecioUnitario, 'Precio unit. s/IVA (€)',
                tipo: const TextInputType.numberWithOptions(decimal: true),
                hint: 'Opcional'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge(
                  [linea.ctrlPrecioUnitario, linea.ctrlCantRecibida]),
              builder: (_, __) {
                final precio = double.tryParse(
                    linea.ctrlPrecioUnitario.text.replaceAll(',', '.')) ?? 0;
                final cant = double.tryParse(
                    linea.ctrlCantRecibida.text.replaceAll(',', '.')) ?? 0;
                final total = precio * cant;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: total > 0
                        ? _primary.withValues(alpha: 0.06)
                        : const Color(0xFFEFF4FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: total > 0
                            ? _primary.withValues(alpha: 0.3)
                            : const Color(0xFFBBD0ED)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Importe',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        total > 0
                            ? '${total.toStringAsFixed(2)} €'
                            : '—',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: total > 0 ? _primary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _campo(linea.ctrlNotas, 'Notas (daños, discrepancias...)', maxLines: 2),
      ]),
    );
  }

  // ── Estado picker ─────────────────────────────────────────────────────────

  Widget _estadoPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EstadoAlbaranRecibido.values.map((e) {
        final sel = _estado == e;
        return GestureDetector(
          onTap: () => setState(() => _estado = e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? _colorEstado(e) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? _colorEstado(e) : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_iconoEstado(e),
                  size: 14, color: sel ? Colors.white : Colors.grey[700]),
              const SizedBox(width: 6),
              Text(e.etiqueta,
                  style: TextStyle(
                      color: sel ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Selector fecha ────────────────────────────────────────────────────────

  Widget _selectorFecha(String label, DateTime fecha, ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: fecha,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey,
              fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 13, color: _primary),
            const SizedBox(width: 6),
            Text(_fmtDate(fecha),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  Widget _seccion(String titulo, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: _primary, size: 18),
            const SizedBox(width: 8),
            Text(titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  Widget _campo(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType tipo = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }

  Widget _botonGuardar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: ElevatedButton.icon(
        onPressed: _guardando ? null : _guardar,
        icon: _guardando
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save),
        label: Text(_guardando
            ? 'Guardando...'
            : _esEdicion ? 'Actualizar' : 'Guardar albarán'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final lineas = _lineas
          .where((l) => l.ctrlDescripcion.text.trim().isNotEmpty)
          .map((l) {
            final precioStr = l.ctrlPrecioUnitario.text.trim().replaceAll(',', '.');
            final precio = precioStr.isEmpty ? null : double.tryParse(precioStr);
            return LineaAlbaran(
              descripcion:      l.ctrlDescripcion.text.trim(),
              referencia:       l.ctrlReferencia.text.trim(),
              cantidadPedida:   double.tryParse(l.ctrlCantPedida.text) ?? 0,
              cantidadRecibida: double.tryParse(l.ctrlCantRecibida.text) ?? 0,
              notas:            l.ctrlNotas.text.trim(),
              precioUnitario:   precio,
            );
          })
          .toList();

      await _svc.guardarAlbaranRecibido(
        empresaId:         widget.empresaId,
        numeroAlbaran:     _ctrlNumero.text,
        nombreProveedor:   _ctrlNombre.text,
        fechaAlbaran:      _fechaAlbaran,
        fechaRecepcion:    _fechaRecepcion,
        lineas:            lineas,
        nifProveedor:      _ctrlNif.text,
        telefonoProveedor: _ctrlTelefono.text,
        estado:            _estado,
        notas:             _ctrlNotas.text,
        idEditar:          widget.existente?.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_esEdicion ? 'Albarán actualizado' : 'Albarán guardado'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _requerido(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _colorEstado(EstadoAlbaranRecibido e) {
    switch (e) {
      case EstadoAlbaranRecibido.pendiente:   return Colors.orange;
      case EstadoAlbaranRecibido.conforme:    return Colors.green;
      case EstadoAlbaranRecibido.disconforme: return Colors.red;
      case EstadoAlbaranRecibido.parcial:     return Colors.blue;
    }
  }

  IconData _iconoEstado(EstadoAlbaranRecibido e) {
    switch (e) {
      case EstadoAlbaranRecibido.pendiente:   return Icons.schedule;
      case EstadoAlbaranRecibido.conforme:    return Icons.check_circle_outline;
      case EstadoAlbaranRecibido.disconforme: return Icons.cancel_outlined;
      case EstadoAlbaranRecibido.parcial:     return Icons.remove_circle_outline;
    }
  }
}

// ── Clase auxiliar para editar una línea ─────────────────────────────────────

class _LineaEditable {
  final ctrlDescripcion    = TextEditingController();
  final ctrlReferencia     = TextEditingController();
  final ctrlCantPedida     = TextEditingController();
  final ctrlCantRecibida   = TextEditingController();
  final ctrlPrecioUnitario = TextEditingController();
  final ctrlNotas          = TextEditingController();

  _LineaEditable();

  static _LineaEditable fromLinea(LineaAlbaran l) {
    final e = _LineaEditable();
    e.ctrlDescripcion.text    = l.descripcion;
    e.ctrlReferencia.text     = l.referencia;
    e.ctrlCantPedida.text     = l.cantidadPedida > 0
        ? l.cantidadPedida.toStringAsFixed(2) : '';
    e.ctrlCantRecibida.text   = l.cantidadRecibida > 0
        ? l.cantidadRecibida.toStringAsFixed(2) : '';
    e.ctrlPrecioUnitario.text = l.precioUnitario != null
        ? l.precioUnitario!.toStringAsFixed(2) : '';
    e.ctrlNotas.text          = l.notas;
    return e;
  }

  void dispose() {
    ctrlDescripcion.dispose();
    ctrlReferencia.dispose();
    ctrlCantPedida.dispose();
    ctrlCantRecibida.dispose();
    ctrlPrecioUnitario.dispose();
    ctrlNotas.dispose();
  }
}

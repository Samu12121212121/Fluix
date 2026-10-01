import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/factura_recibida.dart';
import 'package:planeag_flutter/services/contabilidad_service.dart';
import 'package:planeag_flutter/core/utils/validador_nif_cif.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';

const _kPrimaryFR = Color(0xFF0D47A1);

class FormularioFacturaRecibidaScreen extends StatefulWidget {
  final String empresaId;
  final FacturaRecibida? facturaExistente;
  final String? nombreProveedorInicial;
  final String? nifProveedorInicial;

  const FormularioFacturaRecibidaScreen({
    super.key,
    required this.empresaId,
    this.facturaExistente,
    this.nombreProveedorInicial,
    this.nifProveedorInicial,
  });

  @override
  State<FormularioFacturaRecibidaScreen> createState() =>
      _FormularioFacturaRecibidaScreenState();
}

class _FormularioFacturaRecibidaScreenState
    extends State<FormularioFacturaRecibidaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ContabilidadService();
  bool _guardando = false;
  bool get _esEdicion => widget.facturaExistente != null;

  // Datos proveedor
  final _ctrlNumeroFactura = TextEditingController();
  final _ctrlNifProveedor = TextEditingController();
  final _ctrlNombreProveedor = TextEditingController();
  final _ctrlDireccionProveedor = TextEditingController();
  final _ctrlTelefonoProveedor = TextEditingController();

  // Fechas
  DateTime? _fechaEmision;
  DateTime? _fechaRecepcion;

  // Importes
  final _ctrlBaseImponible = TextEditingController();
  double _porcentajeIva = 21.0;
  bool _ivaDeducible = true;
  final _ctrlDescuentoGlobal = TextEditingController(text: '0');

  // Notas
  final _ctrlNotas = TextEditingController();

  // Arrendamiento (Mod.115)
  bool _esArrendamiento = false;
  final _ctrlNifArrendador = TextEditingController();
  final _ctrlConceptoArrendamiento = TextEditingController();

  // IRPF y estado de pago
  double _porcentajeRetencion = 0;
  EstadoFacturaRecibida _estadoPago = EstadoFacturaRecibida.pendiente;
  DateTime? _fechaPago;
  String? _metodoPago;

  // Validación
  String? _errorNif;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _precargarFactura(widget.facturaExistente!);
    } else {
      _fechaEmision = DateTime.now();
      _fechaRecepcion = DateTime.now();
      if (widget.nombreProveedorInicial != null) _ctrlNombreProveedor.text = widget.nombreProveedorInicial!;
      if (widget.nifProveedorInicial != null) _ctrlNifProveedor.text = widget.nifProveedorInicial!;
    }
  }

  void _precargarFactura(FacturaRecibida f) {
    _ctrlNumeroFactura.text = f.numeroFactura;
    _ctrlNifProveedor.text = f.nifProveedor;
    _ctrlNombreProveedor.text = f.nombreProveedor;
    _ctrlDireccionProveedor.text = f.direccionProveedor ?? '';
    _ctrlTelefonoProveedor.text = f.telefonoProveedor ?? '';
    _fechaEmision = f.fechaEmision;
    _fechaRecepcion = f.fechaRecepcion;
    _ctrlBaseImponible.text = f.baseImponible.toStringAsFixed(2);
    _porcentajeIva = f.porcentajeIva;
    _ivaDeducible = f.ivaDeducible;
    _ctrlDescuentoGlobal.text = f.descuentoGlobal.toStringAsFixed(2);
    _esArrendamiento = f.esArrendamiento;
    _ctrlNifArrendador.text = f.nifArrendador ?? '';
    _ctrlConceptoArrendamiento.text = f.conceptoArrendamiento ?? '';
    _ctrlNotas.text = f.notas ?? '';
    _porcentajeRetencion = f.porcentajeRetencion ?? 0;
    _estadoPago = f.estado;
    _fechaPago = f.fechaPago;
    _metodoPago = f.metodoPago;
  }

  @override
  void dispose() {
    _ctrlNumeroFactura.dispose();
    _ctrlNifProveedor.dispose();
    _ctrlNombreProveedor.dispose();
    _ctrlDireccionProveedor.dispose();
    _ctrlTelefonoProveedor.dispose();
    _ctrlBaseImponible.dispose();
    _ctrlDescuentoGlobal.dispose();
    _ctrlNotas.dispose();
    _ctrlNifArrendador.dispose();
    _ctrlConceptoArrendamiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: FluixAppBar(
        titulo: _esEdicion ? 'Editar factura recibida' : 'Nueva factura recibida',
        showLeading: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Datos proveedor
            _buildSeccion('👤 Datos del Proveedor', [
              TextFormField(
                controller: _ctrlNombreProveedor,
                decoration: _inputDeco('Nombre del proveedor *'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlNifProveedor,
                decoration: _inputDeco(
                  'NIF/CIF *',
                  hintText: '12345678Z o A12345678',
                  errorText: _errorNif,
                ),
                onChanged: (v) {
                  setState(() {
                    if (v.isEmpty) {
                      _errorNif = null;
                    } else {
                      final validacion = ValidadorNifCif.validar(v);
                      _errorNif = validacion.valido ? null : validacion.razon;
                    }
                  });
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  final validacion = ValidadorNifCif.validar(v);
                  return validacion.valido ? null : validacion.razon;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlDireccionProveedor,
                decoration: _inputDeco('Dirección'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlTelefonoProveedor,
                decoration: _inputDeco('Teléfono'),
                keyboardType: TextInputType.phone,
              ),
            ]),
            const SizedBox(height: 16),
            // Datos factura
            _buildSeccion('📄 Datos de la Factura', [
              TextFormField(
                controller: _ctrlNumeroFactura,
                decoration: _inputDeco('Número de factura *'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fecha emisión *',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _seleccionarFechaEmision,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _fmtDate(_fechaEmision),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fecha recepción *',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _seleccionarFechaRecepcion,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _fmtDate(_fechaRecepcion),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 16),
            // Importes
            _buildSeccion('💰 Importes e Impuestos', [
              TextFormField(
                controller: _ctrlBaseImponible,
                decoration: _inputDeco('Base imponible *'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obligatorio';
                  if (double.tryParse(v) == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                value: _porcentajeIva,
                decoration: _inputDeco('IVA aplicable'),
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('0% - Exento')),
                  DropdownMenuItem(value: 4.0, child: Text('4% - Superreducido')),
                  DropdownMenuItem(value: 10.0, child: Text('10% - Reducido')),
                  DropdownMenuItem(value: 21.0, child: Text('21% - General')),
                ],
                onChanged: (v) => setState(() => _porcentajeIva = v ?? 21.0),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('IVA deducible'),
                subtitle: const Text(
                  'Marca si el IVA es deducible en tu declaración',
                ),
                value: _ivaDeducible,
                onChanged: (v) => setState(() => _ivaDeducible = v ?? true),
                activeColor: const Color(0xFF0D47A1),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlDescuentoGlobal,
                decoration: _inputDeco('Descuento global (%)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            // IRPF + Estado de pago
            _buildSeccionPago(),
            const SizedBox(height: 16),
            // Arrendamiento (Mod.115)
            _buildSeccion('🏢 Arrendamiento de Local', [
              SwitchListTile(
                title: const Text('¿Es arrendamiento de local de negocio?'),
                subtitle: const Text(
                  'Activa si esta factura es el alquiler de tu local.\n'
                  'Se incluirá en el Modelo 115 (retención 19%).',
                  style: TextStyle(fontSize: 11),
                ),
                value: _esArrendamiento,
                onChanged: (v) => setState(() => _esArrendamiento = v),
                activeColor: const Color(0xFF0D47A1),
                contentPadding: EdgeInsets.zero,
              ),
              if (_esArrendamiento) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ctrlNifArrendador,
                  decoration: _inputDeco(
                    'NIF del arrendador *',
                    hintText: 'NIF/NIE/CIF del propietario del local',
                  ),
                  validator: (v) {
                    if (!_esArrendamiento) return null;
                    if (v == null || v.isEmpty) return 'Obligatorio para arrendamiento';
                    final val = ValidadorNifCif.validar(v);
                    return val.valido ? null : val.razon;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ctrlConceptoArrendamiento,
                  decoration: _inputDeco(
                    'Concepto (opcional)',
                    hintText: 'Ej: Alquiler local C/ Mayor 5, enero 2026',
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 16),
            // Notas
            _buildSeccion('📝 Notas', [
              TextFormField(
                controller: _ctrlNotas,
                decoration: _inputDeco('Notas sobre la factura'),
                maxLines: 2,
              ),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBotonGuardar(),
    );
  }

  Widget _buildSeccionPago() {
    final base = double.tryParse(_ctrlBaseImponible.text.replaceAll(',', '.')) ?? 0;
    final retencion = base * _porcentajeRetencion / 100;
    final iva = base * _porcentajeIva / 100;
    final total = base + iva - retencion;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💳 Retención IRPF y Estado de Pago',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),

          // IRPF
          Text('Retención IRPF',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _chipIrpf(0, 'Sin retención'),
              _chipIrpf(7, '7% — Nuevo autónomo'),
              _chipIrpf(15, '15% — Estándar'),
              _chipIrpf(19, '19% — Profesional'),
            ],
          ),
          if (_porcentajeRetencion > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _ctrlBaseImponible,
                    builder: (_, __) => Text(
                      'Retención: ${retencion.toStringAsFixed(2)} €  ·  Total a pagar: ${total.toStringAsFixed(2)} €',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Estado de pago
          Text('Estado de pago',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: EstadoFacturaRecibida.values.map((e) {
              final sel = _estadoPago == e;
              return GestureDetector(
                onTap: () => setState(() {
                  _estadoPago = e;
                  if (e != EstadoFacturaRecibida.pagada) {
                    _fechaPago = null;
                    _metodoPago = null;
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _colorEstado(e) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? _colorEstado(e) : Colors.grey[300]!),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_iconoEstado(e), size: 14,
                        color: sel ? Colors.white : Colors.grey[700]),
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
          ),

          // Campos extra si pagada
          if (_estadoPago == EstadoFacturaRecibida.pagada) ...[
            const SizedBox(height: 14),
            // Método de pago
            DropdownButtonFormField<String>(
              value: _metodoPago,
              decoration: _inputDeco('Método de pago'),
              items: const [
                DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'domiciliacion', child: Text('Domiciliación')),
                DropdownMenuItem(value: 'bizum', child: Text('Bizum')),
              ],
              onChanged: (v) => setState(() => _metodoPago = v),
            ),
            const SizedBox(height: 12),
            // Fecha de pago
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fechaPago ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _fechaPago = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: _kPrimaryFR),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _fechaPago != null
                        ? 'Pagada el ${_fechaPago!.day.toString().padLeft(2, '0')}/${_fechaPago!.month.toString().padLeft(2, '0')}/${_fechaPago!.year}'
                        : 'Fecha de pago (opcional)',
                    style: TextStyle(
                      fontSize: 14,
                      color: _fechaPago != null ? Colors.black87 : Colors.grey[500],
                    ),
                  )),
                  if (_fechaPago != null)
                    GestureDetector(
                      onTap: () => setState(() => _fechaPago = null),
                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _chipIrpf(double pct, String label) {
    final sel = _porcentajeRetencion == pct;
    return GestureDetector(
      onTap: () => setState(() => _porcentajeRetencion = pct),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.orange : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? Colors.orange : Colors.grey[300]!),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Color _colorEstado(EstadoFacturaRecibida e) {
    switch (e) {
      case EstadoFacturaRecibida.pendiente:  return Colors.orange;
      case EstadoFacturaRecibida.recibida:   return Colors.blue;
      case EstadoFacturaRecibida.pagada:     return Colors.green;
      case EstadoFacturaRecibida.rechazada:  return Colors.red;
    }
  }

  IconData _iconoEstado(EstadoFacturaRecibida e) {
    switch (e) {
      case EstadoFacturaRecibida.pendiente:  return Icons.schedule;
      case EstadoFacturaRecibida.recibida:   return Icons.mark_email_read_outlined;
      case EstadoFacturaRecibida.pagada:     return Icons.check_circle_outline;
      case EstadoFacturaRecibida.rechazada:  return Icons.cancel_outlined;
    }
  }

  Widget _buildSeccion(String titulo, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(
    String label, {
    String? hintText,
    String? errorText,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0D47A1)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _buildBotonGuardar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _guardando ? null : _guardar,
        icon: _guardando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_guardando
            ? 'Guardando...'
            : _esEdicion
                ? 'Actualizar'
                : 'Guardar Factura'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaEmision == null || _fechaRecepcion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Selecciona las fechas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validar NIF
    final validNif = ValidadorNifCif.validar(_ctrlNifProveedor.text);
    if (!validNif.valido) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${validNif.razon}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final baseImponible =
          double.tryParse(_ctrlBaseImponible.text) ?? 0;
      final descuentoGlobal =
          double.tryParse(_ctrlDescuentoGlobal.text) ?? 0;

      await _service.guardarFacturaRecibida(
        empresaId: widget.empresaId,
        numeroFactura: _ctrlNumeroFactura.text,
        nifProveedor: _ctrlNifProveedor.text,
        nombreProveedor: _ctrlNombreProveedor.text,
        baseImponible: baseImponible,
        porcentajeIva: _porcentajeIva,
        fechaEmision: _fechaEmision,
        fechaRecepcion: _fechaRecepcion,
        ivaDeducible: _ivaDeducible,
        descuentoGlobal: descuentoGlobal,
        direccionProveedor: _ctrlDireccionProveedor.text.isEmpty
            ? null
            : _ctrlDireccionProveedor.text,
        telefonoProveedor: _ctrlTelefonoProveedor.text.isEmpty
            ? null
            : _ctrlTelefonoProveedor.text,
        notas: _ctrlNotas.text.isEmpty ? null : _ctrlNotas.text,
        facturaRecibidaIdEditar:
            _esEdicion ? widget.facturaExistente!.id : null,
        esArrendamiento: _esArrendamiento,
        nifArrendador: _esArrendamiento && _ctrlNifArrendador.text.isNotEmpty
            ? _ctrlNifArrendador.text
            : null,
        conceptoArrendamiento: _esArrendamiento && _ctrlConceptoArrendamiento.text.isNotEmpty
            ? _ctrlConceptoArrendamiento.text
            : null,
        porcentajeRetencion: _porcentajeRetencion > 0 ? _porcentajeRetencion : null,
        estado: _estadoPago,
        fechaPago: _fechaPago,
        metodoPago: _metodoPago,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion
                ? '✅ Factura actualizada'
                : '✅ Factura guardada'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _seleccionarFechaEmision() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaEmision ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) {
      setState(() => _fechaEmision = fecha);
    }
  }

  Future<void> _seleccionarFechaRecepcion() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaRecepcion ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) {
      setState(() => _fechaRecepcion = fecha);
    }
  }

  String _fmtDate(DateTime? date) {
    if (date == null) return '--/--/--';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}



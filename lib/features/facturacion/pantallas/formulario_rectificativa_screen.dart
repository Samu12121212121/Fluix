import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';

/// Pantalla de formulario para crear una factura rectificativa
/// según Art. 15 del RD 1619/2012 (Reglamento de Facturación).
class FormularioRectificativaScreen extends StatefulWidget {
  final String empresaId;
  final Factura facturaOriginal;

  const FormularioRectificativaScreen({
    super.key,
    required this.empresaId,
    required this.facturaOriginal,
  });

  @override
  State<FormularioRectificativaScreen> createState() =>
      _FormularioRectificativaScreenState();
}

class _FormularioRectificativaScreenState
    extends State<FormularioRectificativaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FacturacionService();
  bool _guardando = false;

  // ── Campos de rectificación ──
  MotivoRectificacion _motivo = MotivoRectificacion.errorImportes;
  MetodoRectificacion _metodo = MetodoRectificacion.sustitucion;
  final _ctrlMotivoTexto = TextEditingController();

  // ── Datos fiscales corregidos (solo si motivo == errorDatosDestinatario) ──
  final _ctrlNif = TextEditingController();
  final _ctrlRazonSocial = TextEditingController();
  final _ctrlDireccion = TextEditingController();
  final _ctrlCodigoPostal = TextEditingController();
  final _ctrlCiudad = TextEditingController();

  // ── Líneas editables ──
  late List<_LineaEditable> _lineas;

  Factura get _original => widget.facturaOriginal;

  String get _userName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Pre-cargar datos fiscales del original
    final df = _original.datosFiscales;
    _ctrlNif.text = df?.nif ?? '';
    _ctrlRazonSocial.text = df?.razonSocial ?? '';
    _ctrlDireccion.text = df?.direccion ?? '';
    _ctrlCodigoPostal.text = df?.codigoPostal ?? '';
    _ctrlCiudad.text = df?.ciudad ?? '';

    // Pre-cargar líneas copiadas de la original
    _lineas = _original.lineas.map((l) => _LineaEditable.from(l)).toList();
  }

  @override
  void dispose() {
    _ctrlMotivoTexto.dispose();
    _ctrlNif.dispose();
    _ctrlRazonSocial.dispose();
    _ctrlDireccion.dispose();
    _ctrlCodigoPostal.dispose();
    _ctrlCiudad.dispose();
    for (final l in _lineas) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Crear Factura Rectificativa'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Info de la factura original ──
            _buildInfoOriginal(),
            const SizedBox(height: 20),

            // ── Motivo de rectificación ──
            _buildSeccion(
              '📋 Motivo de Rectificación',
              '(Art. 15 RD 1619/2012)',
              [
                _buildDropdownMotivo(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ctrlMotivoTexto,
                  decoration: const InputDecoration(
                    labelText: 'Descripción adicional del motivo',
                    hintText: 'Detalle la causa de la rectificación…',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Método de rectificación ──
            _buildSeccion(
              '⚙️ Método de Rectificación',
              null,
              [_buildDropdownMetodo()],
            ),
            const SizedBox(height: 16),

            // ── Datos fiscales (si se corrigen) ──
            if (_motivo == MotivoRectificacion.errorDatosDestinatario) ...[
              _buildSeccion(
                '🏢 Datos Fiscales Corregidos',
                null,
                [
                  TextFormField(
                    controller: _ctrlNif,
                    decoration: const InputDecoration(
                      labelText: 'NIF/CIF',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ctrlRazonSocial,
                    decoration: const InputDecoration(
                      labelText: 'Razón Social',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ctrlDireccion,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ctrlCodigoPostal,
                        decoration: const InputDecoration(
                          labelText: 'Código Postal',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _ctrlCiudad,
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Líneas (si se corrigen importes) ──
            if (_motivo != MotivoRectificacion.errorDatosDestinatario) ...[
              _buildSeccion(
                '🛒 Líneas de la Factura',
                _metodo == MetodoRectificacion.sustitucion
                    ? 'Introduzca los datos correctos completos'
                    : 'Introduzca solo la diferencia (positiva o negativa)',
                [
                  ..._lineas.asMap().entries.map((e) => _buildLineaEditable(e.key, e.value)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _agregarLinea,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir línea'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Resumen de totales ──
              _buildResumenTotales(),
              const SizedBox(height: 16),
            ],

            // ── Botón crear ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _crearRectificativa,
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle, color: Colors.white),
                label: Text(
                  _guardando ? 'Creando…' : 'Crear Factura Rectificativa',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── WIDGETS AUXILIARES ─────────────────────────────────────────────────────

  Widget _buildInfoOriginal() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.receipt_long, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              const Text('Factura a rectificar',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.deepPurple)),
            ]),
            const SizedBox(height: 10),
            _infoRow('Número', _original.numeroFactura),
            _infoRow('Fecha emisión', _formatFecha(_original.fechaEmision)),
            _infoRow('Cliente', _original.clienteNombre),
            _infoRow('Total', '${_original.total.toStringAsFixed(2)} €'),
            if (_original.datosFiscales?.nif != null)
              _infoRow('NIF', _original.datosFiscales!.nif!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildSeccion(String titulo, String? subtitulo, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            if (subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(subtitulo,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownMotivo() {
    return DropdownButtonFormField<MotivoRectificacion>(
      initialValue: _motivo,
      decoration: const InputDecoration(
        labelText: 'Tipo de motivo',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.error_outline),
      ),
      isExpanded: true,
      items: MotivoRectificacion.values
          .map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.etiqueta, style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() {
            _motivo = v;
            // Devolución total: método diferencias con líneas invertidas
            if (v == MotivoRectificacion.devolucionTotal) {
              _metodo = MetodoRectificacion.diferencias;
              _lineas = _original.lineas
                  .map((l) => _LineaEditable.from(l, invertir: true))
                  .toList();
            }
          });
        }
      },
    );
  }

  Widget _buildDropdownMetodo() {
    return DropdownButtonFormField<MetodoRectificacion>(
      initialValue: _metodo,
      decoration: const InputDecoration(
        labelText: 'Método',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.swap_horiz),
      ),
      isExpanded: true,
      items: MetodoRectificacion.values
          .map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.etiqueta, style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _metodo = v);
      },
    );
  }

  Widget _buildLineaEditable(int index, _LineaEditable linea) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Línea ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (_lineas.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => setState(() {
                    _lineas[index].dispose();
                    _lineas.removeAt(index);
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: linea.ctrlDescripcion,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: linea.ctrlPrecio,
                decoration: const InputDecoration(
                  labelText: 'Precio €',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) {
                    return 'Número inválido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: TextFormField(
                controller: linea.ctrlCantidad,
                decoration: const InputDecoration(
                  labelText: 'Cant.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return '!';
                  if (int.tryParse(v) == null) return '!';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: DropdownButtonFormField<double>(
                initialValue: linea.porcentajeIva,
                decoration: const InputDecoration(
                  labelText: 'IVA',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('0%')),
                  DropdownMenuItem(value: 4.0, child: Text('4%')),
                  DropdownMenuItem(value: 10.0, child: Text('10%')),
                  DropdownMenuItem(value: 21.0, child: Text('21%')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => linea.porcentajeIva = v);
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildResumenTotales() {
    final lineasFinales = _construirLineas();
    final totales = Factura.calcularTotales(
      lineas: lineasFinales,
      descuentoGlobal: _original.descuentoGlobal,
      porcentajeIrpf: _original.porcentajeIrpf,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 Resumen de la Rectificativa',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            _totalRow('Base imponible', totales['subtotal']!),
            _totalRow('IVA', totales['total_iva']!),
            if (totales['retencion_irpf']! != 0)
              _totalRow('IRPF', -totales['retencion_irpf']!),
            const Divider(),
            _totalRow('TOTAL', totales['total']!, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final color = value < 0 ? Colors.red : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('${value.toStringAsFixed(2)} €',
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  void _agregarLinea() {
    setState(() {
      _lineas.add(_LineaEditable(
        descripcion: '',
        precio: 0,
        cantidad: 1,
        porcentajeIva: 21.0,
      ));
    });
  }

  // ── CONSTRUIR LÍNEAS ──────────────────────────────────────────────────────

  List<LineaFactura> _construirLineas() {
    return _lineas.map((l) {
      final precio =
          double.tryParse(l.ctrlPrecio.text.replaceAll(',', '.')) ?? 0;
      final cantidad = int.tryParse(l.ctrlCantidad.text) ?? 1;
      return LineaFactura(
        descripcion: l.ctrlDescripcion.text,
        precioUnitario: precio,
        cantidad: cantidad,
        porcentajeIva: l.porcentajeIva,
      );
    }).toList();
  }

  // ── CREAR ─────────────────────────────────────────────────────────────────

  Future<void> _crearRectificativa() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      // Datos fiscales corregidos (solo si motivo == errorDatosDestinatario)
      DatosFiscales? dfCorregidos;
      if (_motivo == MotivoRectificacion.errorDatosDestinatario) {
        dfCorregidos = DatosFiscales(
          nif: _ctrlNif.text.trim().isNotEmpty ? _ctrlNif.text.trim() : null,
          razonSocial: _ctrlRazonSocial.text.trim().isNotEmpty
              ? _ctrlRazonSocial.text.trim()
              : null,
          direccion: _ctrlDireccion.text.trim().isNotEmpty
              ? _ctrlDireccion.text.trim()
              : null,
          codigoPostal: _ctrlCodigoPostal.text.trim().isNotEmpty
              ? _ctrlCodigoPostal.text.trim()
              : null,
          ciudad: _ctrlCiudad.text.trim().isNotEmpty
              ? _ctrlCiudad.text.trim()
              : null,
        );
      }

      // Líneas corregidas (si no es corrección de datos)
      List<LineaFactura>? lineas;
      if (_motivo != MotivoRectificacion.errorDatosDestinatario) {
        lineas = _construirLineas();
      }

      final nueva = await _service.crearFacturaRectificativa(
        empresaId: widget.empresaId,
        facturaOriginalId: _original.id,
        motivo: _motivo,
        metodo: _metodo,
        motivoTexto: _ctrlMotivoTexto.text.trim(),
        lineasCorregidas: lineas,
        datosFiscalesCorregidos: dfCorregidos,
        usuarioId: _userId,
        usuarioNombre: _userName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Rectificativa creada: ${nueva.numeroFactura}'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── MODELO INTERNO PARA LÍNEAS EDITABLES ──────────────────────────────────

class _LineaEditable {
  final TextEditingController ctrlDescripcion;
  final TextEditingController ctrlPrecio;
  final TextEditingController ctrlCantidad;
  double porcentajeIva;

  _LineaEditable({
    required String descripcion,
    required double precio,
    required int cantidad,
    required this.porcentajeIva,
  })  : ctrlDescripcion = TextEditingController(text: descripcion),
        ctrlPrecio = TextEditingController(text: precio.toStringAsFixed(2)),
        ctrlCantidad = TextEditingController(text: cantidad.toString());

  factory _LineaEditable.from(LineaFactura l, {bool invertir = false}) {
    return _LineaEditable(
      descripcion: invertir ? '[RECT] ${l.descripcion}' : l.descripcion,
      precio: invertir ? -l.precioUnitario : l.precioUnitario,
      cantidad: l.cantidad,
      porcentajeIva: l.porcentajeIva,
    );
  }

  void dispose() {
    ctrlDescripcion.dispose();
    ctrlPrecio.dispose();
    ctrlCantidad.dispose();
  }
}





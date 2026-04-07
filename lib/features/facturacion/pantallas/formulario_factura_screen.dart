import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/core/utils/validador_nif_cif.dart';
import 'package:planeag_flutter/widgets/cliente_selector_rapido.dart';

enum TipoClienteFactura { particular, empresaAutonomo }

class FormularioFacturaScreen extends StatefulWidget {
  final String empresaId;
  final String? pedidoId;
  final String? clienteNombreInicial;
  final List<Map<String, dynamic>>? lineasIniciales;
  final Factura? facturaExistente; // Para edición

  const FormularioFacturaScreen({
    super.key,
    required this.empresaId,
    this.pedidoId,
    this.clienteNombreInicial,
    this.lineasIniciales,
    this.facturaExistente,
  });

  @override
  State<FormularioFacturaScreen> createState() =>
      _FormularioFacturaScreenState();
}

class _FormularioFacturaScreenState extends State<FormularioFacturaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FacturacionService();
  bool _guardando = false;
  bool get _esEdicion => widget.facturaExistente != null;

  // Datos cliente
  final _ctrlClienteNombre = TextEditingController();
  final _ctrlClienteTelefono = TextEditingController();
  final _ctrlClienteCorreo = TextEditingController();
  final _ctrlNif = TextEditingController();
  final _ctrlRazonSocial = TextEditingController();
  final _ctrlDireccion = TextEditingController();
  TipoClienteFactura _tipoCliente = TipoClienteFactura.particular;
  bool _mostrarDatosFiscales = false;
  String? _errorValidacionNif;  // Mensaje de error NIF/CIF

  // Tipo y método
  TipoFactura _tipoFactura = TipoFactura.venta_directa;
  MetodoPagoFactura? _metodoPago;
  double _porcentajeIva = 21.0;

  // Campos fiscales avanzados
  final _ctrlDiasVencimiento = TextEditingController(text: '30');
  double _descuentoGlobal = 0;
  double _porcentajeIrpf = 0;

  // Líneas
  final List<LineaFactura> _lineas = [];

  // Notas
  final _ctrlNotasInternas = TextEditingController();
  final _ctrlNotasCliente = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.facturaExistente != null) {
      _precargarFactura(widget.facturaExistente!);
    } else {
      if (widget.clienteNombreInicial != null) {
        _ctrlClienteNombre.text = widget.clienteNombreInicial!;
      }
      if (widget.pedidoId != null) {
        _tipoFactura = TipoFactura.pedido;
      }
      if (widget.lineasIniciales != null) {
        for (final l in widget.lineasIniciales!) {
          _lineas.add(LineaFactura(
            descripcion: l['producto_nombre'] ?? '',
            precioUnitario: (l['precio_unitario'] as num?)?.toDouble() ?? 0,
            cantidad: (l['cantidad'] as num?)?.toInt() ?? 1,
            porcentajeIva: _porcentajeIva,
          ));
        }
      }
    }
  }

  void _precargarFactura(Factura f) {
    _ctrlClienteNombre.text = f.clienteNombre;
    _ctrlClienteTelefono.text = f.clienteTelefono ?? '';
    _ctrlClienteCorreo.text = f.clienteCorreo ?? '';
    _tipoFactura = f.tipo;
    _metodoPago = f.metodoPago;
    _ctrlDiasVencimiento.text = f.diasVencimiento.toString();
    _descuentoGlobal = f.descuentoGlobal;
    _porcentajeIrpf = f.porcentajeIrpf;
    _ctrlNotasInternas.text = f.notasInternas ?? '';
    _ctrlNotasCliente.text = f.notasCliente ?? '';
    _lineas.addAll(f.lineas);
    _tipoCliente = ((f.datosFiscales?.razonSocial?.trim().isNotEmpty ?? false) ||
            (f.datosFiscales?.direccion?.trim().isNotEmpty ?? false))
        ? TipoClienteFactura.empresaAutonomo
        : TipoClienteFactura.particular;
    if (f.datosFiscales?.tieneDatos == true) {
      _mostrarDatosFiscales = true;
      _ctrlNif.text = f.datosFiscales?.nif ?? '';
      _ctrlRazonSocial.text = f.datosFiscales?.razonSocial ?? '';
      _ctrlDireccion.text = f.datosFiscales?.direccion ?? '';
    }
    // Intentar leer el IVA de la primera línea
    if (f.lineas.isNotEmpty) {
      _porcentajeIva = f.lineas.first.porcentajeIva;
    }
  }

  @override
  void dispose() {
    _ctrlClienteNombre.dispose();
    _ctrlClienteTelefono.dispose();
    _ctrlClienteCorreo.dispose();
    _ctrlNif.dispose();
    _ctrlRazonSocial.dispose();
    _ctrlDireccion.dispose();
    _ctrlNotasInternas.dispose();
    _ctrlNotasCliente.dispose();
    _ctrlDiasVencimiento.dispose();
    super.dispose();
  }

  Map<String, double> get _totales => Factura.calcularTotales(
    lineas: _lineas,
    descuentoGlobal: _descuentoGlobal,
    porcentajeIrpf: _porcentajeIrpf,
  );

  double get _importeTotalActual => _totales['total'] ?? 0.0;
  bool get _esEmpresaOProfesional =>
      _tipoCliente == TipoClienteFactura.empresaAutonomo;
  bool get _nifObligatorio => _esEmpresaOProfesional || _importeTotalActual >= 400;
  bool get _debeMostrarDatosFiscales =>
      _mostrarDatosFiscales ||
      _esEmpresaOProfesional ||
      _nifObligatorio ||
      _ctrlNif.text.trim().isNotEmpty ||
      _ctrlRazonSocial.text.trim().isNotEmpty ||
      _ctrlDireccion.text.trim().isNotEmpty;

  bool get _nifValidoActual =>
      _ctrlNif.text.trim().isNotEmpty && validarNIF(_ctrlNif.text);

  String? get _mensajeAyudaNif {
    if (_errorValidacionNif != null) return _errorValidacionNif;
    if (_nifObligatorio && _ctrlNif.text.trim().isEmpty) {
      return _esEmpresaOProfesional
          ? 'NIF obligatorio para Empresa/Autónomo'
          : 'NIF obligatorio cuando el importe total es igual o superior a 400 €';
    }
    if (!_nifObligatorio && _ctrlNif.text.trim().isEmpty) {
      return 'NIF opcional para particulares con importe inferior a 400 €';
    }
    return null;
  }

  void _actualizarValidacionNif(String v) {
    setState(() {
      if (v.trim().isEmpty) {
        _errorValidacionNif = null;
      } else {
        final validacion = ValidadorNifCif.validar(v);
        _errorValidacionNif = validacion.valido ? null : validacion.razon;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _totales;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Factura' : 'Nueva Factura'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSeccion('👤 Datos del Cliente', [
              DropdownButtonFormField<TipoClienteFactura>(
                value: _tipoCliente,
                decoration: _inputDeco('Tipo de cliente'),
                items: const [
                  DropdownMenuItem(
                    value: TipoClienteFactura.particular,
                    child: Text('Particular'),
                  ),
                  DropdownMenuItem(
                    value: TipoClienteFactura.empresaAutonomo,
                    child: Text('Empresa/Autónomo'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _tipoCliente = v;
                    if (v == TipoClienteFactura.empresaAutonomo) {
                      _mostrarDatosFiscales = true;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              // Selector de cliente con creación rápida (Feature 7)
              ClienteSelectorRapido(
                empresaId: widget.empresaId,
                valorInicial: _ctrlClienteNombre.text,
                hint: 'Buscar o crear cliente...',
                onSeleccionado: (cliente) {
                  _ctrlClienteNombre.text = cliente.nombre;
                  if (cliente.telefono != null && _ctrlClienteTelefono.text.isEmpty) {
                    _ctrlClienteTelefono.text = cliente.telefono!;
                  }
                  if (cliente.correo != null && _ctrlClienteCorreo.text.isEmpty) {
                    _ctrlClienteCorreo.text = cliente.correo!;
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildCampo('Teléfono', _ctrlClienteTelefono,
                  tipo: TextInputType.phone),
              _buildCampo('Correo', _ctrlClienteCorreo,
                  tipo: TextInputType.emailAddress),
              if (!_nifObligatorio)
                SwitchListTile(
                  title: const Text('Añadir datos fiscales',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Opcional para particulares con importe inferior a 400 €',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _mostrarDatosFiscales,
                  onChanged: (v) => setState(() => _mostrarDatosFiscales = v),
                  activeThumbColor: const Color(0xFF0D47A1),
                  contentPadding: EdgeInsets.zero,
                ),
              if (_debeMostrarDatosFiscales) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _ctrlNif,
                    decoration: _inputDeco(
                      _nifObligatorio ? 'NIF/CIF/NIE *' : 'NIF/CIF/NIE',
                      hintText: '12345678Z o A12345678 o X1234567L',
                      errorText: _mensajeAyudaNif,
                      prefixIcon: _errorValidacionNif == null && _ctrlNif.text.isNotEmpty
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : null,
                    ),
                    onChanged: _actualizarValidacionNif,
                    validator: (_) => null,
                  ),
                ),
                if (!_nifObligatorio)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Aviso: si el destinatario es particular y el importe total es inferior a 400 €, el NIF puede omitirse legalmente.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                _buildCampo('Razón Social', _ctrlRazonSocial),
                _buildCampo('Dirección fiscal', _ctrlDireccion),
              ],
            ]),
            const SizedBox(height: 16),
            _buildSeccion('📋 Configuración', [
              DropdownButtonFormField<TipoFactura>(
                value: _tipoFactura,
                decoration: _inputDeco('Tipo de factura'),
                items: TipoFactura.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.etiqueta),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _tipoFactura = v!),
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
                onChanged: (v) => setState(() => _porcentajeIva = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MetodoPagoFactura?>(
                value: _metodoPago,
                decoration: _inputDeco('Método de pago (opcional)'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Pendiente de pago')),
                  ...MetodoPagoFactura.values.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.etiqueta),
                      )),
                ],
                onChanged: (v) => setState(() => _metodoPago = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlDiasVencimiento,
                decoration: _inputDeco('Días hasta vencimiento'),
                keyboardType: TextInputType.number,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSeccion('💰 Opciones Fiscales Avanzadas', [
              DropdownButtonFormField<double>(
                value: _descuentoGlobal,
                decoration: _inputDeco('Descuento global'),
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('Sin descuento')),
                  DropdownMenuItem(value: 5.0, child: Text('5%')),
                  DropdownMenuItem(value: 10.0, child: Text('10%')),
                  DropdownMenuItem(value: 15.0, child: Text('15%')),
                  DropdownMenuItem(value: 20.0, child: Text('20%')),
                  DropdownMenuItem(value: 25.0, child: Text('25%')),
                  DropdownMenuItem(value: 50.0, child: Text('50%')),
                ],
                onChanged: (v) => setState(() => _descuentoGlobal = v ?? 0),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                initialValue: _porcentajeIrpf,
                decoration: _inputDeco('Retención IRPF (freelancer)'),
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('Sin retención')),
                  DropdownMenuItem(value: 7.0, child: Text('7% (nuevos autónomos)')),
                  DropdownMenuItem(value: 15.0, child: Text('15% (estándar)')),
                  DropdownMenuItem(value: 19.0, child: Text('19% (profesional)')),
                ],
                onChanged: (v) => setState(() => _porcentajeIrpf = v ?? 0),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSeccionLineas(),
            const SizedBox(height: 16),
            _buildResumenTotales(t),
            const SizedBox(height: 16),
            _buildSeccion('📝 Notas', [
              _buildCampo('Notas internas (no visibles al cliente)',
                  _ctrlNotasInternas,
                  maxLines: 2),
              _buildCampo('Notas para el cliente', _ctrlNotasCliente,
                  maxLines: 2),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBotonGuardar(),
    );
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
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCampo(
    String label,
    TextEditingController ctrl, {
    bool validar = false,
    TextInputType tipo = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: tipo,
        maxLines: maxLines,
        decoration: _inputDeco(label),
        validator: validar
            ? (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null
            : null,
      ),
    );
  }

  InputDecoration _inputDeco(
    String label, {
    String? hintText,
    String? errorText,
    Widget? prefixIcon,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _buildSeccionLineas() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🛒 Líneas de Factura',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _agregarLinea,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Añadir', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1)),
                ),
              ],
            ),
            if (_lineas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Sin líneas. Pulsa "Añadir" para agregar productos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._lineas.asMap().entries.map((e) => _buildLinea(e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildLinea(int i, LineaFactura linea) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(linea.descripcion,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${linea.cantidad} × ${linea.precioUnitario.toStringAsFixed(2)}€'
                  '  (IVA ${linea.porcentajeIva.toInt()}%)'
                  '${linea.descuento > 0 ? '  -${linea.descuento.toInt()}% dto' : ''}'
                  '${linea.recargoEquivalencia > 0 ? '  +${linea.recargoEquivalencia}% RE' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${linea.subtotalConIva.toStringAsFixed(2)}€',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: () => setState(() => _lineas.removeAt(i)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTotales(Map<String, double> t) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF0D47A1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFilaTotal('Base imponible', t['subtotal'] ?? 0, Colors.white70),
            if (_descuentoGlobal > 0)
              _buildFilaTotal('Descuento global (${_descuentoGlobal.toInt()}%)',
                  -(t['importe_descuento_global'] ?? 0), Colors.orangeAccent),
            _buildFilaTotal('IVA', t['total_iva'] ?? 0, Colors.white70),
            if ((t['total_recargo_equivalencia'] ?? 0) > 0)
              _buildFilaTotal('Recargo equiv.', t['total_recargo_equivalencia']!, Colors.white70),
            if (_porcentajeIrpf > 0)
              _buildFilaTotal('Retención IRPF (${_porcentajeIrpf.toInt()}%)',
                  -(t['retencion_irpf'] ?? 0), Colors.orangeAccent),
            const Divider(color: Colors.white30, height: 20),
            _buildFilaTotal('TOTAL', t['total'] ?? 0, Colors.white, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaTotal(String label, double valor, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 13)),
          Text('${valor.toStringAsFixed(2)}€',
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 18 : 13)),
        ],
      ),
    );
  }

  Widget _buildBotonGuardar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: ElevatedButton.icon(
        onPressed: _guardando ? null : _guardar,
        icon: _guardando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save),
        label: Text(_guardando
            ? 'Guardando...'
            : _esEdicion ? 'Actualizar Factura' : 'Guardar Factura'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── AGREGAR LÍNEA ──────────────────────────────────────────────────────────

  void _agregarLinea() async {
    final linea = await showDialog<LineaFactura>(
      context: context,
      builder: (ctx) => _DialogLineaFactura(ivaDefault: _porcentajeIva),
    );
    if (linea != null) {
      setState(() => _lineas.add(linea));
    }
  }

  // ── GUARDAR / EDITAR ──────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Añade al menos una línea a la factura'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nifIntroducido = _ctrlNif.text.trim();
    final hayNifValido = nifIntroducido.isNotEmpty && validarNIF(nifIntroducido);

    // Validar NIF/CIF en tiempo real si se ha introducido
    if (_debeMostrarDatosFiscales && nifIntroducido.isNotEmpty) {
      final validacionNif = ValidadorNifCif.validar(_ctrlNif.text);
      if (!validacionNif.valido) {
        _actualizarValidacionNif(_ctrlNif.text);
      }
    }

    if (_nifObligatorio && !hayNifValido) {
      final continuar = await _mostrarDialogoAdvertenciaFiscal();
      if (continuar != true) return;
    }

    setState(() => _guardando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      final nombre = user?.displayName ?? 'Usuario';

      DatosFiscales? datosFiscales;
      if (_debeMostrarDatosFiscales) {
        final nifNormalizado = hayNifValido
            ? ValidadorNifCif.limpiar(_ctrlNif.text)
            : null;
        datosFiscales = DatosFiscales(
          nif: nifNormalizado,
          razonSocial: _ctrlRazonSocial.text.isEmpty ? null : _ctrlRazonSocial.text,
          direccion: _ctrlDireccion.text.isEmpty ? null : _ctrlDireccion.text,
        );

        if ((datosFiscales.nif == null) &&
            (datosFiscales.razonSocial == null) &&
            (datosFiscales.direccion == null)) {
          datosFiscales = null;
        }
      }

      final diasVenc = int.tryParse(_ctrlDiasVencimiento.text) ?? 30;

      if (_esEdicion) {
        await _service.editarFactura(
          empresaId: widget.empresaId,
          facturaId: widget.facturaExistente!.id,
          clienteNombre: _ctrlClienteNombre.text,
          clienteTelefono: _ctrlClienteTelefono.text.isEmpty
              ? null : _ctrlClienteTelefono.text,
          clienteCorreo: _ctrlClienteCorreo.text.isEmpty
              ? null : _ctrlClienteCorreo.text,
          datosFiscales: datosFiscales,
          lineas: _lineas,
          metodoPago: _metodoPago,
          notasInternas: _ctrlNotasInternas.text.isEmpty
              ? null : _ctrlNotasInternas.text,
          notasCliente: _ctrlNotasCliente.text.isEmpty
              ? null : _ctrlNotasCliente.text,
          diasVencimiento: diasVenc,
          descuentoGlobal: _descuentoGlobal,
          porcentajeIrpf: _porcentajeIrpf,
          usuarioId: uid,
          usuarioNombre: nombre,
        );
      } else {
        final resultado = await _service.crearFactura(
          empresaId: widget.empresaId,
          clienteNombre: _ctrlClienteNombre.text,
          clienteTelefono: _ctrlClienteTelefono.text.isEmpty
              ? null : _ctrlClienteTelefono.text,
          clienteCorreo: _ctrlClienteCorreo.text.isEmpty
              ? null : _ctrlClienteCorreo.text,
          datosFiscales: datosFiscales,
          lineas: _lineas,
          metodoPago: _metodoPago,
          pedidoId: widget.pedidoId,
          tipo: _tipoFactura,
          notasInternas: _ctrlNotasInternas.text.isEmpty
              ? null : _ctrlNotasInternas.text,
          notasCliente: _ctrlNotasCliente.text.isEmpty
              ? null : _ctrlNotasCliente.text,
          diasVencimiento: diasVenc,
          descuentoGlobal: _descuentoGlobal,
          porcentajeIrpf: _porcentajeIrpf,
          usuarioId: uid,
          usuarioNombre: nombre,
        );

        // Mostrar feedback de VeriFactu si aplica
        if (mounted && (resultado.verifactuOk || resultado.verifactuError)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado.mensajeVerifactu),
              backgroundColor: resultado.verifactuOk
                  ? const Color(0xFF2196F3)
                  : Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion
                ? '✅ Factura actualizada correctamente'
                : '✅ Factura creada correctamente'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool?> _mostrarDialogoAdvertenciaFiscal() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advertencia fiscal'),
        content: const Text(
          'Esta factura no será válida fiscalmente ni podrá incluirse en el Mod. 347. ¿Deseas continuar de todos modos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            child: const Text('Continuar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── DIÁLOGO AÑADIR LÍNEA ──────────────────────────────────────────────────────

class _DialogLineaFactura extends StatefulWidget {
  final double ivaDefault;
  const _DialogLineaFactura({required this.ivaDefault});

  @override
  State<_DialogLineaFactura> createState() => _DialogLineaFacturaState();
}

class _DialogLineaFacturaState extends State<_DialogLineaFactura> {
  final _ctrlDesc = TextEditingController();
  final _ctrlPrecio = TextEditingController();
  final _ctrlCantidad = TextEditingController(text: '1');
  final _ctrlDescuento = TextEditingController(text: '0');
  late double _iva;
  double _recargoEquivalencia = 0;

  @override
  void initState() {
    super.initState();
    _iva = widget.ivaDefault;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir línea'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrlDesc,
              decoration: const InputDecoration(labelText: 'Descripción *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrlPrecio,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio unitario (€) *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrlCantidad,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrlDescuento,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Descuento línea (%)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<double>(
              initialValue: _iva,
              decoration: const InputDecoration(labelText: 'IVA %'),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('0%')),
                DropdownMenuItem(value: 4.0, child: Text('4%')),
                DropdownMenuItem(value: 10.0, child: Text('10%')),
                DropdownMenuItem(value: 21.0, child: Text('21%')),
              ],
              onChanged: (v) => setState(() => _iva = v!),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<double>(
              initialValue: _recargoEquivalencia,
              decoration: const InputDecoration(labelText: 'Recargo equivalencia'),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('Sin recargo')),
                DropdownMenuItem(value: 0.5, child: Text('0.5% (IVA 4%)')),
                DropdownMenuItem(value: 1.4, child: Text('1.4% (IVA 10%)')),
                DropdownMenuItem(value: 5.2, child: Text('5.2% (IVA 21%)')),
              ],
              onChanged: (v) => setState(() => _recargoEquivalencia = v ?? 0),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _confirmar,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1)),
          child:
              const Text('Añadir', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _confirmar() {
    final desc = _ctrlDesc.text.trim();
    final precio = double.tryParse(_ctrlPrecio.text.replaceAll(',', '.'));
    final cantidad = int.tryParse(_ctrlCantidad.text) ?? 1;
    final descuento = double.tryParse(_ctrlDescuento.text.replaceAll(',', '.')) ?? 0;

    if (desc.isEmpty || precio == null) return;

    Navigator.pop(
      context,
      LineaFactura(
        descripcion: desc,
        precioUnitario: precio,
        cantidad: cantidad,
        porcentajeIva: _iva,
        descuento: descuento,
        recargoEquivalencia: _recargoEquivalencia,
      ),
    );
  }
}

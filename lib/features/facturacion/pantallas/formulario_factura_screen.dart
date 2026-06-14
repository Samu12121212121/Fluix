import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/services/pdf_service.dart';
import 'package:planeag_flutter/services/email_service.dart';
import 'package:planeag_flutter/core/utils/validador_nif_cif.dart';
import 'package:planeag_flutter/widgets/cliente_selector_rapido.dart';
import 'formulario_linea_factura_sheet.dart';

const _kPrimario = Color(0xFF0D47A1);
const _kFondo = Color(0xFFF5F7FA);

enum TipoClienteFactura { particular, empresaAutonomo }

class FormularioFacturaScreen extends StatefulWidget {
  final String empresaId;
  final String? pedidoId;
  final String? clienteNombreInicial;
  final List<Map<String, dynamic>>? lineasIniciales;
  final Factura? facturaExistente;

  const FormularioFacturaScreen({
    super.key,
    required this.empresaId,
    this.pedidoId,
    this.clienteNombreInicial,
    this.lineasIniciales,
    this.facturaExistente,
  });

  @override
  State<FormularioFacturaScreen> createState() => _FormularioFacturaScreenState();
}

class _FormularioFacturaScreenState extends State<FormularioFacturaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FacturacionService();
  final _firestore = FirebaseFirestore.instance;
  bool _guardando = false;
  bool get _esEdicion => widget.facturaExistente != null;

  // Cliente
  final _ctrlNombre = TextEditingController();
  final _ctrlTelefono = TextEditingController();
  final _ctrlCorreo = TextEditingController();
  final _ctrlNif = TextEditingController();
  final _ctrlRazonSocial = TextEditingController();
  final _ctrlDireccion = TextEditingController();
  TipoClienteFactura _tipoCliente = TipoClienteFactura.particular;
  bool _mostrarDatosFiscales = false;
  String? _errorNif;

  // Configuración
  TipoFactura _tipoFactura = TipoFactura.venta_directa;
  MetodoPagoFactura? _metodoPago;
  double _porcentajeIva = 21.0;
  final _ctrlDiasVenc = TextEditingController(text: '30');
  DateTime? _fechaOperacion;

  // Fiscal avanzado
  double _descuentoGlobal = 0;
  double _porcentajeIrpf = 0;

  // Líneas y notas
  final List<LineaFactura> _lineas = [];
  final _ctrlNotasInternas = TextEditingController();
  final _ctrlNotasCliente = TextEditingController();

  // Sector
  bool _esConstruccion = false;
  bool _esHosteleria = false;
  bool _esComercio = false;

  @override
  void initState() {
    super.initState();
    if (widget.facturaExistente != null) {
      _precargar(widget.facturaExistente!);
    } else {
      if (widget.clienteNombreInicial != null) _ctrlNombre.text = widget.clienteNombreInicial!;
      if (widget.pedidoId != null) _tipoFactura = TipoFactura.pedido;
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
    _cargarSector();
  }

  @override
  void dispose() {
    for (final c in [_ctrlNombre, _ctrlTelefono, _ctrlCorreo, _ctrlNif, _ctrlRazonSocial, _ctrlDireccion, _ctrlDiasVenc, _ctrlNotasInternas, _ctrlNotasCliente]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarSector() async {
    try {
      final data = (await _firestore.collection('empresas').doc(widget.empresaId).get()).data() ?? {};
      final s = (data['sector'] as String? ?? '').toLowerCase();
      final t = (data['tipo_negocio'] as String? ?? '').toLowerCase();
      if (!mounted) return;
      setState(() {
        _esConstruccion = s.contains('construcci') || t.contains('construcci') || t.contains('obra');
        _esHosteleria = s.contains('hostel') || s.contains('restaura') || s.contains('bar') || t.contains('hostel');
        _esComercio = s.contains('comerci') || t.contains('tienda') || t.contains('bazar');
        if (!_esEdicion) _porcentajeIva = _esHosteleria ? 10.0 : 21.0;
      });
    } catch (_) {}
  }

  void _precargar(Factura f) {
    _ctrlNombre.text = f.clienteNombre;
    _ctrlTelefono.text = f.clienteTelefono ?? '';
    _ctrlCorreo.text = f.clienteCorreo ?? '';
    _tipoFactura = f.tipo;
    _metodoPago = f.metodoPago;
    _ctrlDiasVenc.text = f.diasVencimiento.toString();
    _descuentoGlobal = f.descuentoGlobal;
    _porcentajeIrpf = f.porcentajeIrpf;
    _ctrlNotasInternas.text = f.notasInternas ?? '';
    _ctrlNotasCliente.text = f.notasCliente ?? '';
    _fechaOperacion = f.fechaOperacion;
    _lineas.addAll(f.lineas);
    if (f.lineas.isNotEmpty) _porcentajeIva = f.lineas.first.porcentajeIva;
    _tipoCliente = (f.datosFiscales?.razonSocial?.trim().isNotEmpty ?? false)
        ? TipoClienteFactura.empresaAutonomo
        : TipoClienteFactura.particular;
    if (f.datosFiscales?.tieneDatos == true) {
      _mostrarDatosFiscales = true;
      _ctrlNif.text = f.datosFiscales?.nif ?? '';
      _ctrlRazonSocial.text = f.datosFiscales?.razonSocial ?? '';
      _ctrlDireccion.text = f.datosFiscales?.direccion ?? '';
    }
  }

  Map<String, double> get _t => Factura.calcularTotales(lineas: _lineas, descuentoGlobal: _descuentoGlobal, porcentajeIrpf: _porcentajeIrpf);
  bool get _esEmpresa => _tipoCliente == TipoClienteFactura.empresaAutonomo;
  bool get _nifObligatorio => _esEmpresa || (_t['total'] ?? 0) >= 400;
  bool get _nifEstricto => _esEmpresa || _ctrlRazonSocial.text.trim().isNotEmpty;
  bool get _mostrarFiscales => _mostrarDatosFiscales || _esEmpresa || _nifObligatorio || _ctrlNif.text.trim().isNotEmpty;
  bool get _nifValido => _ctrlNif.text.trim().isNotEmpty && validarNIF(_ctrlNif.text);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: _kFondo,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Factura' : 'Nueva Factura', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _seccion(1, 'Cliente', Icons.person_outline, _buildCliente()),
            _seccion(2, 'Configuración de factura', Icons.receipt_outlined, _buildConfiguracion()),
            _seccion(3, 'Descuentos y retenciones', Icons.percent, _buildFiscal()),
            _seccion(4, 'Líneas', Icons.list_alt_outlined, _buildLineas()),
            _seccion(5, 'Notas', Icons.notes_outlined, _buildNotas()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(t),
    );
  }

  // ── SECCIONES ─────────────────────────────────────────────────────────────

  List<Widget> _buildCliente() => [
    SegmentedButton<TipoClienteFactura>(
      segments: const [
        ButtonSegment(value: TipoClienteFactura.particular, label: Text('Particular'), icon: Icon(Icons.person, size: 16)),
        ButtonSegment(value: TipoClienteFactura.empresaAutonomo, label: Text('Empresa / Autónomo'), icon: Icon(Icons.business, size: 16)),
      ],
      selected: {_tipoCliente},
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: _kPrimario,
        selectedForegroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 12),
      ),
      onSelectionChanged: (v) => setState(() {
        _tipoCliente = v.first;
        if (_tipoCliente == TipoClienteFactura.empresaAutonomo) _mostrarDatosFiscales = true;
      }),
    ),
    const SizedBox(height: 12),
    ClienteSelectorRapido(
      empresaId: widget.empresaId,
      valorInicial: _ctrlNombre.text,
      hint: 'Buscar o crear cliente...',
      onSeleccionado: (c) {
        setState(() {
          _ctrlNombre.text = c.nombre;
          if (c.telefono != null && _ctrlTelefono.text.isEmpty) _ctrlTelefono.text = c.telefono!;
          if (c.correo != null && _ctrlCorreo.text.isEmpty) _ctrlCorreo.text = c.correo!;
        });
      },
    ),
    const SizedBox(height: 10),
    _campo('Teléfono', _ctrlTelefono, tipo: TextInputType.phone),
    _campo('Correo electrónico', _ctrlCorreo, tipo: TextInputType.emailAddress),
    if (!_nifObligatorio)
      SwitchListTile(
        dense: true, contentPadding: EdgeInsets.zero,
        title: const Text('Añadir datos fiscales', style: TextStyle(fontSize: 13)),
        subtitle: const Text('Opcional para particulares < 400 €', style: TextStyle(fontSize: 11)),
        value: _mostrarDatosFiscales,
        onChanged: (v) => setState(() => _mostrarDatosFiscales = v),
        activeColor: _kPrimario,
      ),
    if (_mostrarFiscales) ..._buildFiscalesCliente(),
  ];

  List<Widget> _buildFiscalesCliente() => [
    const SizedBox(height: 4),
    TextFormField(
      controller: _ctrlNif,
      decoration: _deco(
        _nifObligatorio ? 'NIF / CIF / NIE *' : 'NIF / CIF / NIE',
        hint: '12345678Z · A12345678 · X1234567L',
        error: _errorNif,
        prefijo: _ctrlNif.text.isNotEmpty && _errorNif == null
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : null,
      ),
      onChanged: (v) {
        setState(() => _errorNif = v.trim().isEmpty ? null : (ValidadorNifCif.validar(v).valido ? null : ValidadorNifCif.validar(v).razon));
      },
    ),
    const SizedBox(height: 10),
    _campo('Razón social', _ctrlRazonSocial),
    _campo('Dirección fiscal completa', _ctrlDireccion),
  ];

  List<Widget> _buildConfiguracion() => [
    DropdownButtonFormField<TipoFactura>(
      value: _tipoFactura,
      decoration: _deco('Tipo de factura'),
      items: TipoFactura.values.map((t) => DropdownMenuItem(value: t, child: Text(t.etiqueta))).toList(),
      onChanged: (v) => setState(() => _tipoFactura = v!),
    ),
    const SizedBox(height: 12),
    _buildIvaGlobal(),
    const SizedBox(height: 12),
    if (_esHosteleria) _aviso('Hostelería: comidas/bebidas sin alcohol → 10%  ·  Bebidas alcohólicas → 21%'),
    if (_esComercio) _aviso('Comercio: ajusta el IVA por cada línea (4% / 10% / 21%)'),
    InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _fechaOperacion ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2100),
          helpText: 'Fecha de realización de la operación',
        );
        if (d != null) setState(() => _fechaOperacion = d);
      },
      child: InputDecorator(
        decoration: _deco('Fecha de operación', hint: 'Solo si difiere de la fecha de emisión'),
        child: Row(children: [
          Expanded(child: Text(
            _fechaOperacion != null
                ? '${_fechaOperacion!.day.toString().padLeft(2, '0')}/${_fechaOperacion!.month.toString().padLeft(2, '0')}/${_fechaOperacion!.year}'
                : 'Igual que la fecha de emisión',
            style: TextStyle(color: _fechaOperacion != null ? Colors.black87 : Colors.grey[500]),
          )),
          if (_fechaOperacion != null)
            GestureDetector(onTap: () => setState(() => _fechaOperacion = null), child: const Icon(Icons.close, size: 16, color: Colors.grey))
          else
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
        ]),
      ),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<MetodoPagoFactura?>(
      value: _metodoPago,
      decoration: _deco('Método de pago'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Pendiente de pago')),
        ...MetodoPagoFactura.values.map((m) => DropdownMenuItem(value: m, child: Text(m.etiqueta))),
      ],
      onChanged: (v) => setState(() => _metodoPago = v),
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _ctrlDiasVenc,
      decoration: _deco('Días hasta vencimiento'),
      keyboardType: TextInputType.number,
    ),
  ];

  Widget _buildIvaGlobal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('IVA por defecto en nuevas líneas', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            (0.0, '0% — Exento'),
            (4.0, '4%'),
            (10.0, '10%'),
            (21.0, '21%'),
          ].map((item) {
            final sel = _porcentajeIva == item.$1;
            return GestureDetector(
              onTap: () => setState(() => _porcentajeIva = item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _kPrimario : Colors.grey[100],
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: sel ? _kPrimario : Colors.grey[300]!),
                ),
                child: Text(item.$2, style: TextStyle(color: sel ? Colors.white : Colors.grey[700], fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildFiscal() => [
    DropdownButtonFormField<double>(
      value: _descuentoGlobal,
      decoration: _deco('Descuento global sobre la factura'),
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
      decoration: _deco('Retención IRPF (autónomos / profesionales)'),
      items: const [
        DropdownMenuItem(value: 0.0, child: Text('Sin retención')),
        DropdownMenuItem(value: 7.0, child: Text('7% — Nuevos autónomos')),
        DropdownMenuItem(value: 15.0, child: Text('15% — Estándar')),
        DropdownMenuItem(value: 19.0, child: Text('19% — Profesional')),
      ],
      onChanged: (v) => setState(() => _porcentajeIrpf = v ?? 0),
    ),
  ];

  List<Widget> _buildLineas() => [
    if (_lineas.isEmpty)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Column(children: [
          Icon(Icons.add_shopping_cart_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text('Sin líneas todavía', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 4),
          Text('Pulsa el botón para añadir productos o servicios', style: TextStyle(color: Colors.grey[400], fontSize: 12), textAlign: TextAlign.center),
        ]),
      )
    else
      ...List.generate(_lineas.length, (i) => _buildItemLinea(i, _lineas[i])),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: _agregarLinea,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Añadir línea'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kPrimario,
        side: const BorderSide(color: _kPrimario),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(double.infinity, 44),
      ),
    ),
  ];

  Widget _buildItemLinea(int i, LineaFactura l) {
    final ivaColor = l.porcentajeIva == 21 ? const Color(0xFF1565C0) : l.porcentajeIva == 10 ? const Color(0xFF2E7D32) : l.porcentajeIva == 4 ? const Color(0xFFEF6C00) : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editarLinea(i),
        child: Row(children: [
          Container(
            width: 5, height: 80,
            decoration: BoxDecoration(color: ivaColor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12))),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(l.descripcion, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${l.subtotalConIva.toStringAsFixed(2)}€', style: const TextStyle(fontWeight: FontWeight.bold, color: _kPrimario, fontSize: 14)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${l.cantidad}${l.unidad.isNotEmpty ? " ${l.unidad}" : ""} × ${l.precioUnitario.toStringAsFixed(2)}€', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(width: 8),
                  _badge('IVA ${l.porcentajeIva.toInt()}%', ivaColor),
                  if (l.descuento > 0) ...[const SizedBox(width: 4), _badge('-${l.descuento.toInt()}%', Colors.orange)],
                ]),
                if (l.referencia != null && l.referencia!.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text('Ref: ${l.referencia}', style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
              ]),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: _kPrimario), onPressed: () => _editarLinea(i), visualDensity: VisualDensity.compact),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => setState(() => _lineas.removeAt(i)), visualDensity: VisualDensity.compact),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _buildNotas() => [
    _campo('Notas internas (no visibles al cliente)', _ctrlNotasInternas, maxLines: 2),
    _campo('Notas para el cliente', _ctrlNotasCliente, maxLines: 2),
  ];

  // ── BOTTOM BAR CON TOTALES + GUARDAR ─────────────────────────────────────

  Widget _buildBottomBar(Map<String, double> t) {
    final total = t['total'] ?? 0;
    final base = t['subtotal'] ?? 0;
    final iva = t['total_iva'] ?? 0;
    final irpf = t['retencion_irpf'] ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            _miniTotal('Base', base),
            const SizedBox(width: 16),
            _miniTotal('IVA', iva),
            if (_porcentajeIrpf > 0) ...[
              const SizedBox(width: 16),
              _miniTotal('IRPF', -irpf, color: Colors.orange[700]),
            ],
            const Spacer(),
            Text(
              '${total.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kPrimario),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimario, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _guardando
                  ? const Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Guardando...'),
                    ])
                  : Text(_esEdicion ? 'Actualizar Factura' : 'Guardar Factura',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTotal(String label, double valor, {Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      Text('${valor.toStringAsFixed(2)}€', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? Colors.grey[800])),
    ],
  );

  // ── ACCIONES ──────────────────────────────────────────────────────────────

  Future<void> _agregarLinea() async {
    final linea = await mostrarLineaSheet(context, ivaDefault: _porcentajeIva, esComercio: _esComercio);
    if (linea != null) setState(() => _lineas.add(linea));
  }

  Future<void> _editarLinea(int i) async {
    final linea = await mostrarLineaSheet(context, ivaDefault: _porcentajeIva, esComercio: _esComercio, editar: _lineas[i]);
    if (linea != null) setState(() => _lineas[i] = linea);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Añade al menos una línea'), backgroundColor: Colors.orange));
      return;
    }
    final nifTexto = _ctrlNif.text.trim();
    final hayNifValido = nifTexto.isNotEmpty && validarNIF(nifTexto);
    if (_nifEstricto && !hayNifValido) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NIF/CIF obligatorio para empresas y autónomos'), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
      return;
    }
    if (_nifObligatorio && !_nifEstricto && !hayNifValido) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Advertencia fiscal'),
          content: const Text('Esta factura no tendrá validez fiscal ni podrá incluirse en el Mod. 347. ¿Continuar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _kPrimario), child: const Text('Continuar', style: TextStyle(color: Colors.white))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _guardando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      final nombre = user?.displayName ?? 'Usuario';
      DatosFiscales? fiscales;
      if (_mostrarFiscales) {
        final nif = hayNifValido ? ValidadorNifCif.limpiar(nifTexto) : null;
        fiscales = DatosFiscales(
          nif: nif,
          razonSocial: _ctrlRazonSocial.text.trim().isEmpty ? null : _ctrlRazonSocial.text.trim(),
          direccion: _ctrlDireccion.text.trim().isEmpty ? null : _ctrlDireccion.text.trim(),
        );
        if (!fiscales.tieneDatos) fiscales = null;
      }
      final dias = int.tryParse(_ctrlDiasVenc.text) ?? 30;
      if (_esEdicion) {
        await _service.editarFactura(
          empresaId: widget.empresaId, facturaId: widget.facturaExistente!.id,
          clienteNombre: _ctrlNombre.text, clienteTelefono: _ctrlTelefono.text.trim().isEmpty ? null : _ctrlTelefono.text,
          clienteCorreo: _ctrlCorreo.text.trim().isEmpty ? null : _ctrlCorreo.text,
          datosFiscales: fiscales, lineas: _lineas, metodoPago: _metodoPago,
          notasInternas: _ctrlNotasInternas.text.trim().isEmpty ? null : _ctrlNotasInternas.text,
          notasCliente: _ctrlNotasCliente.text.trim().isEmpty ? null : _ctrlNotasCliente.text,
          fechaOperacion: _fechaOperacion, diasVencimiento: dias,
          descuentoGlobal: _descuentoGlobal, porcentajeIrpf: _porcentajeIrpf,
          usuarioId: uid, usuarioNombre: nombre,
        );
      } else {
        final res = await _service.crearFactura(
          empresaId: widget.empresaId, clienteNombre: _ctrlNombre.text,
          clienteTelefono: _ctrlTelefono.text.trim().isEmpty ? null : _ctrlTelefono.text,
          clienteCorreo: _ctrlCorreo.text.trim().isEmpty ? null : _ctrlCorreo.text,
          datosFiscales: fiscales, lineas: _lineas, metodoPago: _metodoPago,
          pedidoId: widget.pedidoId, tipo: _tipoFactura,
          notasInternas: _ctrlNotasInternas.text.trim().isEmpty ? null : _ctrlNotasInternas.text,
          notasCliente: _ctrlNotasCliente.text.trim().isEmpty ? null : _ctrlNotasCliente.text,
          fechaOperacion: _fechaOperacion, diasVencimiento: dias,
          descuentoGlobal: _descuentoGlobal, porcentajeIrpf: _porcentajeIrpf,
          usuarioId: uid, usuarioNombre: nombre,
        );
        if (mounted && (res.verifactuOk || res.verifactuError)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res.mensajeVerifactu),
            backgroundColor: res.verifactuOk ? const Color(0xFF2196F3) : Colors.orange,
            duration: const Duration(seconds: 4),
          ));
        }
      }
      if (mounted) {
        if (_esEdicion) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Factura actualizada'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        } else {
          await _mostrarOpcionesPostGuardado(res.factura);
        }
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _mostrarOpcionesPostGuardado(Factura f) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostGuardadoSheet(factura: f, empresaId: widget.empresaId),
    );
    if (mounted) Navigator.pop(context, true);
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _seccion(int n, String titulo, IconData icono, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(color: _kPrimario, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Icon(icono, size: 15, color: _kPrimario),
          const SizedBox(width: 6),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    ),
  );

  Widget _campo(String label, TextEditingController ctrl, {TextInputType tipo = TextInputType.text, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(controller: ctrl, keyboardType: tipo, maxLines: maxLines, decoration: _deco(label)),
      );

  Widget _aviso(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFCC02))),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 14, color: Color(0xFFF57F17)),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 11, color: Color(0xFFF57F17)))),
      ]),
    ),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  InputDecoration _deco(String label, {String? hint, String? error, Widget? prefijo}) => InputDecoration(
    labelText: label, hintText: hint, errorText: error, prefixIcon: prefijo,
    filled: true, fillColor: _kFondo,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kPrimario)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

// ── SHEET POST-GUARDADO ────────────────────────────────────────────────────────

class _PostGuardadoSheet extends StatefulWidget {
  final Factura factura;
  final String empresaId;

  const _PostGuardadoSheet({required this.factura, required this.empresaId});

  @override
  State<_PostGuardadoSheet> createState() => _PostGuardadoSheetState();
}

class _PostGuardadoSheetState extends State<_PostGuardadoSheet> {
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.factura;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Icono de éxito
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
          ),
          const SizedBox(height: 12),
          Text(f.numeroFactura, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '${f.total.toStringAsFixed(2)} € · ${f.clienteNombre.isEmpty ? "Cliente general" : f.clienteNombre}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(color: _kPrimario),
            )
          else ...[
            _botonAccion(
              icon: Icons.picture_as_pdf,
              label: 'Ver PDF',
              color: _kPrimario,
              onTap: () => PdfService.verFacturaPdf(context, f, widget.empresaId),
            ),
            const SizedBox(height: 10),
            _botonAccion(
              icon: Icons.share_outlined,
              label: 'Compartir (WhatsApp, Drive…)',
              color: const Color(0xFF25D366),
              onTap: () => _compartir(f),
            ),
            const SizedBox(height: 10),
            _botonAccion(
              icon: Icons.email_outlined,
              label: f.clienteCorreo?.isNotEmpty == true
                  ? 'Enviar por email a ${f.clienteCorreo}'
                  : 'Enviar por email',
              color: Colors.orange,
              onTap: () => _enviarEmail(f),
            ),
            if (f.clienteTelefono != null) ...[
              const SizedBox(height: 10),
              _botonAccion(
                icon: Icons.chat_outlined,
                label: 'WhatsApp a ${f.clienteTelefono}',
                color: const Color(0xFF25D366),
                onTap: () => _whatsapp(f),
              ),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo', style: TextStyle(color: Colors.grey, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonAccion({required IconData icon, required String label, required Color color, required VoidCallback onTap}) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 13), overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          minimumSize: const Size(double.infinity, 46),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      );

  Future<void> _compartir(Factura f) async {
    setState(() => _cargando = true);
    try {
      final bytes = await PdfService.generarFacturaPdfConDatos(f, widget.empresaId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Factura_${f.numeroFactura.replaceAll('/', '_')}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Factura ${f.numeroFactura}',
        text: 'Factura ${f.numeroFactura} · ${f.total.toStringAsFixed(2)}€',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _enviarEmail(Factura f) async {
    setState(() => _cargando = true);
    try {
      final bytes = await PdfService.generarFacturaPdfConDatos(f, widget.empresaId);
      final correo = f.clienteCorreo ?? '';
      if (correo.isNotEmpty) {
        await EmailService.enviarFactura(
          destinatario: correo,
          pdfBytes: bytes,
          numeroFactura: f.numeroFactura,
          total: f.total,
          empresaId: widget.empresaId,
          nombreCliente: f.clienteNombre,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email enviado'), backgroundColor: Colors.green));
      } else {
        // Sin correo: fallback a compartir
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Factura_${f.numeroFactura.replaceAll('/', '_')}.pdf');
        await file.writeAsBytes(bytes);
        if (mounted) {
          await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], subject: 'Factura ${f.numeroFactura}');
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _whatsapp(Factura f) async {
    final tel = f.clienteTelefono!.replaceAll(RegExp(r'[^0-9+]'), '');
    final texto = 'Hola, te envío la factura ${f.numeroFactura} por ${f.total.toStringAsFixed(2)}€.';
    final uri = Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent(texto)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    // También compartir el PDF por separado
    await _compartir(f);
  }
}


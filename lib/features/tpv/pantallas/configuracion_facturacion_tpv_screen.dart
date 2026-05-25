import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../domain/modelos/configuracion_facturacion_tpv.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import '../../../services/demo_cuenta_service.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'importar_catalogo_csv_screen.dart';

class ConfiguracionFacturacionTpvScreen extends StatefulWidget {
  final String empresaId;
  final bool esPropietario;
  
  const ConfiguracionFacturacionTpvScreen({
    super.key, 
    required this.empresaId,
    this.esPropietario = false,
  });

  @override
  State<ConfiguracionFacturacionTpvScreen> createState() =>
      _ConfiguracionFacturacionTpvScreenState();
}

class _ConfiguracionFacturacionTpvScreenState
    extends State<ConfiguracionFacturacionTpvScreen> {
  final TpvFacturacionService _svc = TpvFacturacionService();
  ConfiguracionFacturacionTpv _config = const ConfiguracionFacturacionTpv();
  bool _cargando = true;
  bool _guardando = false;
  String _tipoTpv = 'bar';
  
  // Estado Bluetooth
  bool _btConectada = false;
  String? _nombreImpresora;
  
  // Control de visualización
  bool _esDemo = false;
  bool get _puedeEditarTipoNegocio => widget.esPropietario || _esDemo;

  @override
  void initState() {
    super.initState();
    _cargar();
    _verificarBluetooth();
    _verificarDemo();
  }

  Future<void> _verificarDemo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _esDemo = DemoCuentaService().esDemo(user.email));
    }
  }

  Future<void> _verificarBluetooth() async {
    final conectada = await ImpressoraBluetooth().estaConectada();
    final ultima = await ImpressoraBluetooth().obtenerUltimaGuardada();
    if (mounted) {
      setState(() {
        _btConectada = conectada;
        _nombreImpresora = ultima?['name'];
      });
    }
  }

  Future<void> _cargar() async {
    final config = await _svc.obtenerConfig(widget.empresaId);
    // Leer tipoTpv del documento principal de la empresa
    final empresaSnap = await FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId).get();
    final tipoTpv = empresaSnap.data()?['tipo_tpv'] as String? ?? 'bar';
    setState(() { _config = config; _tipoTpv = tipoTpv; _cargando = false; });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _svc.guardarConfig(widget.empresaId, _config);
      // Guardar tipoTpv en el documento principal de la empresa
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .update({'tipo_tpv': _tipoTpv});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Configuración guardada'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Facturación TPV', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Solo mostrar tipo de TPV para propietario o demo
                    if (_puedeEditarTipoNegocio) ...[
                      _seccionTipoTpv(),
                      const SizedBox(height: 20),
                    ],
                    _seccionModo(),
                  const SizedBox(height: 20),
                  if (_config.modo == ModoFacturacionTpv.resumenDiario) ...[
                    _seccionResumenDiario(),
                    const SizedBox(height: 20),
                  ],
                  if (_config.modo == ModoFacturacionTpv.porVenta) ...[
                    _seccionPorVenta(),
                    const SizedBox(height: 20),
                  ],
                  _seccionMetodosPago(),
                  const SizedBox(height: 20),
                  _seccionSerie(),
                  const SizedBox(height: 20),
                  _seccionOpciones(),
                  const SizedBox(height: 20),
                  _seccionBluetooth(),
                  const SizedBox(height: 20),
                  _seccionImportarCatalogo(),
                  const SizedBox(height: 20),
                  _seccionImagenesProductos(),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_guardando ? 'Guardando…' : '💾 GUARDAR CONFIGURACIÓN'),
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF1565C0))),
  );

  Widget _card(Widget child) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  // ── TIPO DE TPV ─────────────────────────────────────────────────────────────

  static const _tiposTpv = [
    ('bar', '🍺', 'Bar / Restaurante', 'Mesas, comandas, carta'), 
    ('peluqueria_estetica', '✂️', 'Peluquería / Estética', 'Sillones, servicios, turnos'),
    ('tienda', '🛍️', 'Tienda / Retail', 'Catálogo, stock, venta directa'),
  ];

  Widget _seccionTipoTpv() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('TIPO DE NEGOCIO (TPV)'),
      _card(Column(
        children: _tiposTpv.map((t) {
          final (id, emoji, label, desc) = t;
          final sel = _tipoTpv == id;
          return InkWell(
            onTap: () => setState(() => _tipoTpv = id),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1565C0).withValues(alpha: 0.08) : null,
                borderRadius: BorderRadius.circular(8),
                border: sel ? Border.all(color: const Color(0xFF1565C0), width: 1.5) : null,
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontWeight: FontWeight.w600,
                            color: sel ? const Color(0xFF1565C0) : null)),
                        Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (sel) const Icon(Icons.check_circle, color: Color(0xFF1565C0)),
                ],
              ),
            ),
          );
        }).toList(),
      )),
    ],
  );

  Widget _seccionModo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('MODO DE FACTURACIÓN'),
      _card(Column(
        children: ModoFacturacionTpv.values.map((modo) => InkWell(
          onTap: () => setState(() => _config = _config.copyWith(modo: modo)),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Radio<ModoFacturacionTpv>(
                  value: modo,
                  groupValue: _config.modo,
                  onChanged: (v) => setState(() => _config = _config.copyWith(modo: v)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Row(children: [
                        Text(modo.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (modo == ModoFacturacionTpv.resumenDiario) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Recomendado',
                                style: TextStyle(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(modo.descripcion, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      )),
    ],
  );

  // ── RESUMEN DIARIO ────────────────────────────────────────────────────────────

  Widget _seccionResumenDiario() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('RESUMEN DIARIO'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hora de generación'),
            trailing: TextButton(
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _config.horaGeneracion,
                );
                if (t != null) setState(() => _config = _config.copyWith(horaGeneracion: t));
              },
              child: Text(
                '${_config.horaGeneracion.hour.toString().padLeft(2,'0')}:${_config.horaGeneracion.minute.toString().padLeft(2,'0')}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Generar automáticamente'),
            subtitle: const Text('Usa Cloud Function para generación nocturna', style: TextStyle(fontSize: 12)),
            value: _config.generarAutomaticamente,
            onChanged: (v) => setState(() => _config = _config.copyWith(generarAutomaticamente: v)),
          ),
        ],
      )),
    ],
  );

  // ── POR VENTA ─────────────────────────────────────────────────────────────────

  Widget _seccionPorVenta() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('POR CADA VENTA'),
      _card(SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Solo si el pedido tiene cliente'),
        subtitle: const Text('No genera factura para ventas anónimas', style: TextStyle(fontSize: 12)),
        value: _config.soloSiClienteIdentificado,
        onChanged: (v) => setState(() => _config = _config.copyWith(soloSiClienteIdentificado: v)),
      )),
    ],
  );

  // ── MÉTODOS DE PAGO ─────────────────────────────────────────────────────────

  Widget _seccionMetodosPago() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('MÉTODOS DE PAGO A INCLUIR'),
      _card(Column(
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('💵 Efectivo'),
            value: _config.incluirPedidosEfectivo,
            onChanged: (v) => setState(() => _config = _config.copyWith(incluirPedidosEfectivo: v ?? true)),
            dense: true,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('💳 Tarjeta'),
            value: _config.incluirPedidosTarjeta,
            onChanged: (v) => setState(() => _config = _config.copyWith(incluirPedidosTarjeta: v ?? true)),
            dense: true,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('🔀 Mixto'),
            value: _config.incluirPedidosMixto,
            onChanged: (v) => setState(() => _config = _config.copyWith(incluirPedidosMixto: v ?? true)),
            dense: true,
          ),
        ],
      )),
    ],
  );

  // ── SERIE ────────────────────────────────────────────────────────────────────

  Widget _seccionSerie() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('SERIE DE FACTURAS TPV'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: TextEditingController(text: _config.serieFactura),
            decoration: const InputDecoration(
              labelText: 'Prefijo de serie',
              hintText: 'TPV-',
              border: OutlineInputBorder(),
              helperText: 'Ejemplo: TPV-2026-001',
            ),
            onChanged: (v) => _config = _config.copyWith(serieFactura: v),
          ),
        ],
      )),
    ],
  );

  // ── OPCIONES ─────────────────────────────────────────────────────────────────

  Widget _seccionOpciones() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('OPCIONES GENERALES'),
      _card(Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Facturación automática al cobrar'),
            subtitle: const Text('Genera una factura automáticamente cada vez que se cobra un ticket en el TPV', 
                style: TextStyle(fontSize: 12)),
            value: _config.facturacionAutomatica,
            onChanged: (v) => setState(() => _config = _config.copyWith(facturacionAutomatica: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aplicar VeriFactu'),
            subtitle: const Text('Enviar facturas al sistema de la AEAT', style: TextStyle(fontSize: 12)),
            value: _config.aplicarVeriFactu,
            onChanged: (v) => setState(() => _config = _config.copyWith(aplicarVeriFactu: v)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vencimiento'),
            trailing: DropdownButton<int>(
              value: _config.diasVencimiento,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('0 días (contado)')),
                DropdownMenuItem(value: 15, child: Text('15 días')),
                DropdownMenuItem(value: 30, child: Text('30 días')),
                DropdownMenuItem(value: 60, child: Text('60 días')),
              ],
              onChanged: (v) => setState(() => _config = _config.copyWith(diasVencimiento: v ?? 0)),
            ),
          ),
        ],
      )),
    ],
  );

  // ── BLUETOOTH ──────────────────────────────────────────────────────────────────

  Widget _seccionBluetooth() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('IMPRESORA BLUETOOTH'),
      _card(Column(
        children: [
          if (_btConectada && _nombreImpresora != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bluetooth_connected, color: Colors.green, size: 28),
              title: Text('Conectada: $_nombreImpresora'),
              subtitle: const Text('Impresora lista para usar', style: TextStyle(fontSize: 12)),
              trailing: TextButton.icon(
                onPressed: _desconectarBluetooth,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Desconectar'),
              ),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bluetooth_disabled, color: Colors.grey, size: 28),
              title: const Text('Sin impresora conectada'),
              subtitle: const Text('Conecta una impresora Bluetooth para imprimir tickets', style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _configurarBluetooth,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Buscar y conectar impresora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      )),
    ],
  );

  Future<void> _configurarBluetooth() async {
    try {
      final impresoras = await ImpressoraBluetooth().escanearImpresoras();
      if (!mounted) return;
      
      if (impresoras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron impresoras Bluetooth vinculadas.\n'
                'Vincula la impresora en los ajustes de Bluetooth de tu dispositivo primero.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final seleccionada = await showDialog<BluetoothDevice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Seleccionar impresora'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView.builder(
              itemCount: impresoras.length,
              itemBuilder: (_, i) {
                final imp = impresoras[i];
                return ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(imp.name ?? 'Sin nombre'),
                  subtitle: Text(imp.address ?? ''),
                  onTap: () => Navigator.pop(ctx, imp),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (seleccionada != null) {
        await ImpressoraBluetooth().conectar(seleccionada);
        await _verificarBluetooth();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Conectado a ${seleccionada.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _desconectarBluetooth() async {
    await ImpressoraBluetooth().olvidarImpresora();
    await _verificarBluetooth();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impresora desconectada')),
      );
    }
  }

  // ── IMPORTAR CATÁLOGO ──────────────────────────────────────────────────────────

  Widget _seccionImportarCatalogo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('IMPORTAR CATÁLOGO (CSV)'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Importa productos en masa desde un archivo CSV o Excel.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _mostrarInfoPlantilla,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Info plantilla'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _mostrarInfoImportacion,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Importar CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      )),
    ],
  );

  void _mostrarInfoPlantilla() {
    const plantilla = 'nombre,categoria,precio,descripcion,iva,sku,codigo_barras,stock\n'
        'Coca-Cola 33cl,Bebidas,1.50,Refresco de cola,10,COCA33,5449000000996,100\n'
        'Cerveza Estrella 33cl,Bebidas,2.00,Cerveza nacional,10,CERV33,8410793504039,200\n'
        'Café solo,Cafetería,1.20,Café espresso,10,CAFE01,,\n'
        'Jamón serrano,Tapas,3.50,Ración de jamón ibérico,10,JAM01,,50';
        
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Plantilla CSV'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Formato esperado del archivo CSV:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  plantilla,
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Copia este contenido y pégalo en Excel o Google Sheets. '
                'Guarda como CSV y súbelo desde "Importar CSV".',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarInfoImportacion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportarCatalogoCsvScreen(empresaId: widget.empresaId),
      ),
    );
  }

  // ── IMÁGENES DE PRODUCTOS ──────────────────────────────────────────────────────

  Widget _seccionImagenesProductos() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _titulo('IMÁGENES DE PRODUCTOS'),
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gestiona las imágenes de los productos de tu catálogo.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _mostrarInfoImagenes,
              icon: const Icon(Icons.image),
              label: const Text('Gestionar imágenes del catálogo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      )),
    ],
  );

  void _mostrarInfoImagenes() async {
    // Cargar productos del catálogo
    final productosSnap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('catalogo')
        .get();

    if (!mounted) return;

    if (productosSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos en el catálogo')),
      );
      return;
    }

    // Mostrar diálogo con lista de productos
    showDialog(
      context: context,
      builder: (_) => _DialogoGestionImagenes(
        empresaId: widget.empresaId,
        productos: productosSnap.docs,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO GESTIÓN DE IMÁGENES DE PRODUCTOS
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoGestionImagenes extends StatefulWidget {
  final String empresaId;
  final List<QueryDocumentSnapshot> productos;

  const _DialogoGestionImagenes({
    required this.empresaId,
    required this.productos,
  });

  @override
  State<_DialogoGestionImagenes> createState() => _DialogoGestionImagenesState();
}

class _DialogoGestionImagenesState extends State<_DialogoGestionImagenes> {
  bool _subiendo = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gestionar Imágenes de Productos'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: ListView.builder(
          itemCount: widget.productos.length,
          itemBuilder: (context, index) {
            final producto = widget.productos[index];
            final data = producto.data() as Map<String, dynamic>;
            final nombre = data['nombre'] as String? ?? 'Sin nombre';
            final imagenUrl = data['imagen_url'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: imagenUrl != null && imagenUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          imagenUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                title: Text(nombre),
                subtitle: imagenUrl != null && imagenUrl.isNotEmpty
                    ? const Text('Imagen asignada', style: TextStyle(color: Colors.green, fontSize: 11))
                    : const Text('Sin imagen', style: TextStyle(color: Colors.grey, fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imagenUrl != null && imagenUrl.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        tooltip: 'Eliminar imagen',
                        onPressed: () => _eliminarImagen(producto.id, imagenUrl),
                      ),
                    IconButton(
                      icon: const Icon(Icons.upload),
                      tooltip: 'Subir imagen',
                      onPressed: () => _subirImagen(producto.id, nombre),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        if (_subiendo)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        TextButton(
          onPressed: _subiendo ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _subirImagen(String productoId, String nombreProducto) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _subiendo = true);

      final file = result.files.first;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('empresas/${widget.empresaId}/productos/$fileName');

      // Subir archivo — usa bytes siempre que estén disponibles (funciona en Web, Windows, Android, iOS)
      if (kIsWeb || file.bytes != null) {
        await storageRef.putData(file.bytes!);
      } else if (file.path != null) {
        await storageRef.putFile(File(file.path!));
      } else {
        throw Exception('No se pudieron leer los bytes del archivo');
      }

      // Obtener URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Actualizar Firestore
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('catalogo')
          .doc(productoId)
          .update({'imagen_url': downloadUrl});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Imagen subida para $nombreProducto'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => _subiendo = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminarImagen(String productoId, String imagenUrl) async {
    try {
      setState(() => _subiendo = true);

      // Eliminar de Storage
      try {
        final ref = FirebaseStorage.instance.refFromURL(imagenUrl);
        await ref.delete();
      } catch (e) {
        print('No se pudo eliminar de Storage: $e');
      }

      // Actualizar Firestore
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('catalogo')
          .doc(productoId)
          .update({'imagen_url': FieldValue.delete()});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Imagen eliminada'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => _subiendo = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _subiendo = false);
    }
  }
}

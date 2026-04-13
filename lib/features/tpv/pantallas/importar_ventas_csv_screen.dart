import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../domain/modelos/importacion_tpv.dart';
import '../../../services/csv_ventas_parser.dart';
import '../../../services/pedidos_service.dart';

class ImportarVentasCsvScreen extends StatefulWidget {
  final String empresaId;
  const ImportarVentasCsvScreen({super.key, required this.empresaId});

  @override
  State<ImportarVentasCsvScreen> createState() => _ImportarVentasCsvScreenState();
}

class _ImportarVentasCsvScreenState extends State<ImportarVentasCsvScreen> {
  final PedidosService _svc = PedidosService();

  int _paso = 0; // 0=instrucciones, 1=selección, 2=mapeo, 3=preview, 4=importando
  ResultadoParseoVentas? _parseo;
  String _nombreFichero = '';
  int _importados = 0;

  // Mapeo manual (si el auto no es correcto)
  Map<String, int> _mapeoManual = {};
  Map<String, String?> _columnasSeleccionadas = {
    'fecha': null,
    'descripcion': null,
    'cantidad': null,
    'precio': null,
    'total': null,
    'forma_pago': null,
    'iva': null,
  };

  // ── PASO 1: Seleccionar fichero ─────────────────────────────────────────

  Future<void> _seleccionarFichero() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _nombreFichero = file.name;
      _parseo = CsvVentasParser.parsear(file.bytes!);
      // Pre-rellenar mapeo manual con el automático
      for (final entry in _parseo!.mapeoColumnas.entries) {
        _columnasSeleccionadas[entry.key] = _parseo!.columnasDetectadas[entry.value];
      }
      _paso = 2;
    });
  }

  // ── PASO 2: Aplicar mapeo y parsear de nuevo ────────────────────────────

  void _aplicarMapeo() {
    if (_parseo == null) return;
    // Construir mapa índice desde la selección
    _mapeoManual = {};
    _columnasSeleccionadas.forEach((campo, col) {
      if (col != null) {
        final idx = _parseo!.columnasDetectadas.indexOf(col);
        if (idx >= 0) _mapeoManual[campo] = idx;
      }
    });
    setState(() => _paso = 3);
  }

  // ── PASO 3: Importar ────────────────────────────────────────────────────

  Future<void> _importar() async {
    if (_parseo == null) return;
    final filaValidas = _parseo!.filaValidas;
    if (filaValidas.isEmpty) return;

    setState(() { _paso = 4; _importados = 0; });

    final pedidosCreados = <String>[];
    try {
      for (final fila in filaValidas) {
        final linea = LineaPedido(
          productoId: 'tpv_import',
          productoNombre: fila.descripcion,
          precioUnitario: fila.precioUnitario,
          cantidad: fila.cantidad.toInt(),
        );
        final pedido = await _svc.crearPedido(
          empresaId: widget.empresaId,
          clienteNombre: 'Importación TPV',
          lineas: [linea],
          origen: OrigenPedido.tpvExterno,
          metodoPago: fila.metodoPago,
          notasInternas: 'Importado desde CSV — $_nombreFichero',
          usuarioNombre: 'Importación CSV',
        );
        // Marcar como pagado
        await _svc.cambiarEstado(widget.empresaId, pedido.id, EstadoPedido.entregado, '', 'CSV');
        await _svc.cambiarEstadoPago(widget.empresaId, pedido.id, EstadoPago.pagado, '', 'CSV');
        pedidosCreados.add(pedido.id);
        if (mounted) setState(() => _importados++);
      }

      // Guardar historial de importación
      await _guardarHistorial(pedidosCreados, filaValidas.length, _parseo!.filasConError.length);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ ${pedidosCreados.length} ventas importadas correctamente'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _paso = 3; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al importar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _guardarHistorial(List<String> ids, int correctas, int errores) async {
    final importacion = ImportacionTpv(
      id: '',
      empresaId: widget.empresaId,
      nombreFichero: _nombreFichero,
      fechaImportacion: DateTime.now(),
      totalFilas: correctas + errores,
      filasImportadas: correctas,
      filasError: errores,
      origen: 'csv_manual',
      pedidosCreados: ids,
    );
    await FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('importacionesTpv').add(importacion.toFirestore());
  }

  // ── COMPARTIR PLANTILLA ─────────────────────────────────────────────────

  void _descargarPlantilla() {
    Share.share(
      CsvVentasParser.generarPlantilla(),
      subject: 'Plantilla_TPV_Fluix.csv',
    );
  }

  // ── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar ventas CSV', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_paso + 1) / 5,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      body: IndexedStack(
        index: _paso.clamp(0, 4),
        children: [
          _buildPasoInstrucciones(),
          _buildPasoSeleccion(),
          _buildPasoMapeo(),
          _buildPasoPreview(),
          _buildPasoImportando(),
        ],
      ),
    );
  }

  // ── PASO 0: Instrucciones ───────────────────────────────────────────────

  Widget _buildPasoInstrucciones() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Qué es la importación de ventas?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'Importa el cierre del día de tu TPV externo en Fluix. '
            'Acepta CSV exportados desde Glop, Agora, ICG, Excel o cualquier banco.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text('¿Cómo exportar desde tu TPV?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...[
            ('🖥️ Glop',   'Informes → Exportar → CSV'),
            ('📊 Agora',  'Estadísticas → Exportar datos → CSV'),
            ('💼 ICG',    'Informes → Cierre → Exportar'),
            ('📋 Excel',  'Usa la plantilla descargable'),
            ('🏦 Banco',  'Descarga el extracto de ventas TPV'),
          ].map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(child: Text(e.$2, style: const TextStyle(fontSize: 13, color: Colors.grey))),
              ],
            ),
          )),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _descargarPlantilla,
            icon: const Icon(Icons.download),
            label: const Text('Descargar plantilla CSV'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() => _paso = 1),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Comenzar importación'),
            ),
          ),
        ],
      ),
    );
  }

  // ── PASO 1: Selección ───────────────────────────────────────────────────

  Widget _buildPasoSeleccion() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file, size: 80, color: Color(0xFF1565C0)),
            const SizedBox(height: 20),
            const Text('Selecciona el fichero CSV',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Acepta: .csv y .txt con separador coma o punto y coma',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _seleccionarFichero,
              icon: const Icon(Icons.folder_open),
              label: const Text('Seleccionar CSV'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _paso = 0),
              child: const Text('← Volver'),
            ),
          ],
        ),
      ),
    );
  }

  // ── PASO 2: Mapeo ───────────────────────────────────────────────────────

  Widget _buildPasoMapeo() {
    if (_parseo == null) return const SizedBox();
    final cols = _parseo!.columnasDetectadas;

    final labels = {
      'fecha':       ('Fecha venta', true),
      'descripcion': ('Nombre producto', false),
      'cantidad':    ('Cantidad', false),
      'precio':      ('Precio unitario', false),
      'total':       ('Total línea', true),
      'forma_pago':  ('Método de pago', false),
      'iva':         ('% IVA', false),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mapear columnas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Fichero: $_nombreFichero', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          ...labels.entries.map((entry) {
            final campo = entry.key;
            final label = entry.value.$1;
            final required = entry.value.$2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('$label${required ? ' *' : ''}',
                        style: TextStyle(fontWeight: required ? FontWeight.w600 : FontWeight.normal)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _columnasSeleccionadas[campo],
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— No mapear —')),
                        ...cols.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (v) => setState(() => _columnasSeleccionadas[campo] = v),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(children: [
            TextButton(onPressed: () => setState(() => _paso = 1), child: const Text('← Volver')),
            const Spacer(),
            FilledButton(onPressed: _aplicarMapeo, child: const Text('Ver previsualización →')),
          ]),
        ],
      ),
    );
  }

  // ── PASO 3: Preview ─────────────────────────────────────────────────────

  Widget _buildPasoPreview() {
    if (_parseo == null) return const SizedBox();
    final filas = _parseo!.filas;
    final correctas = _parseo!.filaValidas.length;
    final errores = _parseo!.filasConError.length;
    final fmt = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: correctas > 0 ? Colors.green[50] : Colors.orange[50],
          child: Row(
            children: [
              Icon(correctas > 0 ? Icons.check_circle : Icons.warning,
                  color: correctas > 0 ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$correctas ventas correctas${errores > 0 ? ' · $errores con error' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: filas.take(50).length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final fila = filas[i];
              final hayError = !fila.valida;
              return ListTile(
                dense: true,
                tileColor: hayError ? Colors.red[50] : null,
                leading: Text('${fila.numero}',
                    style: TextStyle(
                        color: hayError ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                title: Text(fila.descripcion, style: const TextStyle(fontSize: 13)),
                subtitle: fila.fecha != null
                    ? Text('${fmt.format(fila.fecha!)} · ${fila.cantidad.toStringAsFixed(0)} uds · ${_fmt(fila.total)}')
                    : Text(fila.errores.join(', '), style: const TextStyle(color: Colors.red, fontSize: 11)),
                trailing: Text(_nombreMetodo(fila.metodoPago),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              );
            },
          ),
        ),
        if (filas.length > 50)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Mostrando 50 de ${filas.length} filas',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            TextButton(onPressed: () => setState(() => _paso = 2), child: const Text('← Volver')),
            const Spacer(),
            if (correctas > 0)
              FilledButton.icon(
                onPressed: _importar,
                icon: const Icon(Icons.cloud_upload),
                label: Text('Importar $correctas ventas'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green[700]),
              ),
          ]),
        ),
      ],
    );
  }

  // ── PASO 4: Importando ──────────────────────────────────────────────────

  Widget _buildPasoImportando() {
    final total = _parseo?.filaValidas.length ?? 0;
    final progreso = total > 0 ? _importados / total : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Importando ventas…', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_importados de $total'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progreso),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────

  String _fmt(double v) =>
      NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2).format(v);

  String _nombreMetodo(MetodoPago m) => switch (m) {
    MetodoPago.efectivo => 'Efectivo',
    MetodoPago.tarjeta  => 'Tarjeta',
    MetodoPago.mixto    => 'Mixto',
    MetodoPago.bizum    => 'Bizum',
    MetodoPago.paypal   => 'PayPal',
  };
}



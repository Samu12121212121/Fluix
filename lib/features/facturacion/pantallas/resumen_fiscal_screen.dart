import 'package:flutter/material.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';

class ResumenFiscalScreen extends StatefulWidget {
  final String empresaId;

  const ResumenFiscalScreen({super.key, required this.empresaId});

  @override
  State<ResumenFiscalScreen> createState() => _ResumenFiscalScreenState();
}

class _ResumenFiscalScreenState extends State<ResumenFiscalScreen> {
  final FacturacionService _service = FacturacionService();
  int _mes = DateTime.now().month;
  int _anio = DateTime.now().year;
  Map<String, dynamic>? _resumen;
  bool _cargando = false;

  final List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final resumen = await _service.generarResumenMensual(
          widget.empresaId, _mes, _anio);
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Resumen Fiscal'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSelectorPeriodo(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _buildResumen(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorPeriodo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _mes,
              decoration: _inputDeco('Mes'),
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(_meses[i]),
              )),
              onChanged: (v) {
                setState(() => _mes = v!);
                _cargar();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _anio,
              decoration: _inputDeco('Año'),
              items: List.generate(5, (i) => DropdownMenuItem(
                value: DateTime.now().year - i,
                child: Text('${DateTime.now().year - i}'),
              )),
              onChanged: (v) {
                setState(() => _anio = v!);
                _cargar();
              },
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _cargar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    if (_resumen == null) {
      return const Center(
        child: Text('Selecciona un período para ver el resumen',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final r = _resumen!;
    final baseImponible = (r['base_imponible'] as double?) ?? 0.0;
    final totalIva = (r['total_iva'] as double?) ?? 0.0;
    final totalFacturado = (r['total_facturado'] as double?) ?? 0.0;
    final totalIrpfRetenido = (r['total_irpf_retenido'] as double?) ?? 0.0;
    final totalRecargoEquivalencia = (r['total_recargo_equivalencia'] as double?) ?? 0.0;
    final porMetodo = (r['por_metodo_pago'] as Map<String, double>?) ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                '${_meses[_mes - 1]} $_anio',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${totalFacturado.toStringAsFixed(2)}€',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold),
              ),
              const Text('Total facturado',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Resumen de facturas
        _buildCard('📋 Resumen de Facturas', [
          _buildFila('Total emitidas', '${r['total_facturas'] ?? 0}'),
          _buildFila('Pagadas', '${r['total_pagadas'] ?? 0}',
              color: const Color(0xFF4CAF50)),
          _buildFila('Pendientes', '${r['total_pendientes'] ?? 0}',
              color: const Color(0xFFFF9800)),
          _buildFila('Vencidas', '${r['total_vencidas'] ?? 0}',
              color: Colors.red),
          _buildFila('Rectificativas', '${r['total_rectificativas'] ?? 0}',
              color: Colors.deepPurple),
          _buildFila('Anuladas', '${r['total_anuladas'] ?? 0}',
              color: Colors.grey),
        ]),
        const SizedBox(height: 16),

        // Datos para declaración de IVA
        _buildCard('🏛️ Modelo 303 - IVA', [
          _buildFila('Base Imponible',
              '${baseImponible.toStringAsFixed(2)}€'),
          _buildFila('IVA Repercutido (ventas)',
              '${totalIva.toStringAsFixed(2)}€',
              color: const Color(0xFF0D47A1),
              bold: true),
          if (totalRecargoEquivalencia > 0)
            _buildFila('Recargo Equivalencia',
                '${totalRecargoEquivalencia.toStringAsFixed(2)}€',
                color: const Color(0xFF0D47A1)),
          const Divider(height: 20),
          const Text(
            '⚠️ Recuerda deducir el IVA soportado (compras/gastos) para calcular la cantidad a ingresar o devolver.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ]),
        const SizedBox(height: 16),

        // IRPF retenido (si aplica)
        if (totalIrpfRetenido > 0) ...[
          _buildCard('🏛️ Modelo 111/115 - Retenciones IRPF', [
            _buildFilaImporte('Total retenciones IRPF', totalIrpfRetenido),
            const Divider(height: 12),
            const Text(
              'Retenciones practicadas a profesionales/freelancers que debes ingresar trimestralmente.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
          const SizedBox(height: 16),
        ],

        // Detalle fiscal
        _buildCard('📊 Desglose Fiscal', [
          _buildFilaImporte('Base imponible', baseImponible),
          _buildFilaImporte('IVA repercutido', totalIva),
          if (totalRecargoEquivalencia > 0)
            _buildFilaImporte('Recargo equivalencia', totalRecargoEquivalencia),
          if (totalIrpfRetenido > 0)
            _buildFilaImporte('IRPF retenido', -totalIrpfRetenido),
          const Divider(height: 12),
          _buildFilaImporte('Total facturado', totalFacturado, bold: true),
        ]),
        const SizedBox(height: 16),

        // Por método de pago
        if (porMetodo.isNotEmpty)
          _buildCard('💳 Por Método de Pago', [
            ...porMetodo.entries.map((e) =>
                _buildFilaImporte(e.key, e.value)),
          ]),

        const SizedBox(height: 32),

        // Aviso
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFFF9800)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este resumen es orientativo. Consulta siempre con tu asesor fiscal para la presentación de impuestos.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCard(String titulo, List<Widget> children) {
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

  Widget _buildFila(String label, String valor,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text(valor,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                color: color ?? Colors.black,
              )),
        ],
      ),
    );
  }

  Widget _buildFilaImporte(String label, double valor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: bold ? Colors.black : Colors.grey[700])),
          Text('${valor.toStringAsFixed(2)}€',
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: bold ? const Color(0xFF0D47A1) : Colors.black)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}



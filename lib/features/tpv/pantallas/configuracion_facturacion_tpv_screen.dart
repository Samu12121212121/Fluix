import 'package:flutter/material.dart';
import '../../../domain/modelos/configuracion_facturacion_tpv.dart';
import '../../../services/tpv_facturacion_service.dart';

class ConfiguracionFacturacionTpvScreen extends StatefulWidget {
  final String empresaId;
  const ConfiguracionFacturacionTpvScreen({super.key, required this.empresaId});

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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final config = await _svc.obtenerConfig(widget.empresaId);
    setState(() { _config = config; _cargando = false; });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _svc.guardarConfig(widget.empresaId, _config);
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

  // ── MODO ────────────────────────────────────────────────────────────────────

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
}



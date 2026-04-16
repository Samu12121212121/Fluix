import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import '../../services/tpv/impresora_bluetooth_service.dart';

/// Botón inteligente de impresión Bluetooth.
/// - Impresora guardada y conectada → imprime directo.
/// - Sin impresora → abre bottom sheet para escanear y elegir.
class BotonImprimirWidget extends StatefulWidget {
  final Future<void> Function() onImprimir;
  final String label;
  final IconData icono;
  final Color? color;

  const BotonImprimirWidget({
    super.key,
    required this.onImprimir,
    this.label = 'Imprimir',
    this.icono = Icons.print_rounded,
    this.color,
  });

  @override
  State<BotonImprimirWidget> createState() => _BotonImprimirWidgetState();
}

class _BotonImprimirWidgetState extends State<BotonImprimirWidget> {
  final _svc = ImpressoraBluetooth();
  bool _imprimiendo = false;

  Future<void> _handleTap() async {
    if (_imprimiendo) return;
    final ultima = await _svc.obtenerUltimaGuardada();
    final conectada = await _svc.estaConectada();
    if (ultima != null && conectada) {
      await _ejecutarImpresion();
    } else {
      if (!mounted) return;
      await _mostrarSelector();
    }
  }

  Future<void> _ejecutarImpresion() async {
    setState(() => _imprimiendo = true);
    try {
      await widget.onImprimir();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Text('Impresión enviada'),
        ]),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al imprimir: $e'),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  Future<void> _mostrarSelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SelectorImpresoraSheet(
        svc: _svc,
        onConectada: () async {
          Navigator.pop(ctx);
          await _ejecutarImpresion();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF1565C0);
    return ElevatedButton.icon(
      onPressed: _imprimiendo ? null : _handleTap,
      icon: _imprimiendo
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(widget.icono),
      label: Text(widget.label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );
  }
}

class _SelectorImpresoraSheet extends StatefulWidget {
  final ImpressoraBluetooth svc;
  final VoidCallback onConectada;
  const _SelectorImpresoraSheet({required this.svc, required this.onConectada});
  @override
  State<_SelectorImpresoraSheet> createState() => _SelectorImpresoraSheetState();
}

class _SelectorImpresoraSheetState extends State<_SelectorImpresoraSheet> {
  List<BluetoothDevice>? _dispositivos;
  String? _error;
  bool _escaneando = true;
  String? _conectando;

  @override
  void initState() {
    super.initState();
    _escanear();
  }

  Future<void> _escanear() async {
    setState(() { _escaneando = true; _error = null; });
    try {
      final devs = await widget.svc.escanearImpresoras();
      if (mounted) setState(() => _dispositivos = devs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _escaneando = false);
    }
  }

  Future<void> _conectar(BluetoothDevice device) async {
    setState(() => _conectando = device.address);
    try {
      await widget.svc.conectar(device);
      widget.onConectada();
    } catch (e) {
      if (mounted) {
        setState(() => _conectando = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Seleccionar impresora',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _escaneando ? null : _escanear),
            ],
          ),
          const SizedBox(height: 8),
          if (_escaneando)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_error != null)
            Center(child: Column(children: [
              const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ]))
          else if (_dispositivos?.isEmpty ?? true)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No se encontraron impresoras vinculadas.', style: TextStyle(color: Colors.grey)),
            ))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dispositivos!.length,
              itemBuilder: (_, i) {
                final dev = _dispositivos![i];
                final cargando = _conectando == dev.address;
                return ListTile(
                  leading: const Icon(Icons.print_rounded, color: Color(0xFF1565C0)),
                  title: Text(dev.name ?? 'Impresora desconocida'),
                  subtitle: Text(dev.address ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: cargando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: cargando ? null : () => _conectar(dev),
                );
              },
            ),
        ],
      ),
    );
  }
}


import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/modelos/cierre_caja.dart';
import '../../../services/tpv/cierre_caja_service.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import '../../../widgets/tpv/boton_imprimir_widget.dart';

class PantallaCierreCaja extends StatefulWidget {
  final String empresaId;

  const PantallaCierreCaja({super.key, required this.empresaId});

  @override
  State<PantallaCierreCaja> createState() => _PantallaCierreCajaState();
}

class _PantallaCierreCajaState extends State<PantallaCierreCaja> {
  static const Color _azul = Color(0xFF1565C0);
  static const Color _fondo = Color(0xFFF5F5F5);

  final _svc = CierreCajaService();
  final _impresora = ImpressoraBluetooth();
  final _obsCtrl = TextEditingController();

  CierreCaja? _cierreCalculado;
  bool _calculando = true;
  bool _guardando = false;
  bool _yaCerrado = false;

  @override
  void initState() {
    super.initState();
    _calcular();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    setState(() => _calculando = true);
    try {
      final cierre = await _svc.calcularCierreCaja(
          widget.empresaId, DateTime.now());
      final yaCerrado =
          await _svc.existeCierreCajaHoy(widget.empresaId);
      if (mounted) {
        setState(() {
          _cierreCalculado = cierre;
          _yaCerrado = yaCerrado;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error calculando: $e'),
          backgroundColor: Colors.red[700],
        ));
      }
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  Future<void> _cerrarCaja() async {
    if (_cierreCalculado == null || _yaCerrado) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final cierre = CierreCaja(
      fecha: _cierreCalculado!.fecha,
      totalEfectivo: _cierreCalculado!.totalEfectivo,
      totalTarjeta: _cierreCalculado!.totalTarjeta,
      totalTransferencia: _cierreCalculado!.totalTransferencia,
      totalVentas: _cierreCalculado!.totalVentas,
      numTickets: _cierreCalculado!.numTickets,
      cerradoPor: uid,
      timestamp: DateTime.now(),
      observaciones: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
    );

    setState(() => _guardando = true);
    try {
      await _svc.guardarCierreCaja(widget.empresaId, cierre);
      if (!mounted) return;
      setState(() {
        _cierreCalculado = cierre;
        _yaCerrado = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Text('Cierre de caja guardado'),
        ]),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al guardar: $e'),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.point_of_sale_rounded, size: 22),
          SizedBox(width: 8),
          Text('Cierre de Caja',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
      ),
      body: _calculando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Aviso si ya cerrado ───────────────────────────────────
                if (_yaCerrado)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Text(
                        'La caja ya fue cerrada hoy. No se puede volver a cerrar.',
                        style: TextStyle(fontSize: 13),
                      )),
                    ]),
                  ),

                // ── Resumen del día ──────────────────────────────────────
                if (_cierreCalculado != null) ...[
                  _TarjetaResumen(cierre: _cierreCalculado!),
                  const SizedBox(height: 16),

                  // Observaciones
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _obsCtrl,
                        enabled: !_yaCerrado,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones (opcional)',
                          hintText: 'Incidencias, comentarios...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botones de acción
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _yaCerrado || _guardando ? null : _cerrarCaja,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.lock_rounded),
                        label: Text(_yaCerrado
                            ? 'Ya cerrada'
                            : _guardando
                                ? 'Guardando...'
                                : 'Cerrar caja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _yaCerrado
                              ? Colors.grey
                              : Colors.green[700],
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    BotonImprimirWidget(
                      label: 'Imprimir',
                      icono: Icons.print_rounded,
                      onImprimir: () async {
                        if (_cierreCalculado != null) {
                          final cierre = CierreCaja(
                            fecha: _cierreCalculado!.fecha,
                            totalEfectivo: _cierreCalculado!.totalEfectivo,
                            totalTarjeta: _cierreCalculado!.totalTarjeta,
                            totalTransferencia:
                                _cierreCalculado!.totalTransferencia,
                            totalVentas: _cierreCalculado!.totalVentas,
                            numTickets: _cierreCalculado!.numTickets,
                            cerradoPor: _cierreCalculado!.cerradoPor,
                            timestamp: _cierreCalculado!.timestamp,
                            observaciones: _obsCtrl.text.trim().isEmpty
                                ? null
                                : _obsCtrl.text.trim(),
                          );
                          await _impresora.imprimirCierreCaja(cierre);
                        }
                      },
                    ),
                  ]),
                ],

                const SizedBox(height: 28),

                // ── Historial últimos 7 cierres ──────────────────────────
                const Text('Últimos cierres',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _HistorialCierres(
                    empresaId: widget.empresaId, svc: _svc),
              ],
            ),
    );
  }
}

// ── TARJETA RESUMEN ───────────────────────────────────────────────────────────

class _TarjetaResumen extends StatelessWidget {
  final CierreCaja cierre;

  const _TarjetaResumen({required this.cierre});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total destacado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total del día',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text(
                  fmt.format(cierre.totalGeneral),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Desglose por método
            _FilaMetodo(
              icono: Icons.payments_rounded,
              label: 'Efectivo',
              importe: cierre.totalEfectivo,
              color: Colors.green[700]!,
            ),
            _FilaMetodo(
              icono: Icons.credit_card_rounded,
              label: 'Tarjeta / Bizum',
              importe: cierre.totalTarjeta,
              color: const Color(0xFF1565C0),
            ),
            _FilaMetodo(
              icono: Icons.account_balance_rounded,
              label: 'Transferencia',
              importe: cierre.totalTransferencia,
              color: Colors.purple[700]!,
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.receipt_long_rounded,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('${cierre.numTickets} ticket${cierre.numTickets != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ]),
                Text('Ventas: ${fmt.format(cierre.totalVentas)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaMetodo extends StatelessWidget {
  final IconData icono;
  final String label;
  final double importe;
  final Color color;

  const _FilaMetodo({
    required this.icono,
    required this.label,
    required this.importe,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14)),
          ),
          Text(fmt.format(importe),
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color)),
        ],
      ),
    );
  }
}

// ── HISTORIAL ─────────────────────────────────────────────────────────────────

class _HistorialCierres extends StatelessWidget {
  final String empresaId;
  final CierreCajaService svc;

  const _HistorialCierres(
      {required this.empresaId, required this.svc});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CierreCaja>>(
      stream: svc.getCierresAnteriores(empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final lista = (snap.data ?? []).take(7).toList();
        if (lista.isEmpty) {
          return Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Center(
                child: Text('Sin historial de cierres',
                    style: TextStyle(color: Colors.grey[500])),
              ),
            ),
          );
        }

        final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
        final fmtFecha = DateFormat('dd/MM/yyyy');

        return Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lista.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 56),
            itemBuilder: (_, i) {
              final c = lista[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE3F0FF),
                  child: const Icon(Icons.lock_rounded,
                      color: Color(0xFF1565C0), size: 20),
                ),
                title: Text(fmtFecha.format(c.fecha),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${c.numTickets} tickets · ${fmt.format(c.totalGeneral)}',
                    style: const TextStyle(fontSize: 12)),
                trailing: Text(fmt.format(c.totalGeneral),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0))),
              );
            },
          ),
        );
      },
    );
  }
}


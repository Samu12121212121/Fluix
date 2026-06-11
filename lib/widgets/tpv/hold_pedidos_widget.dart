import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _kBg = Color(0xFF0A0F23);
const _kCard = Color(0xFF1E2139);
const _kVerde = Color(0xFF00FFC8);
const _kRosa = Color(0xFFFF3296);
const _kSecondary = Color(0xFFB0B3C1);

// ── Modelo ────────────────────────────────────────────────────────────────────

class PedidoEnEspera {
  final String id;
  final String etiqueta;
  final List<Map<String, dynamic>> lineas;
  final double total;
  final DateTime guardadoEn;

  const PedidoEnEspera({
    required this.id,
    required this.etiqueta,
    required this.lineas,
    required this.total,
    required this.guardadoEn,
  });
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class HoldPedidosNotifier extends ChangeNotifier {
  final List<PedidoEnEspera> _pedidos = [];
  static const _uuid = Uuid();

  List<PedidoEnEspera> get pedidos => List.unmodifiable(_pedidos);

  String guardar({
    required String etiqueta,
    required List<Map<String, dynamic>> lineas,
    required double total,
  }) {
    final id = _uuid.v4();
    _pedidos.add(PedidoEnEspera(
      id: id,
      etiqueta: etiqueta.isNotEmpty ? etiqueta : 'Pedido en espera',
      lineas: lineas,
      total: total,
      guardadoEn: DateTime.now(),
    ));
    notifyListeners();
    return id;
  }

  PedidoEnEspera? recuperar(String id) {
    final idx = _pedidos.indexWhere((p) => p.id == id);
    if (idx == -1) return null;
    final pedido = _pedidos[idx];
    _pedidos.removeAt(idx);
    notifyListeners();
    return pedido;
  }

  void eliminar(String id) {
    _pedidos.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class HoldPedidosWidget extends StatelessWidget {
  final HoldPedidosNotifier notifier;
  final Function(PedidoEnEspera pedido) onRecuperar;

  const HoldPedidosWidget({
    super.key,
    required this.notifier,
    required this.onRecuperar,
  });

  static Future<PedidoEnEspera?> mostrar(
    BuildContext context,
    HoldPedidosNotifier notifier,
  ) async {
    PedidoEnEspera? resultado;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HoldPedidosWidget(
        notifier: notifier,
        onRecuperar: (p) => resultado = p,
      ),
    );
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final fmtHora = DateFormat('HH:mm');
    final fmtEuro = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return ListenableBuilder(
      listenable: notifier,
      builder: (ctx, _) {
        final pedidos = notifier.pedidos;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pause_circle_outline,
                      color: _kVerde, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pedidos en espera (${pedidos.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: pedidos.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No hay pedidos en espera',
                            style: TextStyle(color: _kSecondary, fontSize: 14),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: pedidos.length,
                        itemBuilder: (_, i) {
                          final p = pedidos[i];
                          final items = p.lineas.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: _kCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _kVerde.withOpacity(0.2)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _kVerde.withOpacity(0.15),
                                child: const Icon(
                                  Icons.pause_rounded,
                                  color: _kVerde,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                p.etiqueta,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '$items artículo${items != 1 ? 's' : ''}  ·  ${fmtHora.format(p.guardadoEn)}',
                                style: const TextStyle(
                                    color: _kSecondary, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fmtEuro.format(p.total),
                                    style: const TextStyle(
                                      color: _kVerde,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: _kRosa, size: 18),
                                    tooltip: 'Eliminar',
                                    onPressed: () =>
                                        notifier.eliminar(p.id),
                                  ),
                                ],
                              ),
                              onTap: () {
                                final recuperado = notifier.recuperar(p.id);
                                if (recuperado != null) {
                                  onRecuperar(recuperado);
                                  Navigator.pop(ctx);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

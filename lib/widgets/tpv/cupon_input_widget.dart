import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kBg = Color(0xFF0A0F23);
const _kCard = Color(0xFF1E2139);
const _kVerde = Color(0xFF00FFC8);
const _kRosa = Color(0xFFFF3296);
const _kSecondary = Color(0xFFB0B3C1);

class CuponInputWidget extends StatefulWidget {
  final String empresaId;
  final double totalBase;
  final Function(String cuponId, double descuento) onAplicado;
  final VoidCallback? onRetirar;

  const CuponInputWidget({
    super.key,
    required this.empresaId,
    required this.totalBase,
    required this.onAplicado,
    this.onRetirar,
  });

  @override
  State<CuponInputWidget> createState() => _CuponInputWidgetState();
}

class _CuponInputWidgetState extends State<CuponInputWidget> {
  final _ctrl = TextEditingController();
  bool _aplicando = false;
  String? _error;
  String? _cuponAplicado;
  double? _descuentoAplicado;
  final _fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _aplicarCupon() async {
    final codigo = _ctrl.text.trim().toUpperCase();
    if (codigo.isEmpty) {
      setState(() => _error = 'Introduce un código de cupón');
      return;
    }

    setState(() {
      _aplicando = true;
      _error = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('cupones')
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _error = 'Cupón no encontrado';
          _aplicando = false;
        });
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();

      // Validar activo
      if (data['activo'] != true) {
        setState(() {
          _error = 'Este cupón no está activo';
          _aplicando = false;
        });
        return;
      }

      // Validar expiración
      if (data['fecha_expiracion'] != null) {
        final expira = data['fecha_expiracion'] is Timestamp
            ? (data['fecha_expiracion'] as Timestamp).toDate()
            : DateTime.tryParse(data['fecha_expiracion'].toString());
        if (expira != null && expira.isBefore(DateTime.now())) {
          setState(() {
            _error = 'Este cupón ha expirado';
            _aplicando = false;
          });
          return;
        }
      }

      // Validar usos
      final usosMax = (data['usos_maximos'] as num?)?.toInt();
      final usosActuales = (data['usos_actuales'] as num?)?.toInt() ?? 0;
      if (usosMax != null && usosActuales >= usosMax) {
        setState(() {
          _error = 'Este cupón ha alcanzado el límite de usos';
          _aplicando = false;
        });
        return;
      }

      // Calcular descuento
      double descuento = 0;
      final tipo = data['tipo'] as String? ?? 'porcentaje';
      final valor = (data['valor'] as num?)?.toDouble() ?? 0;

      if (tipo == 'porcentaje') {
        descuento = widget.totalBase * valor / 100;
      } else {
        descuento = valor.clamp(0.0, widget.totalBase);
      }

      // Incrementar usos_actuales
      await doc.reference
          .update({'usos_actuales': FieldValue.increment(1)});

      setState(() {
        _cuponAplicado = doc.id;
        _descuentoAplicado = descuento;
        _aplicando = false;
        _error = null;
      });

      widget.onAplicado(doc.id, descuento);
    } catch (e) {
      setState(() {
        _error = 'Error al validar el cupón';
        _aplicando = false;
      });
    }
  }

  void _retirar() {
    setState(() {
      _cuponAplicado = null;
      _descuentoAplicado = null;
      _ctrl.clear();
      _error = null;
    });
    widget.onRetirar?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_cuponAplicado != null) {
      return _CuponAplicadoBadge(
        codigo: _ctrl.text.trim().toUpperCase(),
        descuento: _fmt.format(_descuentoAplicado ?? 0),
        onRetirar: _retirar,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _aplicarCupon(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Código de cupón',
                  hintStyle: TextStyle(
                      color: _kSecondary.withOpacity(0.6), fontSize: 13),
                  prefixIcon: const Icon(Icons.local_offer_outlined,
                      color: _kSecondary, size: 18),
                  filled: true,
                  fillColor: _kBg,
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                    borderSide:
                        BorderSide(color: _kSecondary.withOpacity(0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                    borderSide:
                        BorderSide(color: _kSecondary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                    borderSide: const BorderSide(color: _kVerde),
                  ),
                  errorText: _error,
                  errorStyle: const TextStyle(color: _kRosa, fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 12),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: _aplicando ? null : _aplicarCupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kVerde,
                  foregroundColor: _kBg,
                  disabledBackgroundColor: _kVerde.withOpacity(0.3),
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(10)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: _aplicando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF0A0F23)),
                      )
                    : const Text(
                        'Aplicar',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CuponAplicadoBadge extends StatelessWidget {
  final String codigo;
  final String descuento;
  final VoidCallback onRetirar;

  const _CuponAplicadoBadge({
    required this.codigo,
    required this.descuento,
    required this.onRetirar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kVerde.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kVerde.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: _kVerde, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cupón: $codigo',
                  style: const TextStyle(
                      color: _kVerde,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'Descuento: -$descuento',
                  style:
                      const TextStyle(color: _kSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetirar,
            style: TextButton.styleFrom(
              foregroundColor: _kRosa,
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 32),
            ),
            child: const Text('Retirar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

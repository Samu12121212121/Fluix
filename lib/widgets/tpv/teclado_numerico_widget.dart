import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teclado numérico compacto para TPV sin teclado físico.
/// Muestra un dialog centrado (~280px) con display + grid de botones.
/// Uso: `final v = await TecladoNumerico.mostrar(context, label: 'Fondo', sufijo: '€');`
class TecladoNumerico extends StatefulWidget {
  final String label;
  final double? valorInicial;
  final bool permitirDecimal;
  final String sufijo;
  final double? maxValor;
  final String? hint;

  const TecladoNumerico({
    super.key,
    required this.label,
    this.valorInicial,
    this.permitirDecimal = true,
    this.sufijo = '€',
    this.maxValor,
    this.hint,
  });

  /// Muestra el teclado numérico y devuelve el valor introducido o null si se cancela.
  static Future<double?> mostrar(
    BuildContext context, {
    required String label,
    double? valorInicial,
    bool permitirDecimal = true,
    String sufijo = '€',
    double? maxValor,
    String? hint,
  }) {
    return showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (_) => TecladoNumerico(
        label: label,
        valorInicial: valorInicial,
        permitirDecimal: permitirDecimal,
        sufijo: sufijo,
        maxValor: maxValor,
        hint: hint,
      ),
    );
  }

  @override
  State<TecladoNumerico> createState() => _TecladoNumericoState();
}

class _TecladoNumericoState extends State<TecladoNumerico> {
  String _display = '0';
  bool _soloDecimal = false; // si ya se pulsó el punto

  static const _kFondo  = Color(0xFF111827);
  static const _kCard   = Color(0xFF1F2937);
  static const _kBorder = Color(0xFF374151);
  static const _kTexto  = Colors.white;
  static const _kSub    = Color(0xFF9CA3AF);
  static const _kVerde  = Color(0xFF10B981);
  static const _kRojo   = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    if (widget.valorInicial != null && widget.valorInicial! != 0) {
      final v = widget.valorInicial!;
      _display = widget.permitirDecimal
          ? v.toStringAsFixed(2).replaceAll('.', ',')
          : v.toInt().toString();
      _soloDecimal = _display.contains(',');
    }
  }

  bool get _esValido {
    final d = double.tryParse(_display.replaceAll(',', '.')) ?? 0;
    return d >= 0 && (widget.maxValor == null || d <= widget.maxValor!);
  }

  double get _valorActual =>
      double.tryParse(_display.replaceAll(',', '.')) ?? 0;

  void _pulsar(String tecla) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (tecla) {
        case '⌫':
          if (_display.length <= 1) {
            _display = '0';
            _soloDecimal = false;
          } else {
            final nuevo = _display.substring(0, _display.length - 1);
            if (nuevo.endsWith(',')) _soloDecimal = false;
            _display = nuevo.isEmpty ? '0' : nuevo;
          }
          break;

        case 'C':
          _display = '0';
          _soloDecimal = false;
          break;

        case ',':
          if (!widget.permitirDecimal || _soloDecimal) return;
          if (_display == '0') _display = '0,';
          else _display += ',';
          _soloDecimal = true;
          break;

        case '00':
          if (_display == '0') return;
          _pulsar('0');
          _pulsar('0');
          return;

        default: // 0-9
          if (_display == '0' && tecla != ',') {
            _display = tecla;
          } else {
            // Limitar decimales a 2 posiciones
            if (_soloDecimal) {
              final partes = _display.split(',');
              if (partes.length > 1 && partes[1].length >= 2) return;
            }
            // Limitar longitud total
            if (_display.replaceAll(',', '').length >= 9) return;
            _display += tecla;
          }
      }
    });
  }

  void _confirmar() {
    if (!_esValido) return;
    Navigator.pop(context, _valorActual);
  }

  @override
  Widget build(BuildContext context) {
    final sobreMax = widget.maxValor != null && _valorActual > widget.maxValor!;
    final colorDisplay = sobreMax ? _kRojo : _kVerde;

    return Dialog(
      backgroundColor: _kFondo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Label ─────────────────────────────────────────────────────
            Row(children: [
              Text(widget.label,
                  style: const TextStyle(
                    color: _kSub, fontSize: 12, fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: _kSub, size: 18),
              ),
            ]),
            const SizedBox(height: 10),

            // ── Display ───────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorDisplay.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      _display,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: colorDisplay,
                        fontSize: 32, fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(widget.sufijo,
                      style: const TextStyle(
                        color: _kSub, fontSize: 16, fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),

            if (widget.hint != null) ...[
              const SizedBox(height: 6),
              Text(widget.hint!,
                  style: const TextStyle(color: _kSub, fontSize: 10)),
            ],
            if (sobreMax) ...[
              const SizedBox(height: 4),
              Text('Máximo: ${widget.maxValor!.toStringAsFixed(2)} ${widget.sufijo}',
                  style: const TextStyle(color: _kRojo, fontSize: 10)),
            ],
            const SizedBox(height: 14),

            // ── Teclado 4×4 ───────────────────────────────────────────────
            // Fila 1: 7 8 9 ⌫
            _fila(['7', '8', '9', '⌫']),
            const SizedBox(height: 6),
            // Fila 2: 4 5 6 C
            _fila(['4', '5', '6', 'C']),
            const SizedBox(height: 6),
            // Fila 3: 1 2 3 (vacío)
            _fila(['1', '2', '3', '']),
            const SizedBox(height: 6),
            // Fila 4: , 0 00 ✓
            _fila([
              widget.permitirDecimal ? ',' : '',
              '0',
              '00',
              '✓',
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _fila(List<String> teclas) {
    return Row(
      children: teclas.asMap().entries.map((e) {
        final i = e.key;
        final t = e.value;
        final isLast = i == 3;
        return [
          Expanded(child: _tecla(t)),
          if (!isLast) const SizedBox(width: 6),
        ];
      }).expand((x) => x).toList(),
    );
  }

  Widget _tecla(String t) {
    if (t.isEmpty) return const SizedBox.shrink();

    final isConfirm = t == '✓';
    final isClear   = t == 'C';
    final isBack    = t == '⌫';
    final isSpecial = isConfirm || isClear || isBack;

    Color bg, fg;
    if (isConfirm) {
      bg = _esValido ? _kVerde : _kBorder;
      fg = _esValido ? Colors.black : _kSub;
    } else if (isClear) {
      bg = _kRojo.withValues(alpha: 0.15);
      fg = _kRojo;
    } else if (isBack) {
      bg = _kBorder.withValues(alpha: 0.5);
      fg = _kSub;
    } else {
      bg = _kCard;
      fg = _kTexto;
    }

    return GestureDetector(
      onTap: isConfirm ? _confirmar : () => _pulsar(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isConfirm && _esValido
                ? _kVerde.withValues(alpha: 0.6)
                : _kBorder.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: t == '⌫'
              ? Icon(Icons.backspace_outlined, size: 18, color: fg)
              : Text(
                  t,
                  style: TextStyle(
                    color: fg,
                    fontSize: isSpecial ? 16 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Extensión para facilitar el uso en cualquier TextField numérico.
/// Envuelve el TextField y al pulsar muestra el teclado numérico.
class CampoNumericoTPV extends StatelessWidget {
  final String label;
  final double? valor;
  final String sufijo;
  final bool permitirDecimal;
  final double? maxValor;
  final ValueChanged<double> onCambio;

  const CampoNumericoTPV({
    super.key,
    required this.label,
    required this.valor,
    required this.onCambio,
    this.sufijo = '€',
    this.permitirDecimal = true,
    this.maxValor,
  });

  @override
  Widget build(BuildContext context) {
    final displayStr = valor == null
        ? '—'
        : (permitirDecimal
            ? '${valor!.toStringAsFixed(2)} $sufijo'
            : '${valor!.toInt()} $sufijo');

    return GestureDetector(
      onTap: () async {
        final nuevo = await TecladoNumerico.mostrar(
          context,
          label: label,
          valorInicial: valor,
          sufijo: sufijo,
          permitirDecimal: permitirDecimal,
          maxValor: maxValor,
        );
        if (nuevo != null) onCambio(nuevo);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF374151)),
        ),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(displayStr,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          const Icon(Icons.dialpad_rounded, size: 14, color: Color(0xFF6B7280)),
        ]),
      ),
    );
  }
}

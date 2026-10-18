import 'package:flutter/material.dart';
import '../../../domain/modelos/pdf_configuracion.dart';

class PdfConfigPagoTab extends StatefulWidget {
  final PdfConfiguracion cfg;
  final void Function(PdfConfiguracion) onChanged;
  const PdfConfigPagoTab({super.key, required this.cfg, required this.onChanged});

  @override
  State<PdfConfigPagoTab> createState() => _State();
}

class _State extends State<PdfConfigPagoTab> {
  late final _titular = TextEditingController(text: widget.cfg.ibanTitular ?? '');
  late final _banco   = TextEditingController(text: widget.cfg.ibanBanco ?? '');
  late final _iban    = TextEditingController(
      text: widget.cfg.iban != null ? formatearIban(widget.cfg.iban!) : '');
  late final _textoExtra = TextEditingController(text: widget.cfg.textoPagoAdicional ?? '');
  late Set<String> _metodos = Set.from(widget.cfg.metodosAceptados);
  bool _ibanError = false;

  static const _kPurple = Color(0xFF6D5EF8);

  static const _kMetodos = [
    ('transferencia', 'Transferencia bancaria', Icons.account_balance_rounded),
    ('tarjeta',       'Tarjeta',                Icons.credit_card_rounded),
    ('efectivo',      'Efectivo',               Icons.payments_rounded),
    ('bizum',         'Bizum',                  Icons.phone_android_rounded),
    ('domiciliacion', 'Domiciliación bancaria',  Icons.autorenew_rounded),
  ];

  @override
  void dispose() {
    _titular.dispose(); _banco.dispose(); _iban.dispose(); _textoExtra.dispose();
    super.dispose();
  }

  void _notify() {
    final ibanClean = _iban.text.replaceAll(' ', '');
    widget.onChanged(widget.cfg.copyWith(
      ibanTitular: _titular.text.trim().nullIfEmpty,
      ibanBanco: _banco.text.trim().nullIfEmpty,
      iban: ibanClean.nullIfEmpty,
      metodosAceptados: _metodos.toList(),
      textoPagoAdicional: _textoExtra.text.trim().nullIfEmpty,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _section('Cuenta bancaria'),
        const Text(
          'Si no hay IBAN configurado, el bloque «DATOS DE PAGO» no aparecerá en los PDFs.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        _field(_titular, 'Titular de la cuenta', 'FLUIX TECH, S.L.', onChanged: (_) => _notify()),
        _field(_banco, 'Entidad bancaria', 'CaixaBank', onChanged: (_) => _notify()),
        _ibanField(),
        const SizedBox(height: 20),

        _section('Métodos de pago aceptados'),
        const Text('Marca los métodos que quieres mostrar en facturas y presupuestos.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _kMetodos.map((m) {
            final (id, label, icon) = m;
            final selected = _metodos.contains(id);
            return FilterChip(
              avatar: Icon(icon, size: 16,
                  color: selected ? _kPurple : const Color(0xFF9CA3AF)),
              label: Text(label),
              selected: selected,
              selectedColor: const Color(0xFFEEEBFF),
              checkmarkColor: _kPurple,
              onSelected: (v) {
                setState(() { v ? _metodos.add(id) : _metodos.remove(id); });
                _notify();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        _section('Texto adicional de pago (opcional)'),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: _textoExtra,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej. Plazo: 30 días. En caso de devolución, contactar con...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
              isDense: true,
            ),
            onChanged: (_) => _notify(),
          ),
        ),
      ],
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: _kPurple, letterSpacing: 0.3)),
  );

  Widget _field(TextEditingController ctrl, String label, String hint,
      {void Function(String)? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label, hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
      );

  Widget _ibanField() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: _iban,
      decoration: InputDecoration(
        labelText: 'IBAN',
        hintText: 'ES91 2100 0418 4502 0005 1332',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        errorText: _ibanError ? 'IBAN no válido (verifique el dígito de control)' : null,
        suffixIcon: _iban.text.isNotEmpty
            ? Icon(
                _ibanError ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                color: _ibanError ? Colors.red : Colors.green, size: 20)
            : null,
      ),
      textCapitalization: TextCapitalization.characters,
      onChanged: (v) {
        final clean = v.replaceAll(' ', '');
        final formatted = formatearIban(clean);
        if (formatted != v) {
          _iban.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
        setState(() => _ibanError = clean.isNotEmpty && !validarIban(clean));
        _notify();
      },
    ),
  );
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

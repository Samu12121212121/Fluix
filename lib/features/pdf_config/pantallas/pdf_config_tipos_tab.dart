import 'package:flutter/material.dart';
import '../../../domain/modelos/pdf_configuracion.dart';

// Los 7 tipos de documento con su clave interna, emoji y si admite Verifactu
const _kTipos = <(String, String, bool)>[
  ('factura',         '🧾 Factura',              true),
  ('rectificativa',   '🔄 Rectificativa',        true),
  ('presupuesto',     '💼 Presupuesto',          false),
  ('proforma',        '📋 Proforma',             false),
  ('albaran',         '📦 Albarán',              false),
  ('fichajes',        '⏱️ Fichajes',             false),
  ('informeInterno',  '📄 Informe interno',      false),
];

class PdfConfigTiposTab extends StatelessWidget {
  final PdfConfiguracion cfg;
  final void Function(PdfConfiguracion) onChanged;
  const PdfConfigTiposTab({super.key, required this.cfg, required this.onChanged});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: _kTipos.map((t) {
      final (key, label, admiteVerifactu) = t;
      return _TipoCard(
        tipoKey: key, label: label, admiteVerifactu: admiteVerifactu,
        cfg: cfg, onChanged: onChanged,
      );
    }).toList(),
  );
}

class _TipoCard extends StatefulWidget {
  final String tipoKey;
  final String label;
  final bool admiteVerifactu;
  final PdfConfiguracion cfg;
  final void Function(PdfConfiguracion) onChanged;

  const _TipoCard({required this.tipoKey, required this.label,
      required this.admiteVerifactu, required this.cfg, required this.onChanged});

  @override
  State<_TipoCard> createState() => _TipoCardState();
}

class _TipoCardState extends State<_TipoCard> {
  bool _expanded = false;
  late ConfigTipoDocPdf _tipoCfg;
  late final TextEditingController _titulo;
  late final TextEditingController _etiqCliente;
  late final TextEditingController _diasVto;
  late final TextEditingController _pieLegal;
  late final TextEditingController _notas;
  late final TextEditingController _condiciones;

  static const _kPurple = Color(0xFF6D5EF8);

  @override
  void initState() {
    super.initState();
    _tipoCfg = widget.cfg.cfgTipo(widget.tipoKey);
    _titulo       = TextEditingController(text: _tipoCfg.titulo);
    _etiqCliente  = TextEditingController(text: _tipoCfg.etiquetaCliente);
    _diasVto      = TextEditingController(text: '${_tipoCfg.diasVencimiento}');
    _pieLegal     = TextEditingController(text: _tipoCfg.pieLegal);
    _notas        = TextEditingController(text: _tipoCfg.notasDefecto ?? '');
    _condiciones  = TextEditingController(text: _tipoCfg.condiciones ?? '');
  }

  @override
  void dispose() {
    for (final c in [_titulo, _etiqCliente, _diasVto, _pieLegal, _notas, _condiciones]) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify() {
    final updated = _tipoCfg.copyWith(
      titulo: _titulo.text.trim(),
      etiquetaCliente: _etiqCliente.text.trim(),
      diasVencimiento: int.tryParse(_diasVto.text) ?? 0,
      pieLegal: _pieLegal.text.trim(),
      notasDefecto: _notas.text.trim().nullIfEmpty,
      condiciones: _condiciones.text.trim().nullIfEmpty,
    );
    _tipoCfg = updated;
    final newCfgPorTipo = Map<String, ConfigTipoDocPdf>.from(widget.cfg.configPorTipo)
      ..[widget.tipoKey] = updated;
    widget.onChanged(widget.cfg.copyWith(configPorTipo: newCfgPorTipo));
  }

  void _toggle(String field, bool v) {
    _tipoCfg = switch (field) {
      'mostrarPago'       => _tipoCfg.copyWith(mostrarPago: v),
      'mostrarColumnaIva' => _tipoCfg.copyWith(mostrarColumnaIva: v),
      'mostrarImportes'   => _tipoCfg.copyWith(mostrarImportes: v),
      'mostrarFirma'      => _tipoCfg.copyWith(mostrarFirma: v),
      'mostrarVerifactu'  => _tipoCfg.copyWith(mostrarVerifactu: v),
      _ => _tipoCfg,
    };
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Column(children: [
        ListTile(
          title: Text(widget.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(_tipoCfg.titulo,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
              color: _kPurple),
          onTap: () => setState(() => _expanded = !_expanded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _field(_titulo, 'Título del documento')),
                const SizedBox(width: 8),
                Expanded(child: _field(_etiqCliente, 'Etiqueta del cliente')),
              ]),
              if (widget.tipoKey != 'albaran' &&
                  widget.tipoKey != 'fichajes' &&
                  widget.tipoKey != 'informeInterno')
                _field(_diasVto,
                    widget.tipoKey == 'presupuesto' || widget.tipoKey == 'proforma'
                        ? 'Días de validez' : 'Días de vencimiento',
                    isNumber: true),
              _field(_pieLegal, 'Pie legal', maxLines: 2),
              _field(_notas, 'Notas por defecto (opcional)', maxLines: 2),
              if (widget.tipoKey == 'presupuesto' || widget.tipoKey == 'proforma')
                _field(_condiciones, 'Condiciones del presupuesto (opcional)', maxLines: 3),
              const SizedBox(height: 8),
              const Text('Opciones', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _kPurple)),
              const SizedBox(height: 6),
              _switch('Mostrar bloque de pago', 'mostrarPago', _tipoCfg.mostrarPago),
              _switch('Mostrar columna IVA en tabla', 'mostrarColumnaIva', _tipoCfg.mostrarColumnaIva),
              _switch('Mostrar precios e importes', 'mostrarImportes', _tipoCfg.mostrarImportes),
              _switch('Recuadro de firma y sello', 'mostrarFirma', _tipoCfg.mostrarFirma),
              if (widget.admiteVerifactu)
                _switch('Bloque Verifactu / QR AEAT', 'mostrarVerifactu', _tipoCfg.mostrarVerifactu),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1, bool isNumber = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          onChanged: (_) => _notify(),
        ),
      );

  Widget _switch(String label, String field, bool value) => SwitchListTile.adaptive(
    value: value,
    onChanged: (v) { setState(() {}); _toggle(field, v); },
    title: Text(label, style: const TextStyle(fontSize: 13)),
    dense: true,
    activeColor: _kPurple,
    contentPadding: EdgeInsets.zero,
  );
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

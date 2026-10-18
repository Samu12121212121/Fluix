import 'package:flutter/material.dart';
import '../../../domain/modelos/pdf_configuracion.dart';

class PdfConfigEmisorTab extends StatefulWidget {
  final PdfConfiguracion cfg;
  final void Function(PdfConfiguracion) onChanged;
  final String empresaId;
  const PdfConfigEmisorTab({super.key, required this.cfg,
      required this.onChanged, required this.empresaId});

  @override
  State<PdfConfigEmisorTab> createState() => _State();
}

class _State extends State<PdfConfigEmisorTab> {
  late final _razon    = TextEditingController(text: widget.cfg.razonSocial);
  late final _comercial= TextEditingController(text: widget.cfg.nombreComercial ?? '');
  late final _cif      = TextEditingController(text: widget.cfg.cif);
  late final _nombreVia= TextEditingController(text: widget.cfg.nombreVia);
  late final _numero   = TextEditingController(text: widget.cfg.numero);
  late final _piso     = TextEditingController(text: widget.cfg.pisoPorta ?? '');
  late final _cp       = TextEditingController(text: widget.cfg.codigoPostal);
  late final _localidad= TextEditingController(text: widget.cfg.localidad);
  late final _provincia= TextEditingController(text: widget.cfg.provincia);
  late final _tel      = TextEditingController(text: widget.cfg.telefono ?? '');
  late final _email    = TextEditingController(text: widget.cfg.email ?? '');
  late final _web      = TextEditingController(text: widget.cfg.web ?? '');
  late final _regMerc  = TextEditingController(text: widget.cfg.registroMercantil ?? '');
  late String _tipoVia = widget.cfg.tipoVia;

  bool _cifError = false;

  static const _kPurple = Color(0xFF6D5EF8);

  @override
  void dispose() {
    for (final c in [_razon, _comercial, _cif, _nombreVia, _numero, _piso,
        _cp, _localidad, _provincia, _tel, _email, _web, _regMerc]) { c.dispose(); }
    super.dispose();
  }

  void _notify() => widget.onChanged(widget.cfg.copyWith(
    razonSocial: _razon.text.trim(),
    nombreComercial: _comercial.text.trim().nullIfEmpty,
    cif: _cif.text.trim().toUpperCase(),
    tipoVia: _tipoVia,
    nombreVia: _nombreVia.text.trim(),
    numero: _numero.text.trim(),
    pisoPorta: _piso.text.trim().nullIfEmpty,
    codigoPostal: _cp.text.trim(),
    localidad: _localidad.text.trim(),
    provincia: _provincia.text.trim(),
    telefono: _tel.text.trim().nullIfEmpty,
    email: _email.text.trim().nullIfEmpty,
    web: _web.text.trim().nullIfEmpty,
    registroMercantil: _regMerc.text.trim().nullIfEmpty,
  ));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _section('Identificación fiscal'),
        _field(_razon, 'Razón social *', 'FLUIX TECH, S.L.', onChanged: (_) => _notify()),
        _field(_comercial, 'Nombre comercial (opcional)', 'Fluix', onChanged: (_) => _notify()),
        _fieldCIF(),
        const SizedBox(height: 20),

        _section('Domicilio fiscal'),
        _tipoViaRow(),
        Row(children: [
          Expanded(flex: 3, child: _field(_nombreVia, 'Calle / Avenida *', 'Beleña', onChanged: (_) => _notify())),
          const SizedBox(width: 8),
          Expanded(child: _field(_numero, 'Nº *', '14', onChanged: (_) => _notify())),
          const SizedBox(width: 8),
          Expanded(child: _field(_piso, 'Piso/Pta', '2.º B', onChanged: (_) => _notify())),
        ]),
        Row(children: [
          Expanded(child: _field(_cp, 'C.P. *', '19005', onChanged: (_) => _notify())),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _field(_localidad, 'Localidad *', 'Guadalajara', onChanged: (_) => _notify())),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _field(_provincia, 'Provincia', 'Guadalajara', onChanged: (_) => _notify())),
        ]),
        const SizedBox(height: 8),
        // Preview de la dirección compuesta
        _domicilioPreview(),
        const SizedBox(height: 20),

        _section('Contacto'),
        Row(children: [
          Expanded(child: _field(_tel, 'Teléfono', '+34 949 000 000', onChanged: (_) => _notify())),
          const SizedBox(width: 8),
          Expanded(child: _field(_email, 'Email', 'info@empresa.com', onChanged: (_) => _notify())),
        ]),
        _field(_web, 'Web (opcional)', 'www.empresa.com', onChanged: (_) => _notify()),
        const SizedBox(height: 20),

        _section('Pie de página'),
        _field(_regMerc, 'Registro Mercantil (opcional)',
            'Reg. Merc. de Guadalajara, T.123, F.45, H.GU-0001', onChanged: (_) => _notify()),
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

  Widget _fieldCIF() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: _cif,
      decoration: InputDecoration(
        labelText: 'CIF / NIF *', hintText: 'B12345678',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        errorText: _cifError ? 'Formato de NIF/CIF no válido' : null,
      ),
      textCapitalization: TextCapitalization.characters,
      onChanged: (v) {
        setState(() => _cifError = v.trim().isNotEmpty && !validarNifEs(v));
        _notify();
      },
    ),
  );

  Widget _tipoViaRow() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      value: kTiposVia.contains(_tipoVia) ? _tipoVia : 'Calle',
      decoration: const InputDecoration(
        labelText: 'Tipo de vía',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      items: kTiposVia.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) { if (v != null) { setState(() => _tipoVia = v); _notify(); } },
    ),
  );

  Widget _domicilioPreview() {
    final cfg = widget.cfg.copyWith(
      tipoVia: _tipoVia, nombreVia: _nombreVia.text,
      numero: _numero.text, pisoPorta: _piso.text.nullIfEmpty,
      codigoPostal: _cp.text, localidad: _localidad.text,
    );
    final linea = cfg.domicilioCompleto;
    if (linea.trim().isEmpty || linea.trim() == '·') return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4CAFE)),
      ),
      child: Row(children: [
        const Icon(Icons.preview_rounded, size: 16, color: _kPurple),
        const SizedBox(width: 8),
        Expanded(child: Text(linea,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B48A5)))),
      ]),
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

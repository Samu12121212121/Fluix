import 'package:flutter/material.dart';
import '../negocio_theme.dart';

// ── Helpers internos ─────────────────────────────────────────────────────────
Widget _card({required bool d, required IconData icon, required Color c, required String title, String? sub, required Widget child}) {
  return Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kCard(d), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorde(d), width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: c, size: 15)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: kTexto(d), fontWeight: FontWeight.bold, fontSize: 13)),
          if (sub != null) Text(sub, style: TextStyle(color: kMuted(d), fontSize: 10)),
        ])),
      ]),
      Divider(color: kBorde(d), height: 18),
      child,
    ]),
  );
}

Widget _lbl(bool d, String t) => Padding(padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: TextStyle(color: kAccent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3)));

Widget _field(bool d, TextEditingController c, String hint, {int? maxLines, int? maxLen, IconData? icon, String? label, TextInputType? type}) => TextField(
  controller: c, maxLines: maxLines, maxLength: maxLen, keyboardType: type,
  style: TextStyle(color: kTexto(d), fontSize: 13),
  decoration: kDec(d, hint).copyWith(
    labelText: label, labelStyle: label != null ? TextStyle(color: kMuted(d), fontSize: 12) : null,
    prefixIcon: icon != null ? Icon(icon, color: kAccent, size: 17) : null,
  ),
);

Widget _switch(bool d, String label, bool val, Function(bool) fn) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(children: [
    Expanded(child: Text(label, style: TextStyle(color: kTexto(d), fontSize: 13))),
    Switch(value: val, onChanged: fn, activeColor: kAccent, activeTrackColor: kAccent.withValues(alpha: 0.25), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
  ]),
);

Future<String?> _textDialog(BuildContext ctx, bool d, String title, String hint) async {
  final c = TextEditingController();
  final r = await showDialog<String>(context: ctx, builder: (_) => AlertDialog(
    backgroundColor: kCard(d), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    title: Text(title, style: TextStyle(color: kTexto(d), fontSize: 14)),
    content: TextField(controller: c, autofocus: true, style: TextStyle(color: kTexto(d)), decoration: kDec(d, hint)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: kMuted(d)))),
      FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg(d)), child: const Text('Añadir')),
    ],
  ));
  c.dispose();
  return r;
}

Future<String?> _pickDialog(BuildContext ctx, bool d, String title, List<String> opts) => showDialog<String>(
  context: ctx, builder: (_) => AlertDialog(
    backgroundColor: kCard(d), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    title: Text(title, style: TextStyle(color: kTexto(d), fontSize: 14)),
    content: SizedBox(width: 280, child: ListView.separated(
      shrinkWrap: true, itemCount: opts.length,
      separatorBuilder: (_, __) => Divider(color: kBorde(d), height: 1),
      itemBuilder: (_, i) => ListTile(dense: true, title: Text(opts[i], style: TextStyle(color: kTexto(d), fontSize: 13)), onTap: () => Navigator.pop(ctx, opts[i])),
    )),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: kMuted(d))))],
  ),
);

Widget _chips(BuildContext ctx, bool d, List<String> items, VoidCallback onAdd, Function(String) onDel) => Wrap(
  spacing: 8, runSpacing: 8, children: [
    ...items.map((c) => Chip(
      label: Text(c, style: TextStyle(color: kTexto(d), fontSize: 11)),
      backgroundColor: kCard2(d), side: BorderSide(color: kAccent.withValues(alpha: 0.3)),
      deleteIconColor: kRosa, onDeleted: () => onDel(c), padding: const EdgeInsets.symmetric(horizontal: 2),
    )),
    ActionChip(
      avatar: Icon(Icons.add, color: kAccent, size: 13),
      label: Text('Añadir', style: TextStyle(color: kAccent, fontSize: 10)),
      backgroundColor: kCard2(d), side: BorderSide(color: kBorde(d)),
      onPressed: onAdd,
    ),
  ],
);

// ════════════════════════════════════════════════════════════════════════════
// IDENTIDAD
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionIdentidad(BuildContext ctx, {
  required bool dark,
  required TextEditingController nombreCtrl,
  required TextEditingController nombreLegalCtrl,
  required TextEditingController descCortaCtrl,
  required TextEditingController descCtrl,
  required String categoria,
  required List<String> subcategorias,
  required List<String> etiquetas,
  required List<String> idiomas,
  required List<String> publicoObjetivo,
  required List<String> fotos,
  required bool subiendo,
  required int? anioApertura,
  required String nivelPrecio,
  required void Function(String) onCatChanged,
  required void Function(List<String>) onSubcatChanged,
  required void Function(List<String>) onEtiquetasChanged,
  required void Function(List<String>) onIdiomasChanged,
  required void Function(List<String>) onPublicoChanged,
  required void Function(String) onNivelPrecioChanged,
  required void Function(int?) onAnioChanged,
  required VoidCallback onSubirFoto,
  required void Function(List<String>) onFotosChanged,
}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Fotos
    _card(d: dark, icon: Icons.photo_library_outlined, c: kAccent, title: 'Galería de Fotos', sub: 'La primera foto es la portada', child: Column(children: [
      if (subiendo) const LinearProgressIndicator(color: kAccent),
      const SizedBox(height: 4),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ...fotos.asMap().entries.map((e) => Stack(children: [
          Container(width: 88, height: 88,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: e.key == 0 ? Border.all(color: kAccent, width: 2) : null),
            child: ClipRRect(borderRadius: BorderRadius.circular(e.key == 0 ? 9 : 10),
              child: Image.network(e.value, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: kCard2(dark), child: Icon(Icons.broken_image, color: kMuted(dark))))),
          ),
          if (e.key == 0) Positioned(bottom: 3, left: 3,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(3)),
              child: Text('portada', style: TextStyle(color: kBg(dark), fontSize: 7, fontWeight: FontWeight.w800)))),
          Positioned(top: 3, right: 3, child: GestureDetector(
            onTap: () { final f = [...fotos]..removeAt(e.key); onFotosChanged(f); },
            child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 11)),
          )),
        ])),
        GestureDetector(onTap: onSubirFoto, child: Container(width: 88, height: 88,
          decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withValues(alpha: 0.4), width: 1.5)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 24, color: kAccent),
            const SizedBox(height: 3),
            Text('Añadir', style: TextStyle(color: kAccent, fontSize: 9)),
          ]),
        )),
      ]),
    ])),

    // Nombre e identidad
    _card(d: dark, icon: Icons.storefront_outlined, c: kAccent, title: 'Nombre e Identidad', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(dark, 'NOMBRE COMERCIAL *'),
      _field(dark, nombreCtrl, 'Ej: Peluquería Marina'),
      const SizedBox(height: 10),
      _lbl(dark, 'NOMBRE LEGAL'),
      _field(dark, nombreLegalCtrl, 'Ej: Marina García S.L.'),
      const SizedBox(height: 10),
      _lbl(dark, 'DESCRIPCIÓN CORTA'),
      _field(dark, descCortaCtrl, 'Una frase que te defina', maxLines: 2, maxLen: 150),
      const SizedBox(height: 10),
      _lbl(dark, 'DESCRIPCIÓN COMPLETA'),
      _field(dark, descCtrl, 'Cuéntales todo sobre tu negocio...', maxLines: 5, maxLen: 3000),
    ])),

    // Categoría
    _card(d: dark, icon: Icons.category_outlined, c: const Color(0xFF9B59B6), title: 'Categoría y Etiquetas', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(dark, 'CATEGORÍA PRINCIPAL'),
      _CategoriaSelector(dark: dark, categoria: categoria, onChanged: onCatChanged),
      const SizedBox(height: 12),
      _lbl(dark, 'SUBCATEGORÍAS'),
      _chips(ctx, dark, subcategorias, () async {
        final r = await _textDialog(ctx, dark, 'Nueva subcategoría', 'Ej: Coloración, Tratamientos...');
        if (r != null && r.isNotEmpty && !subcategorias.contains(r)) onSubcatChanged([...subcategorias, r]);
      }, (v) => onSubcatChanged([...subcategorias]..remove(v))),
      const SizedBox(height: 12),
      _lbl(dark, 'ETIQUETAS'),
      _chips(ctx, dark, etiquetas, () async {
        final r = await _textDialog(ctx, dark, 'Nueva etiqueta', 'Ej: Ecológico, Premium, 24h...');
        if (r != null && r.isNotEmpty && !etiquetas.contains(r)) onEtiquetasChanged([...etiquetas, r]);
      }, (v) => onEtiquetasChanged([...etiquetas]..remove(v))),
    ])),

    // Info adicional
    _card(d: dark, icon: Icons.info_outline_rounded, c: kAzul, title: 'Información Adicional', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'AÑO APERTURA'),
          TextFormField(
            keyboardType: TextInputType.number,
            initialValue: anioApertura?.toString() ?? '',
            style: TextStyle(color: kTexto(dark), fontSize: 13),
            decoration: kDec(dark, 'Ej: 2018'),
            onChanged: (v) => onAnioChanged(int.tryParse(v)),
          ),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'NIVEL DE PRECIO'),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: '€', label: Text('€')), ButtonSegment(value: '€€', label: Text('€€')), ButtonSegment(value: '€€€', label: Text('€€€'))],
            selected: {nivelPrecio},
            onSelectionChanged: (v) => onNivelPrecioChanged(v.first),
            style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : kCard2(dark))),
          ),
        ])),
      ]),
      const SizedBox(height: 12),
      _lbl(dark, 'IDIOMAS'),
      _chips(ctx, dark, idiomas, () async {
        final r = await _pickDialog(ctx, dark, 'Añadir idioma', const ['Español', 'Inglés', 'Francés', 'Alemán', 'Árabe', 'Italiano', 'Portugués']);
        if (r != null && !idiomas.contains(r)) onIdiomasChanged([...idiomas, r]);
      }, (v) => onIdiomasChanged([...idiomas]..remove(v))),
      const SizedBox(height: 12),
      _lbl(dark, 'PÚBLICO OBJETIVO'),
      _chips(ctx, dark, publicoObjetivo, () async {
        final r = await _pickDialog(ctx, dark, 'Añadir público', const ['Todos', 'Adultos', 'Mujeres', 'Hombres', 'Familias', 'Niños', 'Profesionales']);
        if (r != null && !publicoObjetivo.contains(r)) onPublicoChanged([...publicoObjetivo, r]);
      }, (v) => onPublicoChanged([...publicoObjetivo]..remove(v))),
    ])),
  ]);
}

class _CategoriaSelector extends StatelessWidget {
  final bool dark; final String categoria; final void Function(String) onChanged;
  const _CategoriaSelector({required this.dark, required this.categoria, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const cats = [('general','🏢','General'),('restaurantes','🍽️','Restaurante'),('peluquerias','✂️','Peluquería'),
      ('esteticas','💅','Estética'),('clinicas','🏥','Clínica'),('gimnasios','🏋️','Gimnasio'),
      ('hoteles','🏨','Hotel'),('tiendas','🛍️','Tienda'),('cafeterias','☕','Cafetería'),
      ('barberias','🪒','Barbería'),('tatuajes','🎨','Tatuaje'),('carnicerias','🥩','Carnicería')];
    return Wrap(spacing: 7, runSpacing: 7, children: cats.map((cat) {
      final sel = categoria == cat.$1;
      return ChoiceChip(
        label: Text('${cat.$2} ${cat.$3}', style: TextStyle(color: sel ? kBg(dark) : kMuted(dark), fontSize: 10)),
        selected: sel, onSelected: (_) => onChanged(cat.$1),
        selectedColor: kAccent, backgroundColor: kBg(dark),
        side: BorderSide(color: sel ? kAccent : kBorde(dark), width: sel ? 1.5 : 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 3),
      );
    }).toList());
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CONTACTO
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionContacto(BuildContext ctx, {
  required bool dark,
  required TextEditingController telefonoCtrl,
  required TextEditingController waCtrl,
  required TextEditingController emailPublicoCtrl,
  required TextEditingController emailNotiCtrl,
  required TextEditingController igCtrl,
  required TextEditingController fbCtrl,
  required TextEditingController tiktokCtrl,
  required TextEditingController youtubeCtrl,
  required TextEditingController webCtrl,
  required Map<String, bool> vis,
  required void Function(Map<String, bool>) onVisChanged,
}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _card(d: dark, icon: Icons.phone_outlined, c: kAzul, title: 'Teléfono y Mensajería', child: Column(children: [
      _field(dark, telefonoCtrl, '+34 612 345 678', icon: Icons.phone_outlined, label: 'Teléfono', type: TextInputType.phone),
      const SizedBox(height: 8),
      _field(dark, waCtrl, '+34 612 345 678', icon: Icons.chat_outlined, label: 'WhatsApp', type: TextInputType.phone),
      const SizedBox(height: 8),
      _field(dark, emailPublicoCtrl, 'info@tunegocio.com', icon: Icons.email_outlined, label: 'Email público', type: TextInputType.emailAddress),
      const SizedBox(height: 8),
      _field(dark, emailNotiCtrl, 'reservas@tunegocio.com', icon: Icons.notifications_outlined, label: 'Email notificaciones', type: TextInputType.emailAddress),
      const SizedBox(height: 8),
      _field(dark, webCtrl, 'https://tu-negocio.com', icon: Icons.language_outlined, label: 'Sitio Web', type: TextInputType.url),
    ])),
    _card(d: dark, icon: Icons.share_outlined, c: const Color(0xFF9B59B6), title: 'Redes Sociales', child: Column(children: [
      _field(dark, igCtrl, '@tu_negocio', icon: Icons.camera_alt_outlined, label: 'Instagram'),
      const SizedBox(height: 8),
      _field(dark, fbCtrl, 'facebook.com/tu-negocio', icon: Icons.facebook, label: 'Facebook'),
      const SizedBox(height: 8),
      _field(dark, tiktokCtrl, '@tu_negocio', icon: Icons.music_note_outlined, label: 'TikTok'),
      const SizedBox(height: 8),
      _field(dark, youtubeCtrl, 'youtube.com/@tu-negocio', icon: Icons.play_circle_outline, label: 'YouTube'),
    ])),
    _card(d: dark, icon: Icons.visibility_outlined, c: kAccent, title: 'Mostrar en ficha pública', sub: 'Solo ven los datos que actives', child: Column(children: [
      _switch(dark, 'Teléfono',   vis['telefono']  ?? true,  (v) { final m = {...vis}; m['telefono']  = v; onVisChanged(m); }),
      _switch(dark, 'WhatsApp',   vis['whatsapp']  ?? true,  (v) { final m = {...vis}; m['whatsapp']  = v; onVisChanged(m); }),
      _switch(dark, 'Email',      vis['email']     ?? false, (v) { final m = {...vis}; m['email']     = v; onVisChanged(m); }),
      _switch(dark, 'Web',        vis['web']       ?? true,  (v) { final m = {...vis}; m['web']       = v; onVisChanged(m); }),
      _switch(dark, 'Instagram',  vis['instagram'] ?? true,  (v) { final m = {...vis}; m['instagram'] = v; onVisChanged(m); }),
      _switch(dark, 'Facebook',   vis['facebook']  ?? true,  (v) { final m = {...vis}; m['facebook']  = v; onVisChanged(m); }),
      _switch(dark, 'TikTok',     vis['tiktok']    ?? true,  (v) { final m = {...vis}; m['tiktok']    = v; onVisChanged(m); }),
      _switch(dark, 'YouTube',    vis['youtube']   ?? true,  (v) { final m = {...vis}; m['youtube']   = v; onVisChanged(m); }),
      Divider(color: kBorde(dark), height: 16),
      Text('Botones de acción', style: TextStyle(color: kMuted(dark), fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      _switch(dark, 'Botón Llamar',      vis['btn_llamar'] ?? true, (v) { final m = {...vis}; m['btn_llamar'] = v; onVisChanged(m); }),
      _switch(dark, 'Botón WhatsApp',    vis['btn_wa']     ?? true, (v) { final m = {...vis}; m['btn_wa']     = v; onVisChanged(m); }),
      _switch(dark, 'Botón Visitar Web', vis['btn_web']    ?? true, (v) { final m = {...vis}; m['btn_web']    = v; onVisChanged(m); }),
    ])),
  ]);
}

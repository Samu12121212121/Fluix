import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../negocio_theme.dart';

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

Widget _toggle(bool d, String lbl, bool val, Function(bool) fn) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(children: [
    Expanded(child: Text(lbl, style: TextStyle(color: kTexto(d), fontSize: 13))),
    Switch(value: val, onChanged: fn, activeColor: kAccent, activeTrackColor: kAccent.withValues(alpha: 0.25), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
  ]),
);

// ════════════════════════════════════════════════════════════════════════════
// PROFESIONALES
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionProfesionales(BuildContext ctx, {
  required bool dark, required String empresaId,
  required bool mostrarEquipo, required bool permitirElegir,
  required void Function(bool) onMostrarEquipoChanged,
  required void Function(bool) onPermitirElegirChanged,
}) {
  return Column(children: [
    _card(d: dark, icon: Icons.people_outline, c: kAzul, title: 'Equipo de Profesionales', sub: 'Los clientes podrán elegir profesional al reservar', child: Column(children: [
      _toggle(dark, 'Mostrar equipo en perfil público', mostrarEquipo, onMostrarEquipoChanged),
      _toggle(dark, 'Permitir elegir profesional al reservar', permitirElegir, onPermitirElegirChanged),
    ])),
    _card(d: dark, icon: Icons.person_outline_rounded, c: kAzul, title: 'Miembros del Equipo', sub: 'Gestiona los profesionales desde el módulo Empleados',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('empleados').snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('Sin profesionales configurados', style: TextStyle(color: kMuted(dark), fontSize: 13))));
          return Column(children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final nombre = data['nombre'] as String? ?? '';
            final cargo  = data['cargo'] as String? ?? '';
            return ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 16, backgroundColor: kAzul.withValues(alpha: 0.15), child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?', style: const TextStyle(color: kAzul, fontWeight: FontWeight.bold, fontSize: 13))),
              title: Text(nombre, style: TextStyle(color: kTexto(dark), fontSize: 12)),
              subtitle: cargo.isNotEmpty ? Text(cargo, style: TextStyle(color: kMuted(dark), fontSize: 10)) : null,
            );
          }).toList());
        },
      ),
    ),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// RESEÑAS
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionResenas(BuildContext ctx, {
  required bool dark, required String? negocioId, required String empresaId,
  required bool mostrarResenasGoogle, required bool mostrarResenasFluix, required bool permitirResenas,
  required void Function(bool) onGoogleChanged,
  required void Function(bool) onFluixChanged,
  required void Function(bool) onPermitirChanged,
  required void Function(String, {bool error}) snack,
}) {
  return Column(children: [
    _card(d: dark, icon: Icons.star_outline_rounded, c: kOro, title: 'Configuración de Reseñas', child: Column(children: [
      _toggle(dark, 'Mostrar reseñas de Google', mostrarResenasGoogle, onGoogleChanged),
      _toggle(dark, 'Mostrar reseñas de Fluix', mostrarResenasFluix, onFluixChanged),
      _toggle(dark, 'Permitir nuevas reseñas', permitirResenas, onPermitirChanged),
    ])),
    _card(d: dark, icon: Icons.rate_review_outlined, c: kOro, title: 'Reseñas Fluix', sub: 'Ver y responder reseñas de clientes',
      child: StreamBuilder<QuerySnapshot>(
        stream: negocioId != null ? FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('valoraciones').where('origen', isEqualTo: 'fluix').limit(3).snapshots() : const Stream.empty(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          final total = docs.length;
          final media = total == 0 ? 0.0 : docs.fold(0.0, (a, d) => a + ((d.data() as Map)['estrellas'] as num? ?? 0).toDouble()) / total;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (total > 0) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kOro.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(9), border: Border.all(color: kOro.withValues(alpha: 0.25))),
              child: Row(children: [
                Text(media.toStringAsFixed(1), style: TextStyle(color: kOro, fontSize: 28, fontWeight: FontWeight.bold, height: 1)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: List.generate(5, (i) => Icon(i < media.round() ? Icons.star_rounded : Icons.star_border_rounded, color: kOro, size: 13))),
                  Text('$total reseña${total == 1 ? '' : 's'}', style: TextStyle(color: kMuted(dark), fontSize: 10)),
                ]),
              ]),
            ),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: negocioId == null ? null : () => snack('Abre el módulo Reseñas para gestionar'),
              icon: Icon(total > 0 ? Icons.reply_rounded : Icons.add_rounded, color: kOro, size: 14),
              label: Text(total > 0 ? 'Ver y responder ($total)' : 'Añadir primera reseña', style: TextStyle(color: kOro, fontWeight: FontWeight.w600, fontSize: 12)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: kOro.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(vertical: 10)),
            )),
          ]);
        },
      ),
    ),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// GALERÍA
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionGaleria(BuildContext ctx, {
  required bool dark, required List<String> fotos,
  required bool subiendo, required VoidCallback onSubirFoto,
  required void Function(List<String>) onFotosChanged,
}) {
  return _card(d: dark, icon: Icons.photo_library_outlined, c: kRosa, title: 'Galería del Negocio', sub: 'La primera foto es la portada en Explorar', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (subiendo) const LinearProgressIndicator(color: kAccent),
    const SizedBox(height: 4),
    Wrap(spacing: 8, runSpacing: 8, children: [
      ...fotos.asMap().entries.map((e) => Stack(children: [
        Container(width: 96, height: 96,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: e.key == 0 ? Border.all(color: kAccent, width: 2) : null),
          child: ClipRRect(borderRadius: BorderRadius.circular(e.key == 0 ? 9 : 10), child: Image.network(e.value, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: kCard2(dark), child: Icon(Icons.broken_image, color: kMuted(dark))))),
        ),
        if (e.key == 0) Positioned(bottom: 3, left: 3, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(3)), child: Text('portada', style: TextStyle(color: kBg(dark), fontSize: 7, fontWeight: FontWeight.w800)))),
        Positioned(top: 3, right: 3, child: GestureDetector(onTap: () { final f = [...fotos]..removeAt(e.key); onFotosChanged(f); }, child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 11)))),
      ])),
      GestureDetector(onTap: onSubirFoto, child: Container(width: 96, height: 96,
        decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withValues(alpha: 0.4), width: 1.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_photo_alternate_outlined, size: 26, color: kAccent), const SizedBox(height: 3), Text('Añadir', style: TextStyle(color: kAccent, fontSize: 10))]),
      )),
    ]),
    if (fotos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${fotos.length} foto${fotos.length == 1 ? '' : 's'} · La primera es la portada', style: TextStyle(color: kMuted(dark), fontSize: 10))),
  ]));
}

// ════════════════════════════════════════════════════════════════════════════
// POLÍTICAS
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionPoliticas(BuildContext ctx, {
  required bool dark, required String? negocioId, required String negocioNombre,
  required void Function(String, {bool error}) snack,
}) {
  return Column(children: [
    _card(d: dark, icon: Icons.gavel_outlined, c: const Color(0xFF718096), title: 'Términos y Condiciones', sub: 'El cliente los acepta al confirmar una reserva', child: Column(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [Icon(Icons.info_outline_rounded, color: kMuted(dark), size: 14), const SizedBox(width: 8), Expanded(child: Text('Los T&C se editan con editor de texto enriquecido.', style: TextStyle(color: kMuted(dark), fontSize: 11, height: 1.4)))])),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: negocioId == null ? null : () => snack('Abre la sección de Términos y Condiciones del negocio'),
        icon: const Icon(Icons.edit_outlined, size: 14),
        label: const Text('Editar Términos y Condiciones', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        style: FilledButton.styleFrom(backgroundColor: kCard2(dark), foregroundColor: kAccent, side: BorderSide(color: kBorde(dark), width: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(vertical: 11)),
      )),
      if (negocioId == null) Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: Text('Guarda el perfil primero', style: TextStyle(color: kMuted(dark), fontSize: 10)))),
    ])),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// PAGOS Y CONFIANZA
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionPagos(BuildContext ctx, {
  required bool dark,
  required TextEditingController razonSocialCtrl,
  required TextEditingController nifCifCtrl,
  required List<String> metodosPago,
  required bool pagosOnline,
  required bool preciosConImpuestos,
  required bool facturaDisponible,
  required void Function(List<String>) onMetodosChanged,
  required void Function(bool) onPagosOnlineChanged,
  required void Function(bool) onImpuestosChanged,
  required void Function(bool) onFacturaChanged,
}) {
  const metodos = ['Efectivo', 'Tarjeta', 'Bizum', 'PayPal', 'Stripe', 'Transferencia'];
  return Column(children: [
    _card(d: dark, icon: Icons.business_outlined, c: const Color(0xFF27AE60), title: 'Datos Fiscales', sub: 'Solo si procede mostrarlo en tu ficha pública', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(dark, 'RAZÓN SOCIAL'),
      TextField(controller: razonSocialCtrl, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'Ej: Marina García S.L.')),
      const SizedBox(height: 8),
      _lbl(dark, 'NIF / CIF'),
      TextField(controller: nifCifCtrl, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'Ej: B12345678')),
    ])),
    _card(d: dark, icon: Icons.payments_outlined, c: const Color(0xFF27AE60), title: 'Métodos de Pago y Facturación', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: metodos.map((m) {
        final sel = metodosPago.contains(m);
        return FilterChip(
          label: Text(m, style: TextStyle(color: sel ? Colors.white : kTexto(dark), fontSize: 11)),
          selected: sel, onSelected: (v) => onMetodosChanged(v ? [...metodosPago, m] : ([...metodosPago]..remove(m))),
          selectedColor: const Color(0xFF27AE60), backgroundColor: kCard2(dark),
          side: BorderSide(color: sel ? const Color(0xFF27AE60) : kBorde(dark)), checkmarkColor: Colors.white, padding: EdgeInsets.zero,
        );
      }).toList()),
      const SizedBox(height: 10),
      _toggle(dark, 'Pagos online activados', pagosOnline, onPagosOnlineChanged),
      _toggle(dark, 'Precios incluyen impuestos (IVA)', preciosConImpuestos, onImpuestosChanged),
      _toggle(dark, 'Factura disponible', facturaDisponible, onFacturaChanged),
    ])),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// DISEÑO
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionDiseno(BuildContext ctx, {
  required bool dark,
  required TextEditingController textoBienvenidaCtrl,
  required TextEditingController msgPromoCtrl,
}) {
  return _card(d: dark, icon: Icons.palette_outlined, c: const Color(0xFF9B59B6), title: 'Apariencia y Mensajes', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl(dark, 'TEXTO DE BIENVENIDA'),
    TextField(controller: textoBienvenidaCtrl, maxLines: 2, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'Ej: ¡Bienvenido a nuestra peluquería!')),
    const SizedBox(height: 10),
    _lbl(dark, 'MENSAJE PROMOCIONAL'),
    TextField(controller: msgPromoCtrl, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'Ej: Esta semana: 20% en coloraciones')),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF9B59B6).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFF9B59B6).withValues(alpha: 0.3))),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF9B59B6), size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text('Personalización de colores disponible próximamente', style: TextStyle(color: kMuted(dark), fontSize: 11))),
      ]),
    ),
  ]));
}

// ════════════════════════════════════════════════════════════════════════════
// PROMOCIONES
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionPromociones(BuildContext ctx, {
  required bool dark, required String? negocioId,
  required void Function(String, {bool error}) snack,
}) {
  return _card(d: dark, icon: Icons.local_offer_outlined, c: const Color(0xFFFF9800), title: 'Promociones', sub: 'Ofertas especiales visibles en tu ficha pública', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (negocioId != null)
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('negocios_publicos').doc(negocioId).collection('promociones').snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Sin promociones activas', style: TextStyle(color: kMuted(dark), fontSize: 12)));
          return Column(children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.local_offer_rounded, color: Color(0xFFFF9800), size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(data['nombre'] as String? ?? '', style: TextStyle(color: kTexto(dark), fontSize: 12))),
                if (data['precio_promo'] != null) Text('€${data['precio_promo']}', style: const TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            );
          }).toList());
        },
      ),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: FilledButton.icon(
      onPressed: negocioId == null ? null : () { final nc = TextEditingController(); final dc = TextEditingController(); final pc = TextEditingController(); final ppc = TextEditingController();
        showDialog(context: ctx, builder: (_) => AlertDialog(
          backgroundColor: kCard(dark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          title: Text('Nueva promoción', style: TextStyle(color: kTexto(dark), fontSize: 14, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nc, autofocus: true, style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Nombre de la promoción *')),
            const SizedBox(height: 8),
            TextField(controller: dc, maxLines: 2, style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Descripción')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: pc, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Precio original €'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: ppc, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Precio promo €'))),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: kMuted(dark)))),
            FilledButton(onPressed: () async {
              if (nc.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('negocios_publicos').doc(negocioId).collection('promociones').add({'nombre': nc.text.trim(), 'descripcion': dc.text.trim(), if (double.tryParse(pc.text) != null) 'precio_original': double.parse(pc.text), if (double.tryParse(ppc.text) != null) 'precio_promo': double.parse(ppc.text), 'activo': true, 'creado_en': FieldValue.serverTimestamp()});
              snack('✅ Promoción creada');
            }, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white), child: const Text('Crear')),
          ],
        )).then((_) { nc.dispose(); dc.dispose(); pc.dispose(); ppc.dispose(); }); },
      icon: const Icon(Icons.add_rounded, size: 14),
      label: const Text('Crear promoción', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(vertical: 11)),
    )),
  ]));
}

// ════════════════════════════════════════════════════════════════════════════
// SEO
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionSeo(BuildContext ctx, {
  required bool dark,
  required TextEditingController urlPublicaCtrl,
  required TextEditingController tituloSeoCtrl,
  required TextEditingController descSeoCtrl,
  required List<String> palabrasClave,
  required bool indexarExternamente,
  required bool aparecerEnResultados,
  required void Function(List<String>) onPalabrasChanged,
  required void Function(bool) onIndexarChanged,
  required void Function(bool) onAparecerChanged,
}) {
  return _card(d: dark, icon: Icons.search_rounded, c: kAzul, title: 'SEO y Buscadores', sub: 'Cómo aparece tu negocio en búsquedas', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl(dark, 'URL PÚBLICA'),
    TextField(controller: urlPublicaCtrl, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'mi-peluqueria-guadalajara')),
    const SizedBox(height: 8),
    _lbl(dark, 'TÍTULO SEO (máx 60 chars)'),
    TextField(controller: tituloSeoCtrl, maxLength: 60, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'Peluquería en Guadalajara | Nombre del negocio')),
    const SizedBox(height: 8),
    _lbl(dark, 'DESCRIPCIÓN SEO (máx 160 chars)'),
    TextField(controller: descSeoCtrl, maxLines: 3, maxLength: 160, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'Descripción de 160 caracteres que aparece en Google...')),
    const SizedBox(height: 8),
    _lbl(dark, 'PALABRAS CLAVE'),
    Wrap(spacing: 7, runSpacing: 7, children: [
      ...palabrasClave.map((c) => Chip(
        label: Text(c, style: TextStyle(color: kTexto(dark), fontSize: 11)),
        backgroundColor: kCard2(dark), side: BorderSide(color: kAzul.withValues(alpha: 0.3)),
        deleteIconColor: kRosa, onDeleted: () => onPalabrasChanged([...palabrasClave]..remove(c)), padding: EdgeInsets.zero,
      )),
      ActionChip(
        avatar: const Icon(Icons.add, color: kAzul, size: 13),
        label: Text('Añadir', style: TextStyle(color: kAzul, fontSize: 10)),
        backgroundColor: kCard2(dark), side: BorderSide(color: kBorde(dark)),
        onPressed: () async {
          final c = TextEditingController();
          final r = await showDialog<String>(context: ctx, builder: (_) => AlertDialog(
            backgroundColor: kCard(dark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            title: Text('Nueva palabra clave', style: TextStyle(color: kTexto(dark))),
            content: TextField(controller: c, autofocus: true, style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Ej: peluquería guadalajara')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), style: FilledButton.styleFrom(backgroundColor: kAzul, foregroundColor: Colors.white), child: const Text('Añadir'))],
          ));
          c.dispose();
          if (r != null && r.isNotEmpty && !palabrasClave.contains(r)) onPalabrasChanged([...palabrasClave, r]);
        },
      ),
    ]),
    const SizedBox(height: 10),
    _toggle(dark, 'Aparecer en resultados de Fluix', aparecerEnResultados, onAparecerChanged),
    _toggle(dark, 'Indexación externa (Google, Bing...)', indexarExternamente, onIndexarChanged),
  ]));
}

// ════════════════════════════════════════════════════════════════════════════
// VISIBILIDAD
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionVisibilidad(BuildContext ctx, {
  required bool dark,
  required Map<String, bool> vis,
  required void Function(Map<String, bool>) onVisChanged,
}) {
  const secciones = [
    ('descripcion', 'Descripción del negocio'),
    ('contacto', 'Datos de contacto'),
    ('horarios', 'Horarios de apertura'),
    ('ubicacion', 'Dirección y mapa'),
    ('servicios', 'Catálogo de servicios'),
    ('reservas', 'Botón de reserva'),
    ('agenda', 'Agenda de disponibilidad'),
    ('profesionales', 'Equipo de profesionales'),
    ('resenas_google', 'Reseñas de Google'),
    ('resenas_fluix', 'Reseñas de Fluix'),
    ('galeria', 'Galería de fotos'),
    ('promociones', 'Promociones activas'),
    ('politicas', 'Políticas del negocio'),
    ('redes_sociales', 'Redes sociales'),
  ];
  return _card(d: dark, icon: Icons.visibility_outlined, c: kAccent, title: 'Visibilidad de Secciones', sub: 'Controla qué ven los clientes en tu ficha pública', child: Column(children: secciones.map((s) => _toggle(dark, s.$2, vis[s.$1] ?? true, (v) { final m = {...vis}; m[s.$1] = v; onVisChanged(m); })).toList()));
}

// ════════════════════════════════════════════════════════════════════════════
// PESTAÑAS DE LA FICHA
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionTabs(BuildContext ctx, {
  required bool dark,
  required Map<String, bool> vis,
  required void Function(Map<String, bool>) onVisChanged,
}) {
  const tabs = [
    ('tab_servicios', 'Servicios / Reservas'),
    ('tab_resenas',   'Reseñas'),
    ('tab_productos', 'Productos'),
    ('tab_equipo',    'Equipo'),
    ('tab_galeria',   'Galería'),
    ('tab_ofertas',   'Ofertas Flash'),
    ('tab_politicas', 'Políticas'),
  ];
  return _card(
    d: dark, icon: Icons.tab_rounded, c: kRosa,
    title: 'Pestañas del perfil público',
    sub: 'Activa solo las pestañas que quieres mostrar a los clientes',
    child: Column(children: tabs.map((t) => _toggle(
      dark, t.$2, vis[t.$1] ?? true,
      (v) { final m = {...vis}; m[t.$1] = v; onVisChanged(m); }
    )).toList()),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ESTADÍSTICAS
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionEstadisticas(BuildContext ctx, {
  required bool dark, required String? negocioId,
}) {
  if (negocioId == null) {
    return _card(d: dark, icon: Icons.bar_chart_rounded, c: kOro, title: 'Estadísticas', child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(child: Column(children: [Icon(Icons.bar_chart_rounded, color: kMuted(dark), size: 32), const SizedBox(height: 8), Text('Activa tu perfil para ver estadísticas', style: TextStyle(color: kMuted(dark), fontSize: 13))])),
    ));
  }
  const stats = [
    ('Visitas a la ficha', Icons.remove_red_eye_outlined, kAccent),
    ('Clics en Reservar', Icons.calendar_month_outlined, kRosa),
    ('Reservas completadas', Icons.check_circle_outlined, Color(0xFF27AE60)),
    ('Clics en Teléfono', Icons.phone_outlined, kAzul),
    ('Clics en WhatsApp', Icons.chat_outlined, Color(0xFF27AE60)),
    ('Clics en Cómo llegar', Icons.map_outlined, Color(0xFFFF9800)),
    ('Visitas a Galería', Icons.photo_library_outlined, kRosa),
    ('Viz. Servicios', Icons.content_cut_outlined, kAccent),
  ];
  return _card(d: dark, icon: Icons.bar_chart_rounded, c: kOro, title: 'Estadísticas de tu Ficha', sub: 'Últimos 30 días', child: Column(children: [
    GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.4),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final st = stats[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: st.$3.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(9), border: Border.all(color: st.$3.withValues(alpha: 0.2))),
          child: Row(children: [
            Icon(st.$2, color: st.$3, size: 14),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('—', style: TextStyle(color: st.$3, fontSize: 15, fontWeight: FontWeight.w800)),
              Text(st.$1, style: TextStyle(color: kMuted(dark), fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ]),
        );
      },
    ),
    const SizedBox(height: 8),
    Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [Icon(Icons.info_outline_rounded, color: kMuted(dark), size: 13), const SizedBox(width: 7), Expanded(child: Text('Estadísticas en tiempo real disponibles próximamente', style: TextStyle(color: kMuted(dark), fontSize: 10)))])),
  ]));
}

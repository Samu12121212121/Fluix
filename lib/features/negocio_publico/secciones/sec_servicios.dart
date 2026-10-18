import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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
// SERVICIOS
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionServicios(BuildContext ctx, {
  required bool dark,
  required String? negocioId,
  required String empresaId,
  required void Function(String, {bool error}) snack,
}) {
  if (negocioId == null) {
    return _card(d: dark, icon: Icons.content_cut_outlined, c: kRosa, title: 'Catálogo de Servicios', child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Column(children: [
        Icon(Icons.content_cut_outlined, color: kMuted(dark), size: 32),
        const SizedBox(height: 8),
        Text('Activa tu perfil público primero', style: TextStyle(color: kMuted(dark), fontSize: 13)),
      ])),
    ));
  }

  return _card(d: dark, icon: Icons.content_cut_outlined, c: kRosa, title: 'Catálogo de Servicios', sub: 'Los clientes los ven en tu perfil al reservar',
    child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('servicios').where('activo', isNotEqualTo: false).orderBy('activo').orderBy('nombre').snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)));
        final docs = snap.data?.docs ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (docs.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Column(children: [Icon(Icons.spa_outlined, color: kMuted(dark), size: 28), const SizedBox(height: 6), Text('Sin servicios todavía', style: TextStyle(color: kMuted(dark), fontSize: 13))])))
          else ...[
            ...docs.asMap().entries.map((e) => _ItemServicio(doc: e.value, idx: e.key, dark: dark, negocioId: negocioId, empresaId: empresaId, ctx: ctx, snack: snack)),
            Padding(padding: const EdgeInsets.only(top: 4, bottom: 2), child: Text('${docs.length} servicio${docs.length == 1 ? '' : 's'}', style: TextStyle(color: kMuted(dark), fontSize: 10))),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: () => _showServicioDialog(ctx, dark: dark, negocioId: negocioId, empresaId: empresaId, orden: docs.length, snack: snack),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Añadir servicio', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: FilledButton.styleFrom(backgroundColor: kRosa, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(vertical: 11)),
            )),
          ]),
        ]);
      },
    ),
  );
}

class _ItemServicio extends StatelessWidget {
  final QueryDocumentSnapshot doc; final int idx; final bool dark;
  final String negocioId; final String empresaId; final BuildContext ctx;
  final void Function(String, {bool error}) snack;
  const _ItemServicio({required this.doc, required this.idx, required this.dark, required this.negocioId, required this.empresaId, required this.ctx, required this.snack});
  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final nombre = data['nombre'] as String? ?? '';
    final cat    = data['categoria'] as String? ?? '';
    final precio = data['precio'] as num?;
    final precD  = data['precio_desde'] as num?;
    final dur    = data['duracion'] as int?;
    final activo = data['activo'] as bool? ?? true;
    final precTxt = precio != null ? '€${precio.toStringAsFixed(precio % 1 == 0 ? 0 : 2)}'
        : precD != null ? 'Desde €${precD.toStringAsFixed(precD % 1 == 0 ? 0 : 2)}' : 'Consultar';
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorde(dark), width: 0.5)),
      child: Row(children: [
        Container(width: 3, height: 56, decoration: BoxDecoration(color: activo ? kRosa : kBorde(dark), borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)))),
        const SizedBox(width: 10),
        Expanded(child: Opacity(opacity: activo ? 1 : 0.5, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(nombre, style: TextStyle(color: kTexto(dark), fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            if (cat.isNotEmpty) Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: kRosa.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(cat, style: TextStyle(color: kRosa, fontSize: 8, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Text(precTxt, style: TextStyle(color: kRosa, fontSize: 12, fontWeight: FontWeight.w700)),
            if (dur != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.access_time_rounded, size: 10, color: kMuted(dark)),
              const SizedBox(width: 2),
              Text(dur >= 60 ? '${dur ~/ 60}h${dur % 60 > 0 ? '${dur % 60}m' : ''}' : '${dur}min', style: TextStyle(color: kMuted(dark), fontSize: 10)),
            ],
          ]),
        ])))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: () => _showServicioDialog(ctx, dark: dark, negocioId: negocioId, empresaId: empresaId, doc: doc, orden: idx, snack: snack),
              icon: Icon(Icons.edit_outlined, size: 14, color: kAccent), padding: const EdgeInsets.all(5), constraints: const BoxConstraints()),
          IconButton(onPressed: () => _deleteServicio(ctx, dark: dark, empresaId: empresaId, docId: doc.id, nombre: nombre, snack: snack),
              icon: const Icon(Icons.delete_outline, size: 14, color: kRojo), padding: const EdgeInsets.all(5), constraints: const BoxConstraints()),
        ]),
        const SizedBox(width: 3),
      ]),
    );
  }
}

Future<void> _showServicioDialog(BuildContext ctx, {required bool dark, required String? negocioId, required String empresaId, QueryDocumentSnapshot? doc, required int orden, required void Function(String, {bool error}) snack}) async {
  final data = doc?.data() as Map<String, dynamic>?;
  final nCtrl = TextEditingController(text: data?['nombre'] ?? '');
  final dCtrl = TextEditingController(text: data?['descripcion'] ?? '');
  final cCtrl = TextEditingController(text: data?['categoria'] ?? '');
  final pCtrl = TextEditingController(text: data?['precio']?.toString() ?? '');
  final pdCtrl = TextEditingController(text: data?['precio_desde']?.toString() ?? '');
  String? fotoUrl = data?['imagen_url'] as String?;
  bool usaDesde = data?['precio_desde'] != null;
  bool subF = false;
  int dur = data?['duracion'] as int? ?? 60;
  String pub = data?['publico'] as String? ?? 'todos';
  bool activo = data?['activo'] as bool? ?? true;

  await showDialog(context: ctx, builder: (_) => StatefulBuilder(builder: (ctx2, setSt) => Dialog(
    backgroundColor: kCard(dark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
      child: Column(children: [
        Container(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), decoration: BoxDecoration(color: kRosa.withValues(alpha: 0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          child: Row(children: [
            const Icon(Icons.content_cut_rounded, color: kRosa, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(doc == null ? 'Nuevo servicio' : 'Editar servicio', style: TextStyle(color: kTexto(dark), fontSize: 14, fontWeight: FontWeight.bold))),
            Row(children: [
              Text(activo ? 'Visible' : 'Oculto', style: TextStyle(color: activo ? kAccent : kMuted(dark), fontSize: 10)),
              Transform.scale(scale: 0.8, child: Switch(value: activo, onChanged: (v) => setSt(() => activo = v), activeColor: kAccent, activeTrackColor: kAccent.withValues(alpha: 0.25), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
            ]),
          ]),
        ),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'NOMBRE *'),
          TextField(controller: nCtrl, autofocus: true, style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Ej: Corte de cabello mujer')),
          const SizedBox(height: 10),
          _lbl(dark, 'DESCRIPCIÓN'),
          TextField(controller: dCtrl, maxLines: 2, style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Breve descripción')),
          const SizedBox(height: 10),
          _lbl(dark, 'CATEGORÍA'),
          TextField(controller: cCtrl, style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Ej: Corte, Color...')),
          const SizedBox(height: 10),
          _lbl(dark, 'FOTO'),
          GestureDetector(
            onTap: subF ? null : () async {
              Uint8List? bytes; String ext = 'jpg';
              try {
                final esDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
                if (esDesktop) {
                  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true, allowMultiple: false);
                  if (r == null || r.files.isEmpty) return;
                  bytes = r.files.first.bytes; ext = r.files.first.extension ?? 'jpg';
                } else {
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
                  if (img == null) return;
                  bytes = await img.readAsBytes(); ext = img.path.split('.').last;
                }
                if (bytes == null) return;
                setSt(() => subF = true);
                final ref = FirebaseStorage.instance.ref('negocios_publicos/$negocioId/servicios/${DateTime.now().millisecondsSinceEpoch}.$ext');
                await ref.putData(bytes, SettableMetadata(contentType: ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg'));
                fotoUrl = await ref.getDownloadURL();
                setSt(() => subF = false);
              } catch (e) { setSt(() => subF = false); }
            },
            child: Container(height: 72, decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(9), border: Border.all(color: fotoUrl != null ? kAccent.withValues(alpha: 0.4) : kBorde(dark))),
              child: subF ? const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))
                  : fotoUrl != null
                  ? Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl!, fit: BoxFit.cover, width: double.infinity, height: 72)),
                Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => setSt(() => fotoUrl = null),
                    child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 11)))),
              ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_outlined, color: kAccent, size: 22),
                const SizedBox(height: 3),
                Text('Toca para añadir foto', style: TextStyle(color: kAccent, fontSize: 10)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _lbl(dark, 'PRECIO'),
                const SizedBox(width: 6),
                GestureDetector(onTap: () => setSt(() => usaDesde = !usaDesde),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: usaDesde ? kAccent.withValues(alpha: 0.15) : kCard2(dark), borderRadius: BorderRadius.circular(20), border: Border.all(color: usaDesde ? kAccent : kBorde(dark))),
                      child: Text('Desde', style: TextStyle(color: usaDesde ? kAccent : kMuted(dark), fontSize: 8, fontWeight: FontWeight.w700)))),
              ]),
              TextField(controller: usaDesde ? pdCtrl : pCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: kTexto(dark), fontSize: 12), decoration: kDec(dark, 'Precio €')),
            ])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl(dark, 'DURACIÓN'),
              Row(children: [
                Expanded(child: Slider(value: dur.toDouble(), min: 10, max: 240, divisions: 23, activeColor: kRosa, inactiveColor: kBorde(dark), onChanged: (v) => setSt(() => dur = v.toInt()))),
                Text(dur >= 60 ? '${dur ~/ 60}h${dur % 60 > 0 ? '${dur % 60}m' : ''}' : '${dur}m', style: const TextStyle(color: kRosa, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ])),
          ]),
          const SizedBox(height: 10),
          _lbl(dark, 'PÚBLICO'),
          Row(children: [
            for (final opt in [('todos','Todos',kAccent),('femenino','Mujer',kRosa),('masculino','Hombre',kAzul)])
              Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(onTap: () => setSt(() => pub = opt.$1),
                child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: pub == opt.$1 ? opt.$3.withValues(alpha: 0.1) : kCard2(dark), borderRadius: BorderRadius.circular(9), border: Border.all(color: pub == opt.$1 ? opt.$3 : kBorde(dark), width: pub == opt.$1 ? 1.5 : 0.5)),
                  child: Text(opt.$2, textAlign: TextAlign.center, style: TextStyle(color: pub == opt.$1 ? opt.$3 : kMuted(dark), fontSize: 11, fontWeight: pub == opt.$1 ? FontWeight.w700 : FontWeight.w400)),
                ),
              ))),
          ]),
        ]))),
        Container(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx2),
              style: OutlinedButton.styleFrom(side: BorderSide(color: kBorde(dark)), foregroundColor: kMuted(dark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text('Cancelar', style: TextStyle(fontSize: 12)))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: FilledButton(
            onPressed: () async {
              final nombre = nCtrl.text.trim();
              if (nombre.isEmpty) return;
              final pVal = double.tryParse((usaDesde ? pdCtrl : pCtrl).text.trim());
              final datos = <String, dynamic>{'nombre': nombre, 'descripcion': dCtrl.text.trim(), 'categoria': cCtrl.text.trim(), 'duracion': dur, 'publico': pub, 'activo': activo, 'orden': orden, if (fotoUrl != null) 'imagen_url': fotoUrl};
              if (pVal != null) { if (usaDesde) datos['precio_desde'] = pVal; else datos['precio'] = pVal; }
              Navigator.pop(ctx2);
              try {
                final col = FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('servicios');
                if (doc == null) await col.add(datos); else await col.doc(doc.id).update(datos);
                snack(doc == null ? '✅ Servicio añadido' : '✅ Servicio actualizado');
              } catch (e) { snack('Error: $e', error: true); }
            },
            style: FilledButton.styleFrom(backgroundColor: kRosa, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(vertical: 11)),
            child: Text(doc == null ? 'Añadir' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          )),
        ])),
      ]),
    ),
  )));
  nCtrl.dispose(); dCtrl.dispose(); cCtrl.dispose(); pCtrl.dispose(); pdCtrl.dispose();
}

Future<void> _deleteServicio(BuildContext ctx, {required bool dark, required String empresaId, required String docId, required String nombre, required void Function(String, {bool error}) snack}) async {
  final ok = await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
    backgroundColor: kCard(dark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    title: Text('Eliminar servicio', style: TextStyle(color: kTexto(dark), fontSize: 14)),
    content: Text('¿Eliminar "$nombre"?', style: TextStyle(color: kMuted(dark), fontSize: 13)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: kRojo, foregroundColor: Colors.white), child: const Text('Eliminar')),
    ],
  ));
  if (ok != true) return;
  await FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('servicios').doc(docId).delete();
  snack('🗑️ Servicio eliminado');
}

// ════════════════════════════════════════════════════════════════════════════
// PRODUCTOS
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionProductos(BuildContext ctx, {
  required bool dark,
  required String? negocioId,
  required String empresaId,
  required void Function(String, {bool error}) snack,
}) {
  return _card(d: dark, icon: Icons.shopping_bag_outlined, c: kOro, title: 'Catálogo de Productos', sub: 'Productos disponibles en tu negocio',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('productos').snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Center(child: Text('Sin productos añadidos', style: TextStyle(color: kMuted(dark), fontSize: 13))));
          return Column(children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: kOro.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.shopping_bag_outlined, size: 14, color: kOro)),
              title: Text(data['nombre'] as String? ?? '', style: TextStyle(color: kTexto(dark), fontSize: 12)),
              trailing: Text(data['precio'] != null ? '€${data['precio']}' : '', style: const TextStyle(color: kOro, fontWeight: FontWeight.bold, fontSize: 12)));
          }).toList());
        },
      ),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: () { final nc = TextEditingController(); final pc = TextEditingController(); final dc = TextEditingController();
          showDialog(context: ctx, builder: (_) => AlertDialog(
            backgroundColor: kCard(dark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            title: Text('Nuevo producto', style: TextStyle(color: kTexto(dark), fontSize: 14, fontWeight: FontWeight.bold)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nc, autofocus: true, style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Nombre *')),
              const SizedBox(height: 8),
              TextField(controller: pc, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Precio €')),
              const SizedBox(height: 8),
              TextField(controller: dc, maxLines: 2, style: TextStyle(color: kTexto(dark)), decoration: kDec(dark, 'Descripción (opcional)')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: kMuted(dark)))),
              FilledButton(onPressed: () async {
                if (nc.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('productos').add({'nombre': nc.text.trim(), 'descripcion': dc.text.trim(), if (double.tryParse(pc.text) != null) 'precio': double.parse(pc.text), 'activo': true, 'creado_en': FieldValue.serverTimestamp()});
                snack('✅ Producto añadido');
              }, style: FilledButton.styleFrom(backgroundColor: kOro, foregroundColor: Colors.white), child: const Text('Añadir')),
            ],
          )).then((_) { nc.dispose(); pc.dispose(); dc.dispose(); }); },
        icon: const Icon(Icons.add_rounded, size: 15),
        label: const Text('Añadir producto', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        style: FilledButton.styleFrom(backgroundColor: kOro, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(vertical: 11)),
      )),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// RESERVAS CONFIG
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionReservasConfig(BuildContext ctx, {
  required bool dark,
  required bool reservasOnlineActivas,
  required bool mostrarAgenda,
  required bool reservarSinRegistro,
  required bool listaEspera,
  required bool pagosAnticipados,
  required int antelacionMinHoras,
  required int antelacionMaxDias,
  required TextEditingController textoBotonCtrl,
  required TextEditingController instrReservaCtrl,
  required void Function(bool) onReservasActChanged,
  required void Function(bool) onAgendaChanged,
  required void Function(bool) onSinRegistroChanged,
  required void Function(bool) onListaEsperaChanged,
  required void Function(bool) onPagosAnticipChanged,
  required void Function(int) onAntelMinChanged,
  required void Function(int) onAntelMaxChanged,
}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _card(d: dark, icon: Icons.calendar_month_outlined, c: kAccent, title: 'Reservas Online', sub: 'Configura cómo reciben reservas tus clientes', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _toggle(dark, 'Activar reservas online', reservasOnlineActivas, onReservasActChanged),
      if (reservasOnlineActivas) ...[
        const SizedBox(height: 10),
        _lbl(dark, 'TEXTO DEL BOTÓN'),
        TextField(controller: textoBotonCtrl, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'Reservar ahora')),
        const SizedBox(height: 8),
        _toggle(dark, 'Mostrar agenda de disponibilidad', mostrarAgenda, onAgendaChanged),
        _toggle(dark, 'Reservar sin registro', reservarSinRegistro, onSinRegistroChanged),
        _toggle(dark, 'Lista de espera', listaEspera, onListaEsperaChanged),
        _toggle(dark, 'Pago anticipado obligatorio', pagosAnticipados, onPagosAnticipChanged),
      ],
    ])),
    _card(d: dark, icon: Icons.timer_outlined, c: kAzul, title: 'Antelación y Plazos', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(dark, 'ANTELACIÓN MÍNIMA (horas antes)'),
      Row(children: [
        Expanded(child: Slider(value: antelacionMinHoras.toDouble().clamp(1, 72), min: 1, max: 72, divisions: 71, activeColor: kAzul, inactiveColor: kBorde(dark), onChanged: (v) => onAntelMinChanged(v.toInt()))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: kAzul.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
            child: Text('${antelacionMinHoras}h', style: const TextStyle(color: kAzul, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 10),
      _lbl(dark, 'ANTELACIÓN MÁXIMA (días)'),
      Row(children: [
        Expanded(child: Slider(value: antelacionMaxDias.toDouble().clamp(1, 365), min: 1, max: 365, divisions: 72, activeColor: kAzul, inactiveColor: kBorde(dark), onChanged: (v) => onAntelMaxChanged(v.toInt()))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: kAzul.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
            child: Text('${antelacionMaxDias}d', style: const TextStyle(color: kAzul, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 10),
      _lbl(dark, 'INSTRUCCIONES PARA EL CLIENTE'),
      TextField(controller: instrReservaCtrl, maxLines: 3, style: TextStyle(color: kTexto(dark), fontSize: 13), decoration: kDec(dark, 'Ej: Llega 5 minutos antes...')),
    ])),
  ]);
}

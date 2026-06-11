import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';

const _kBg     = Color(0xFF0A0F23);
const _kCard   = Color(0xFF1E2139);
const _kAccent = Color(0xFF00FFC8);
const _kRosa   = Color(0xFFFF3296);
const _kTexto  = Colors.white;
const _kMuted  = Color(0xFFB0B3C1);
const _kBorde  = Color(0xFF2A2E45);

class TabServiciosNegocio extends StatefulWidget {
  final String empresaId;
  const TabServiciosNegocio({super.key, required this.empresaId});

  @override
  State<TabServiciosNegocio> createState() => _TabServiciosNegocioState();
}

class _TabServiciosNegocioState extends State<TabServiciosNegocio> {
  CollectionReference get _col =>
      FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).collection('servicios');

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFFF2850) : _kAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Importar CSV ─────────────────────────────────────────────────────────
  Future<void> _importarCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final rows = const CsvToListConverter(eol: '\n').convert(String.fromCharCodes(bytes));
    if (rows.isEmpty) { _snack('El CSV está vacío', error: true); return; }

    final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    final iNombre = headers.indexOf('nombre');
    if (iNombre == -1) { _snack('El CSV necesita una columna "nombre"', error: true); return; }

    final iDesc     = headers.indexWhere((h) => h.startsWith('desc'));
    final iCat      = headers.indexWhere((h) => h.startsWith('cat'));
    final iPrecio   = headers.indexOf('precio');
    final iPrecioD  = headers.indexWhere((h) => h.contains('desde'));
    final iDuracion = headers.indexWhere((h) => h.startsWith('dur'));
    final iPublico  = headers.indexWhere((h) => h.startsWith('pub'));

    final servicios = <Map<String, dynamic>>[];
    for (final row in rows.skip(1)) {
      final nombre = iNombre < row.length ? row[iNombre].toString().trim() : '';
      if (nombre.isEmpty) continue;
      final s = <String, dynamic>{'nombre': nombre, 'activo': true};
      _setIfNotEmpty(s, 'descripcion', iDesc, row);
      _setIfNotEmpty(s, 'categoria', iCat, row);
      if (iPrecio >= 0 && iPrecio < row.length) {
        final v = double.tryParse(row[iPrecio].toString().replaceAll(',', '.'));
        if (v != null) s['precio'] = v;
      }
      if (iPrecioD >= 0 && iPrecioD < row.length) {
        final v = double.tryParse(row[iPrecioD].toString().replaceAll(',', '.'));
        if (v != null) s['precio_desde'] = v;
      }
      if (iDuracion >= 0 && iDuracion < row.length) {
        final v = int.tryParse(row[iDuracion].toString());
        if (v != null) s['duracion'] = v;
      }
      _setIfNotEmpty(s, 'publico', iPublico, row);
      servicios.add(s);
    }

    if (servicios.isEmpty) { _snack('No hay servicios válidos en el CSV', error: true); return; }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Importar ${servicios.length} servicio${servicios.length == 1 ? '' : 's'}',
            style: const TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 260,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Columnas: nombre, descripcion, categoria, precio, duracion, publico',
                style: TextStyle(color: _kMuted, fontSize: 10)),
            const SizedBox(height: 10),
            Expanded(child: ListView.separated(
              itemCount: servicios.length,
              separatorBuilder: (_, __) => const Divider(color: _kBorde, height: 1),
              itemBuilder: (_, i) {
                final s = servicios[i];
                final precio = s['precio'] != null
                    ? '€${s['precio']}'
                    : s['precio_desde'] != null ? 'Desde €${s['precio_desde']}' : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Text(s['nombre'] as String,
                        style: const TextStyle(color: _kTexto, fontSize: 13))),
                    if (s['categoria'] != null)
                      Text(s['categoria'] as String,
                          style: const TextStyle(color: _kMuted, fontSize: 11)),
                    if (precio.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(precio, style: const TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                );
              },
            )),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Importar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    int importados = 0;
    for (final s in servicios) {
      try {
        await _col.add({...s, 'creado_en': FieldValue.serverTimestamp()});
        importados++;
      } catch (_) {}
    }
    if (mounted) _snack('✅ $importados servicio${importados == 1 ? '' : 's'} importado${importados == 1 ? '' : 's'}');
  }

  void _setIfNotEmpty(Map<String, dynamic> map, String key, int idx, List row) {
    if (idx >= 0 && idx < row.length) {
      final v = row[idx].toString().trim();
      if (v.isNotEmpty) map[key] = v;
    }
  }

  // ── Eliminar servicio ─────────────────────────────────────────────────────
  Future<void> _eliminar(String id, String nombre) async {
    final ok = await showDialog<bool>(context: context, builder: (dlgCtx) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Eliminar servicio', style: TextStyle(color: _kTexto, fontSize: 16)),
      content: Text('¿Eliminar "$nombre"?', style: const TextStyle(color: _kMuted, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        FilledButton(onPressed: () => Navigator.pop(dlgCtx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF2850), foregroundColor: Colors.white),
            child: const Text('Eliminar')),
      ],
    ));
    if (ok == true) {
      await _col.doc(id).delete();
      _snack('🗑️ Servicio eliminado');
    }
  }

  // ── Diálogo añadir/editar ─────────────────────────────────────────────────
  Future<void> _mostrarDialogo({QueryDocumentSnapshot? doc}) async {
    final data = doc?.data() as Map<String, dynamic>?;
    final nombreCtrl = TextEditingController(text: data?['nombre'] ?? '');
    final descCtrl   = TextEditingController(text: data?['descripcion'] ?? '');
    final catCtrl    = TextEditingController(text: data?['categoria'] ?? '');
    final precioCtrl = TextEditingController(text: data?['precio']?.toString() ?? '');
    int duracion     = data?['duracion'] as int? ?? 60;
    String publico   = data?['publico'] as String? ?? 'todos';
    bool activo      = data?['activo'] as bool? ?? true;
    String? fotoUrl  = data?['imagen_url'] as String?;
    bool subiendoFoto = false;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(builder: (ctx, setSt) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF151932),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.content_cut_rounded, color: _kAccent, size: 16)),
                const SizedBox(width: 10),
                Expanded(child: Text(doc == null ? 'Nuevo servicio' : 'Editar servicio',
                    style: const TextStyle(color: _kTexto, fontSize: 15, fontWeight: FontWeight.bold))),
                Switch(value: activo, onChanged: (v) => setSt(() => activo = v), activeColor: _kAccent),
                IconButton(icon: const Icon(Icons.close, color: _kMuted, size: 18),
                    onPressed: () => Navigator.pop(dlgCtx)),
              ]),
            ),
            // Body
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(nombreCtrl, 'Nombre *', 'Ej: Corte de cabello'),
                const SizedBox(height: 10),
                _field(descCtrl, 'Descripción', 'Breve descripción', maxLines: 2),
                const SizedBox(height: 10),
                _field(catCtrl, 'Categoría', 'Ej: Corte, Color, Masaje…'),
                const SizedBox(height: 10),
                _field(precioCtrl, 'Precio (€)', '0.00', keyboard: TextInputType.number),
                const SizedBox(height: 10),
                // Duración
                Row(children: [
                  const Text('Duración', style: TextStyle(color: _kMuted, fontSize: 12)),
                  const Spacer(),
                  Text(duracion >= 60
                      ? '${duracion ~/ 60}h${duracion % 60 > 0 ? ' ${duracion % 60}min' : ''}'
                      : '${duracion}min',
                      style: const TextStyle(color: _kAccent, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
                Slider(value: duracion.toDouble(), min: 10, max: 240, divisions: 23,
                    activeColor: _kAccent, inactiveColor: _kBorde,
                    onChanged: (v) => setSt(() => duracion = v.toInt())),
                // Público
                const Text('Público', style: TextStyle(color: _kMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  for (final p in ['todos', 'femenino', 'masculino'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p[0].toUpperCase() + p.substring(1)),
                        selected: publico == p,
                        onSelected: (_) => setSt(() => publico = p),
                        selectedColor: _kAccent,
                        backgroundColor: _kBg,
                        labelStyle: TextStyle(
                            color: publico == p ? _kBg : _kMuted,
                            fontSize: 12, fontWeight: FontWeight.w600),
                        side: BorderSide(color: publico == p ? _kAccent : _kBorde),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                // Foto
                GestureDetector(
                  onTap: subiendoFoto ? null : () async {
                    Uint8List? bytes; String ext = 'jpg';
                    try {
                      final esDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
                      if (esDesktop) {
                        final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                        if (r == null || r.files.isEmpty) return;
                        bytes = r.files.first.bytes; ext = r.files.first.extension ?? 'jpg';
                      } else {
                        final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
                        if (img == null) return;
                        bytes = await img.readAsBytes(); ext = img.path.split('.').last;
                      }
                      if (bytes == null) return;
                      setSt(() => subiendoFoto = true);
                      final ref = FirebaseStorage.instance.ref(
                          'empresas/${widget.empresaId}/servicios/${DateTime.now().millisecondsSinceEpoch}.$ext');
                      await ref.putData(bytes, SettableMetadata(
                          contentType: ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg'));
                      fotoUrl = await ref.getDownloadURL();
                    } catch (e) {
                      if (mounted) _snack('Error foto: $e', error: true);
                    } finally {
                      setSt(() => subiendoFoto = false);
                    }
                  },
                  child: Container(
                    height: 80, width: double.infinity,
                    decoration: BoxDecoration(
                      color: _kBg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: fotoUrl != null ? _kAccent.withValues(alpha: 0.4) : _kBorde),
                    ),
                    child: subiendoFoto
                        ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2))
                        : fotoUrl != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(9),
                            child: Image.network(fotoUrl!, fit: BoxFit.cover, width: double.infinity))
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_photo_alternate_outlined, color: _kAccent, size: 24),
                            SizedBox(height: 3),
                            Text('Foto (opcional)', style: TextStyle(color: _kMuted, fontSize: 10)),
                          ]),
                  ),
                ),
              ],
            ))),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  if (nombre.isEmpty) return;
                  final datos = <String, dynamic>{
                    'nombre': nombre,
                    'descripcion': descCtrl.text.trim(),
                    'categoria': catCtrl.text.trim(),
                    'duracion': duracion,
                    'publico': publico,
                    'activo': activo,
                    if (fotoUrl != null) 'imagen_url': fotoUrl,
                  };
                  final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
                  if (precio != null) datos['precio'] = precio;
                  Navigator.pop(dlgCtx);
                  try {
                    if (doc == null) {
                      await _col.add({...datos, 'creado_en': FieldValue.serverTimestamp()});
                    } else {
                      await _col.doc(doc.id).update(datos);
                    }
                    _snack(doc == null ? '✅ Servicio añadido' : '✅ Servicio actualizado');
                  } catch (e) {
                    _snack('Error: $e', error: true);
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: _kBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                child: Text(doc == null ? 'Añadir servicio' : 'Guardar cambios',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              )),
            ),
          ]),
        ),
      )),
    );
    nombreCtrl.dispose(); descCtrl.dispose(); catCtrl.dispose(); precioCtrl.dispose();
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _kMuted, fontSize: 12)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: _kTexto, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: _kBorde, fontSize: 12),
          filled: true, fillColor: _kBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _kBorde, width: 0.8)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _kAccent, width: 1)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _col.orderBy('nombre').snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _kAccent));
        }
        final docs = snap.data?.docs ?? [];

        return Column(children: [
          // Barra de acciones
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: () => _mostrarDialogo(),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Añadir servicio', style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccent, foregroundColor: _kBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              )),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _importarCsv,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('CSV', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAccent,
                  side: const BorderSide(color: _kAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                ),
              ),
            ]),
          ),
          if (docs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${docs.length} servicio${docs.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: _kMuted, fontSize: 11)),
            ),
          // Lista
          Expanded(child: docs.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.content_cut_rounded, size: 48, color: _kBorde),
                  SizedBox(height: 12),
                  Text('Sin servicios todavía', style: TextStyle(color: _kMuted, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Añade servicios para que los clientes puedan reservar',
                      style: TextStyle(color: _kBorde, fontSize: 11), textAlign: TextAlign.center),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc  = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre   = data['nombre'] as String? ?? '';
                    final cat      = data['categoria'] as String? ?? '';
                    final precio   = data['precio'] as num?;
                    final precioD  = data['precio_desde'] as num?;
                    final duracion = data['duracion'] as int?;
                    final activo   = data['activo'] as bool? ?? true;
                    final imgUrl   = data['imagen_url'] as String?;
                    final publico  = (data['publico'] as String? ?? '').toLowerCase();

                    final pColor = publico == 'femenino' ? _kRosa
                        : publico == 'masculino' ? const Color(0xFF4A9EFF)
                        : _kAccent;

                    final precioTxt = precio != null
                        ? '€${precio.toStringAsFixed(precio % 1 == 0 ? 0 : 2)}'
                        : precioD != null
                        ? 'Desde €${precioD.toStringAsFixed(precioD % 1 == 0 ? 0 : 2)}'
                        : 'Consultar';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: activo ? _kBorde : _kBorde.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Row(children: [
                        Container(width: 4, height: 64,
                            decoration: BoxDecoration(
                                color: activo ? pColor : _kBorde,
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: imgUrl != null ? Colors.transparent : pColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                              image: imgUrl != null ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover) : null,
                            ),
                            child: imgUrl == null ? Icon(_iconCat(cat), size: 18, color: pColor) : null,
                          ),
                        ),
                        Expanded(child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(nombre, style: const TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text(precioTxt, style: TextStyle(color: pColor, fontSize: 12, fontWeight: FontWeight.w700)),
                              if (duracion != null) ...[
                                const SizedBox(width: 8),
                                Text(_durTxt(duracion),
                                    style: const TextStyle(color: _kMuted, fontSize: 11)),
                              ],
                            ]),
                          ]),
                        )),
                        IconButton(
                          onPressed: () => _mostrarDialogo(doc: doc as QueryDocumentSnapshot),
                          icon: const Icon(Icons.edit_outlined, size: 17, color: _kMuted),
                          padding: const EdgeInsets.all(6), constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          onPressed: () => _eliminar(doc.id, nombre),
                          icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFFF2850)),
                          padding: const EdgeInsets.all(6), constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                      ]),
                    );
                  },
                )),
        ]);
      },
    );
  }

  IconData _iconCat(String cat) {
    switch (cat.toLowerCase()) {
      case 'corte': case 'pelo':    return Icons.content_cut_rounded;
      case 'color': case 'tinte':   return Icons.color_lens_rounded;
      case 'manicura': case 'uñas': return Icons.spa_rounded;
      case 'masaje':                return Icons.self_improvement_rounded;
      case 'facial':                return Icons.face_retouching_natural_rounded;
      case 'barba':                 return Icons.face_rounded;
      default:                      return Icons.star_rounded;
    }
  }

  String _durTxt(int min) {
    if (min >= 60) {
      final h = min ~/ 60; final m = min % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }
    return '${min}min';
  }
}

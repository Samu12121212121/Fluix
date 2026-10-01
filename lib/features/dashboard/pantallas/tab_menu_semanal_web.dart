import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/contenido_web_service.dart';

// ignore_for_file: use_build_context_synchronously

// ═════════════════════════════════════════════════════════════════════════════
// TAB MENÚ SEMANAL WEB — gestión del menú del día por días de la semana
// Colección: empresas/{id}/menu_semanal
// Mejoras: plantillas, renovar semana, vista previa, precio por plato
// ═════════════════════════════════════════════════════════════════════════════

const _kDias = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

class TabMenuSemanalWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color? color;

  const TabMenuSemanalWeb({
    super.key,
    required this.empresaId,
    required this.svc,
    this.color,
  });

  @override
  State<TabMenuSemanalWeb> createState() => _TabMenuSemanalWebState();
}

class _TabMenuSemanalWebState extends State<TabMenuSemanalWeb> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  bool _renovando = false;
  bool _popupActivo = false;
  bool _guardandoPopup = false;

  Color get _color => widget.color ?? const Color(0xFF0F766E);

  DocumentReference<Map<String, dynamic>> get _webAvanzadaDoc =>
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('web_avanzada');

  CollectionReference<Map<String, dynamic>> get _plantillasCol =>
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('menu_plantillas');

  @override
  void initState() {
    super.initState();
    _stream = widget.svc.obtenerMenuSemanal(widget.empresaId);
    _cargarEstadoPopup();
  }

  Future<void> _cargarEstadoPopup() async {
    try {
      final doc = await _webAvanzadaDoc.get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _popupActivo = data['popup_activo'] == true &&
            data['popup_tipo'] == 'menu_semanal';
      });
    } catch (_) {}
  }

  Future<void> _togglePopupMenu(bool activo) async {
    setState(() => _guardandoPopup = true);
    try {
      if (activo) {
        await _webAvanzadaDoc.set({
          'popup_activo': true,
          'popup_tipo': 'menu_semanal',
          'actualizado': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await _webAvanzadaDoc.set({
          'popup_activo': false,
          'popup_tipo': null,
          'actualizado': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (mounted) setState(() => _popupActivo = activo);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardandoPopup = false);
    }
  }

  // ── Renovar semana: marca todos los días como inactivos para empezar de nuevo
  Future<void> _renovarSemana(List<Map<String, dynamic>> dias) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renovar menú de la semana',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: const Text(
            'Los platos se mantienen pero todos los días quedarán inactivos. '
            'Activa solo los días que apliquen esta semana.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _color),
            child: const Text('Renovar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _renovando = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final dia in dias) {
        final id = dia['id'] as String?;
        if (id == null) continue;
        batch.update(
          FirebaseFirestore.instance
              .collection('empresas').doc(widget.empresaId)
              .collection('menu_semanal').doc(id),
          {'activo': false},
        );
      }
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Semana renovada — activa los días que apliquen'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 3),
      ));
    } finally {
      if (mounted) setState(() => _renovando = false);
    }
  }

  // ── Guardar plantilla ─────────────────────────────────────────────────────
  Future<void> _guardarPlantilla(List<Map<String, dynamic>> dias) async {
    final ctrl = TextEditingController(
        text: 'Semana tipo ${DateTime.now().day}/${DateTime.now().month}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Guardar como plantilla',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre de la plantilla'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _color),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok != true) return;

    final diasData = dias.map((d) {
      final copia = Map<String, dynamic>.from(d)..remove('id');
      return copia;
    }).toList();

    await _plantillasCol.add({
      'nombre': ctrl.text.trim(),
      'dias': diasData,
      'creada': FieldValue.serverTimestamp(),
    });

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Plantilla guardada'),
      backgroundColor: Color(0xFF10B981),
      duration: Duration(seconds: 2),
    ));
  }

  // ── Aplicar plantilla ─────────────────────────────────────────────────────
  Future<void> _mostrarPlantillas(BuildContext ctx) async {
    final snap = await _plantillasCol.orderBy('creada', descending: true).limit(20).get();
    if (snap.docs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('No hay plantillas guardadas todavía'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    final seleccionada = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Aplicar plantilla',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        const Divider(height: 1),
        ...snap.docs.map((doc) {
          final data = doc.data();
          final nombre = data['nombre'] as String? ?? 'Plantilla';
          final dias = (data['dias'] as List?)?.length ?? 0;
          return ListTile(
            leading: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.restaurant_menu_rounded, size: 18, color: _color)),
            title: Text(nombre,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: Text('$dias días', style: const TextStyle(fontSize: 11)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFFCBD5E1)),
                onPressed: () async {
                  await doc.reference.delete();
                  Navigator.pop(ctx);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
            ]),
            onTap: () => Navigator.pop(ctx, data),
          );
        }),
        const SizedBox(height: 24),
      ]),
    );

    if (seleccionada == null) return;
    await _aplicarPlantilla(seleccionada);
  }

  Future<void> _aplicarPlantilla(Map<String, dynamic> plantilla) async {
    final dias = (plantilla['dias'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final col = FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('menu_semanal');

    // Borrar los docs actuales y añadir los de la plantilla
    final snap = await col.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    for (int i = 0; i < dias.length; i++) {
      batch.set(col.doc(), {...dias[i], 'orden': i, 'activo': true});
    }
    await batch.commit();

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Plantilla "${plantilla['nombre']}" aplicada'),
      backgroundColor: const Color(0xFF10B981),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: Colors.red)));
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dias = snap.data ?? [];
        final activos = dias.where((d) => d['activo'] as bool? ?? true).length;

        return Column(children: [
          _buildHeader(context, dias, activos),
          const Divider(height: 1),
          Expanded(
            child: dias.isEmpty
                ? _buildVacio()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                    itemCount: dias.length,
                    itemBuilder: (_, i) => _buildDiaCard(dias[i]),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _buildHeader(BuildContext ctx, List<Map<String, dynamic>> dias, int activos) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Menú Semanal', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _color)),
            Text('$activos día${activos != 1 ? 's' : ''} activo${activos != 1 ? 's' : ''} esta semana',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ])),
          if (dias.isNotEmpty) ...[
            // Renovar semana
            _accionBtn(
              icon: _renovando
                  ? const SizedBox(width: 13, height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 13),
              label: 'Renovar',
              onTap: _renovando ? null : () => _renovarSemana(dias),
            ),
            const SizedBox(width: 6),
            // Guardar plantilla
            _accionBtn(
              icon: const Icon(Icons.bookmark_add_outlined, size: 13),
              label: 'Guardar',
              onTap: () => _guardarPlantilla(dias),
            ),
            const SizedBox(width: 6),
          ],
          // Aplicar plantilla
          _accionBtn(
            icon: const Icon(Icons.bookmarks_outlined, size: 13),
            label: 'Plantillas',
            onTap: () => _mostrarPlantillas(ctx),
          ),
          const SizedBox(width: 6),
          // Toggle popup web
          GestureDetector(
            onTap: _guardandoPopup ? null : () => _togglePopupMenu(!_popupActivo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _popupActivo
                    ? _color.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _popupActivo ? _color.withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _guardandoPopup
                    ? SizedBox(width: 13, height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _color))
                    : Icon(_popupActivo ? Icons.campaign_rounded : Icons.campaign_outlined,
                        size: 13, color: _popupActivo ? _color : const Color(0xFF475569)),
                const SizedBox(width: 4),
                Text(_popupActivo ? 'Popup ON' : 'Popup',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _popupActivo ? _color : const Color(0xFF475569),
                    )),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _abrirEditor(null),
            icon: const Icon(Icons.add_rounded, size: 14),
            label: const Text('Añadir día'),
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _accionBtn({required Widget icon, required String label, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11,
                color: Color(0xFF475569), fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _buildDiaCard(Map<String, dynamic> dia) {
    final id       = dia['id'] as String? ?? '';
    final nombre   = dia['dia'] as String? ?? '';
    final activo   = dia['activo'] as bool? ?? true;
    final precio   = dia['precio'];
    final primeros = (dia['primeros'] as List?)?.cast<String>() ?? [];
    final segundos = (dia['segundos'] as List?)?.cast<String>() ?? [];
    final postres  = (dia['postres']  as List?)?.cast<String>() ?? [];
    final bebida   = dia['bebida'] as String? ?? '';
    final nota     = dia['nota'] as String? ?? '';
    final tieneContenido = (primeros + segundos + postres).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo ? const Color(0xFFE8EDF2) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(children: [
        // Cabecera del día
        InkWell(
          onTap: () => _abrirEditor(dia),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(12),
            bottom: tieneContenido ? Radius.zero : const Radius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              // Indicador de color del día
              Container(
                width: 4, height: 40,
                decoration: BoxDecoration(
                  color: activo ? _color : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_capitalize(nombre), style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: activo ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
                  if (precio != null)
                    Text('${precio}€ · menú completo', style: TextStyle(
                        fontSize: 11,
                        color: activo ? _color : const Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w600)),
                  if (!tieneContenido)
                    Text('Sin platos — toca para editar',
                        style: const TextStyle(fontSize: 11,
                            color: Color(0xFFCBD5E1), fontStyle: FontStyle.italic)),
                ]),
              ),
              Switch(
                value: activo,
                activeColor: const Color(0xFF10B981),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: id.isEmpty ? null : (v) =>
                    widget.svc.toggleDiaMenuActivo(widget.empresaId, id, v),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Color(0xFFCBD5E1)),
                onPressed: id.isEmpty ? null : () => _confirmarBorrar(id, nombre),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
        ),
        // Detalle de platos
        if (tieneContenido) ...[
          const Divider(height: 1, indent: 12, endIndent: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (primeros.isNotEmpty)
                Expanded(child: _seccionPlatos('Primeros', primeros, activo)),
              if (primeros.isNotEmpty && (segundos.isNotEmpty || postres.isNotEmpty))
                const SizedBox(width: 10),
              if (segundos.isNotEmpty)
                Expanded(child: _seccionPlatos('Segundos', segundos, activo)),
              if (segundos.isNotEmpty && postres.isNotEmpty)
                const SizedBox(width: 10),
              if (postres.isNotEmpty)
                Expanded(child: _seccionPlatos('Postre', postres, activo)),
            ]),
          ),
          if (bebida.isNotEmpty || nota.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(children: [
                if (bebida.isNotEmpty)
                  Row(children: [
                    Icon(Icons.local_bar_rounded, size: 12,
                        color: activo ? _color : const Color(0xFFCBD5E1)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(bebida, style: TextStyle(
                        fontSize: 11,
                        color: activo ? const Color(0xFF475569) : const Color(0xFFCBD5E1)))),
                  ]),
                if (nota.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 12,
                        color: Color(0xFF94A3B8)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(nota, style: const TextStyle(
                        fontSize: 10, color: Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic))),
                  ]),
                ],
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _seccionPlatos(String titulo, List<String> platos, bool activo) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
          color: activo ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
          letterSpacing: .5, textBaseline: TextBaseline.alphabetic)),
      const SizedBox(height: 3),
      ...platos.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text('• $p', style: TextStyle(fontSize: 11,
            color: activo ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      )),
    ]);
  }

  Widget _buildVacio() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.restaurant_rounded, size: 52, color: _color.withValues(alpha: 0.2)),
      const SizedBox(height: 14),
      const Text('Sin menú semanal todavía',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: Color(0xFF334155))),
      const SizedBox(height: 5),
      const Text('Añade los días o aplica una plantilla guardada',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      const SizedBox(height: 18),
      ElevatedButton.icon(
        onPressed: () => _abrirEditor(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir primer día'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]));
  }

  Future<void> _confirmarBorrar(String id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminar "$nombre"',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: const Text('Se eliminará este día del menú semanal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.svc.eliminarDiaMenu(widget.empresaId, id);
  }

  void _abrirEditor(Map<String, dynamic>? dia) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditorDiaMenu(
        dia: dia,
        color: _color,
        onGuardar: (data) async {
          await widget.svc.guardarDiaMenu(widget.empresaId, data);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor de un día del menú (mejorado con precio por plato)
// ─────────────────────────────────────────────────────────────────────────────

class _EditorDiaMenu extends StatefulWidget {
  final Map<String, dynamic>? dia;
  final Color color;
  final Future<void> Function(Map<String, dynamic>) onGuardar;

  const _EditorDiaMenu({this.dia, required this.color, required this.onGuardar});

  @override
  State<_EditorDiaMenu> createState() => _EditorDiaMenuState();
}

class _EditorDiaMenuState extends State<_EditorDiaMenu> {
  String  _dia          = _kDias.first;
  final _precioCtrl     = TextEditingController();
  final _bebidaCtrl     = TextEditingController();
  final _notaCtrl       = TextEditingController();
  final _primerosCtrl   = TextEditingController();
  final _segundosCtrl   = TextEditingController();
  final _postresCtrl    = TextEditingController();
  bool _activo   = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dia;
    if (d != null) {
      _dia         = d['dia'] as String? ?? _kDias.first;
      _activo      = d['activo'] as bool? ?? true;
      _precioCtrl.text  = (d['precio'] != null) ? d['precio'].toString() : '';
      _bebidaCtrl.text  = d['bebida'] as String? ?? '';
      _notaCtrl.text    = d['nota'] as String? ?? '';
      final primeros = (d['primeros'] as List?)?.cast<String>() ?? [];
      final segundos = (d['segundos'] as List?)?.cast<String>() ?? [];
      final postres  = (d['postres']  as List?)?.cast<String>() ?? [];
      _primerosCtrl.text = primeros.join('\n');
      _segundosCtrl.text = segundos.join('\n');
      _postresCtrl.text  = postres.join('\n');
    }
  }

  @override
  void dispose() {
    for (final c in [_precioCtrl, _bebidaCtrl, _notaCtrl,
                     _primerosCtrl, _segundosCtrl, _postresCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _parsePlatos(String texto) =>
      texto.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Row(children: [
          Text(widget.dia == null ? 'Nuevo día de menú' : 'Editar menú',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 16),
        // ── Día + Precio ────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _dia,
              decoration: InputDecoration(
                labelText: 'Día de la semana',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.color)),
              ),
              items: _kDias.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(d[0].toUpperCase() + d.substring(1)))).toList(),
              onChanged: (v) { if (v != null) setState(() => _dia = v); },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: TextFormField(
              controller: _precioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Precio (€)',
                hintText: '14,90',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.color)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        // ── Platos ──────────────────────────────────────────────────────
        _seccionPlatos('Primeros', _primerosCtrl,
            'Ej:\nEnsalada mixta\nGazpacho andaluz'),
        const SizedBox(height: 10),
        _seccionPlatos('Segundos', _segundosCtrl,
            'Ej:\nPollo asado con patatas\nMerluza a la plancha'),
        const SizedBox(height: 10),
        _seccionPlatos('Postre', _postresCtrl,
            'Ej:\nFlan casero\nFruta del tiempo'),
        const SizedBox(height: 10),
        // ── Bebida y nota ───────────────────────────────────────────────
        TextFormField(
          controller: _bebidaCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Bebida incluida',
            hintText: 'Ej: Agua, vino o cerveza incluida',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: widget.color)),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notaCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Nota adicional',
            hintText: 'Ej: Disponible de 13:00 a 16:00 h',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: widget.color)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Activo esta semana',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155))),
          const Spacer(),
          Switch(
            value: _activo,
            activeColor: const Color(0xFF10B981),
            onChanged: (v) => setState(() => _activo = v),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(
              backgroundColor: widget.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _guardando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.dia == null ? 'Añadir al menú' : 'Guardar cambios',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _seccionPlatos(String titulo, TextEditingController ctrl, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: widget.color)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        maxLines: 3,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          helperText: 'Un plato por línea',
          helperStyle: const TextStyle(fontSize: 10),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: widget.color)),
        ),
      ),
    ]);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final precio = double.tryParse(
          _precioCtrl.text.replaceAll(',', '.').replaceAll('€', '').trim());
      final data = <String, dynamic>{
        if (widget.dia?['id'] != null) 'id': widget.dia!['id'],
        'dia':      _dia,
        'activo':   _activo,
        'primeros': _parsePlatos(_primerosCtrl.text),
        'segundos': _parsePlatos(_segundosCtrl.text),
        'postres':  _parsePlatos(_postresCtrl.text),
        if (_bebidaCtrl.text.trim().isNotEmpty) 'bebida': _bebidaCtrl.text.trim(),
        if (_notaCtrl.text.trim().isNotEmpty)   'nota':   _notaCtrl.text.trim(),
        if (precio != null) 'precio': precio,
        if (widget.dia?['orden'] != null) 'orden': widget.dia!['orden'],
      };
      await widget.onGuardar(data);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

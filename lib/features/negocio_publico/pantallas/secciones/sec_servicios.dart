part of '../modulo_app_screen.dart';

extension _SecServiciosProductos on _ModuloAppScreenState {

  Widget _buildProductos() {
    if (_negocioId == null) {
      return _Seccion(icono: Icons.shopping_bag_outlined, titulo: 'Catálogo de Productos',
        subtitulo: 'Guarda el perfil primero',
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Text('Activa tu perfil público primero', style: TextStyle(color: _kMuted, fontSize: 13)))));
    }
    return _Seccion(icono: Icons.shopping_bag_outlined, titulo: 'Catálogo de Productos',
      subtitulo: 'Productos disponibles en tu perfil',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas').doc(widget.empresaId).collection('productos')
            .orderBy('nombre').snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2)));
          }
          final docs = snap.data?.docs ?? [];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (docs.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_bag_outlined, color: _kMuted, size: 32),
                  const SizedBox(height: 8),
                  Text('Sin productos todavía', style: TextStyle(color: _kMuted, fontSize: 13)),
                ])))
            else
              ...docs.map((doc) => _productoTile(doc)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _dlgProducto(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Añadir producto', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(backgroundColor: _kOro, foregroundColor: _kBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ]);
        },
      ),
    );
  }

  Widget _productoTile(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final nombre = d['nombre'] as String? ?? '';
    final precio = d['precio'] as num?;
    final stock  = d['stock'] as int?;
    final activo = d['activo'] as bool? ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorde, width: 0.5)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w600)),
          Row(children: [
            if (precio != null) Text('€${precio.toStringAsFixed(2)}', style: TextStyle(color: _kOro, fontSize: 12, fontWeight: FontWeight.w700)),
            if (stock != null) ...[const SizedBox(width: 8), Text('Stock: $stock', style: TextStyle(color: _kMuted, fontSize: 11))],
            if (!activo) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: _kBorde, borderRadius: BorderRadius.circular(4)),
                child: Text('Oculto', style: TextStyle(color: _kMuted, fontSize: 9)))],
          ]),
        ])),
        IconButton(icon: Icon(Icons.edit_outlined, color: _kAccent, size: 18), onPressed: () => _dlgProducto(doc: doc)),
        IconButton(icon: Icon(Icons.delete_outline, color: _kRosa, size: 18), onPressed: () async {
          final ok = await showDialog<bool>(context: context,
              builder: (_) => AlertDialog(backgroundColor: _kCard,
                title: Text('Eliminar $nombre', style: TextStyle(color: _kTexto, fontSize: 15)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Eliminar', style: TextStyle(color: _kRosa))),
                ]));
          if (ok == true) {
            await FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).collection('productos').doc(doc.id).delete();
          }
        }),
      ]),
    );
  }

  Future<void> _dlgProducto({QueryDocumentSnapshot? doc}) async {
    final d = doc?.data() as Map<String, dynamic>?;
    final nmCtrl   = TextEditingController(text: d?['nombre'] ?? '');
    final descCtrl = TextEditingController(text: d?['descripcion'] ?? '');
    final catCtrl  = TextEditingController(text: d?['categoria'] ?? '');
    final pCtrl    = TextEditingController(text: d?['precio']?.toString() ?? '');
    final pPromoCtrl = TextEditingController(text: d?['precio_promo']?.toString() ?? '');
    final stCtrl   = TextEditingController(text: d?['stock']?.toString() ?? '');
    bool activo = d?['activo'] as bool? ?? true;
    bool destacado = d?['destacado'] as bool? ?? false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
          child: Column(children: [
            Container(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(color: _kCard2, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                Icon(Icons.shopping_bag_outlined, color: _kOro, size: 20), const SizedBox(width: 10),
                Expanded(child: Text(doc == null ? 'Nuevo producto' : 'Editar producto',
                    style: TextStyle(color: _kTexto, fontSize: 15, fontWeight: FontWeight.bold))),
                Switch(value: activo, onChanged: (v) => setSt(() => activo = v),
                    activeColor: _kAccent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ])),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label('Nombre *'), TextField(controller: nmCtrl, autofocus: true,
                    style: TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('Ej: Camiseta logo')),
                const SizedBox(height: 12),
                _Label('Categoría'), TextField(controller: catCtrl,
                    style: TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('Ej: Ropa, Accesorios…')),
                const SizedBox(height: 12),
                _Label('Descripción'), TextField(controller: descCtrl, maxLines: 2,
                    style: TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('Descripción para el cliente')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _Label('Precio (€)'), TextField(controller: pCtrl, keyboardType: TextInputType.number,
                        style: TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('25.00')),
                  ])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _Label('Precio promo (€)'), TextField(controller: pPromoCtrl, keyboardType: TextInputType.number,
                        style: TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('19.90')),
                  ])),
                ]),
                const SizedBox(height: 12),
                _Label('Stock'), TextField(controller: stCtrl, keyboardType: TextInputType.number,
                    style: TextStyle(color: _kTexto, fontSize: 13), decoration: _dec('Vacío = ilimitado')),
                const SizedBox(height: 10),
                CheckboxListTile(contentPadding: EdgeInsets.zero, value: destacado, activeColor: _kOro,
                    title: Text('Producto destacado', style: TextStyle(color: _kTexto, fontSize: 13)),
                    onChanged: (v) => setSt(() => destacado = v!)),
              ]))),
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(foregroundColor: _kMuted,
                        padding: const EdgeInsets.symmetric(vertical: 13), side: BorderSide(color: _kBorde)),
                    child: const Text('Cancelar'))),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: FilledButton(
                  onPressed: () async {
                    if (nmCtrl.text.trim().isEmpty) return;
                    final datos = <String, dynamic>{'nombre': nmCtrl.text.trim(), 'categoria': catCtrl.text.trim(),
                      'descripcion': descCtrl.text.trim(), 'activo': activo, 'destacado': destacado};
                    if (pCtrl.text.isNotEmpty) datos['precio'] = double.tryParse(pCtrl.text);
                    if (pPromoCtrl.text.isNotEmpty) datos['precio_promo'] = double.tryParse(pPromoCtrl.text);
                    if (stCtrl.text.isNotEmpty) datos['stock'] = int.tryParse(stCtrl.text);
                    Navigator.pop(ctx);
                    try {
                      final col = FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).collection('productos');
                      if (doc == null) await col.add(datos); else await col.doc(doc.id).update(datos);
                      _snack(doc == null ? '✅ Producto añadido' : '✅ Producto actualizado');
                    } catch (e) { _snack('Error: $e', error: true); }
                  },
                  style: FilledButton.styleFrom(backgroundColor: _kOro, foregroundColor: _kBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: Text(doc == null ? 'Añadir' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.w800)),
                )),
              ])),
          ]),
        ),
      )),
    );
    nmCtrl.dispose(); descCtrl.dispose(); catCtrl.dispose(); pCtrl.dispose(); pPromoCtrl.dispose(); stCtrl.dispose();
  }
}

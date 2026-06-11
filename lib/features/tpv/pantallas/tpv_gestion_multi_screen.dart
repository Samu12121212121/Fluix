import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TpvGestionMultiScreen extends StatelessWidget {
  final String empresaId;
  const TpvGestionMultiScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.point_of_sale, size: 20),
          SizedBox(width: 8),
          Text('Gestión de TPVs', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .collection('tpvs_personalizados')
            .orderBy('nombre')
            .snapshots(),
        builder: (ctx, snap) {
          final tpvs = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TarjetaTpvBase(empresaId: empresaId),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('TPVs adicionales',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF444444))),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _crearTpv(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo TPV'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (tpvs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Sin TPVs adicionales todavía.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...tpvs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _TarjetaTpvPersonalizado(
                    tpvId: doc.id,
                    nombre: data['nombre'] as String? ?? '—',
                    empresaId: empresaId,
                    ocultos:
                        List<String>.from(data['productos_ocultos'] ?? []),
                    onEliminar: () => _eliminarTpv(context, doc.id),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _crearTpv(BuildContext context) async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo TPV adicional'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre del TPV',
            hintText: 'Ej: Terraza, Barra, Caja 2…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Crear')),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('tpvs_personalizados')
        .add({
      'nombre': nombre,
      'activo': true,
      'productos_ocultos': [],
      'imagenes': {},
      'creado': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _eliminarTpv(BuildContext context, String tpvId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar TPV'),
        content: const Text(
            '¿Eliminar este TPV? Se perderán sus productos extra y personalizaciones.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('tpvs_personalizados')
        .doc(tpvId)
        .delete();
  }
}

// ── Tarjeta del catálogo base ─────────────────────────────────────────────────

class _TarjetaTpvBase extends StatelessWidget {
  final String empresaId;
  const _TarjetaTpvBase({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('catalogo')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        final total = snap.data?.docs.length ?? 0;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.store,
                          color: Color(0xFF1565C0), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TPV Estándar (Base)',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('$total productos activos',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Chip(
                      label: Text('BASE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      backgroundColor: Color(0xFF1565C0),
                      padding: EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'El catálogo base contiene todos los productos estándar. '
                  'Los TPVs adicionales heredan este catálogo y pueden '
                  'ocultar productos o añadir productos específicos.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Tarjeta de TPV personalizado ──────────────────────────────────────────────

class _TarjetaTpvPersonalizado extends StatelessWidget {
  final String tpvId;
  final String nombre;
  final String empresaId;
  final List<String> ocultos;
  final VoidCallback onEliminar;

  const _TarjetaTpvPersonalizado({
    required this.tpvId,
    required this.nombre,
    required this.empresaId,
    required this.ocultos,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TpvPersonalizadoDetalleScreen(
              empresaId: empresaId,
              tpvId: tpvId,
              nombreInicial: nombre,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tablet_android,
                    color: Colors.indigo, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      ocultos.isEmpty
                          ? 'Catálogo completo'
                          : '${ocultos.length} producto${ocultos.length != 1 ? 's' : ''} ocultado${ocultos.length != 1 ? 's' : ''} del base',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: onEliminar,
                tooltip: 'Eliminar TPV',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pantalla de detalle: editar TPV personalizado
// ═══════════════════════════════════════════════════════════════════════════════

class TpvPersonalizadoDetalleScreen extends StatefulWidget {
  final String empresaId;
  final String tpvId;
  final String nombreInicial;

  const TpvPersonalizadoDetalleScreen({
    super.key,
    required this.empresaId,
    required this.tpvId,
    required this.nombreInicial,
  });

  @override
  State<TpvPersonalizadoDetalleScreen> createState() =>
      _TpvPersonalizadoDetalleScreenState();
}

class _TpvPersonalizadoDetalleScreenState
    extends State<TpvPersonalizadoDetalleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late String _nombre;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _nombre = widget.nombreInicial;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  DocumentReference get _docRef => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('tpvs_personalizados')
      .doc(widget.tpvId);

  Future<void> _renombrar() async {
    final ctrl = TextEditingController(text: _nombre);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar TPV'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevo == null || nuevo.isEmpty) return;
    await _docRef.update({'nombre': nuevo});
    setState(() => _nombre = nuevo);
  }

  Future<void> _toggleOculto(
      String prodId, List<String> ocultos) async {
    setState(() => _guardando = true);
    final nuevos = List<String>.from(ocultos);
    if (nuevos.contains(prodId)) {
      nuevos.remove(prodId);
    } else {
      nuevos.add(prodId);
    }
    await _docRef.update({'productos_ocultos': nuevos});
    setState(() => _guardando = false);
  }

  Future<void> _cambiarImagenBase(
      String prodId, Map<String, dynamic> imagenes) async {
    final ctrl = TextEditingController(text: imagenes[prodId] as String? ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('URL de imagen personalizada'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'URL de imagen',
            hintText: 'https://…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (imagenes.containsKey(prodId))
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Quitar imagen'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (url == null) return;
    final nuevas = Map<String, dynamic>.from(imagenes);
    if (url.isEmpty) {
      nuevas.remove(prodId);
    } else {
      nuevas[prodId] = url;
    }
    await _docRef.update({'imagenes': nuevas});
  }

  Future<void> _agregarProductoExtra() async {
    final nombre = TextEditingController();
    final precio = TextEditingController();
    final categoria = TextEditingController();
    final imagen = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Producto extra para este TPV'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nombre,
              decoration: const InputDecoration(
                  labelText: 'Nombre *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: precio,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Precio (€) *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: categoria,
              decoration: const InputDecoration(
                  labelText: 'Categoría', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: imagen,
              decoration: const InputDecoration(
                  labelText: 'URL imagen (opcional)',
                  border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Añadir')),
        ],
      ),
    );
    if (ok != true) return;
    final n = nombre.text.trim();
    final p = double.tryParse(precio.text.replaceAll(',', '.'));
    if (n.isEmpty || p == null) return;

    await _docRef.collection('productos_extra').add({
      'nombre': n,
      'precio': p,
      'categoria': categoria.text.trim(),
      'imagen_url': imagen.text.trim().isEmpty ? null : imagen.text.trim(),
      'iva_porcentaje': 10.0,
      'activo': true,
    });
  }

  Future<void> _eliminarProductoExtra(String id) async {
    await _docRef.collection('productos_extra').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(children: [
          Expanded(
            child: Text(_nombre,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: _renombrar,
            tooltip: 'Renombrar',
          ),
        ]),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.store, size: 18), text: 'Catálogo base'),
            Tab(icon: Icon(Icons.add_box, size: 18), text: 'Extras'),
          ],
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: _docRef.snapshots(),
            builder: (ctx, snapDoc) {
              if (!snapDoc.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data =
                  snapDoc.data!.data() as Map<String, dynamic>? ?? {};
              final ocultos =
                  List<String>.from(data['productos_ocultos'] ?? []);
              final imagenes =
                  Map<String, dynamic>.from(data['imagenes'] ?? {});

              return TabBarView(
                controller: _tabs,
                children: [
                  _TabCatalogoBase(
                    empresaId: widget.empresaId,
                    ocultos: ocultos,
                    imagenes: imagenes,
                    onToggleOculto: (id) => _toggleOculto(id, ocultos),
                    onCambiarImagen: (id) =>
                        _cambiarImagenBase(id, imagenes),
                  ),
                  _TabProductosExtra(
                    docRef: _docRef,
                    onAgregar: _agregarProductoExtra,
                    onEliminar: _eliminarProductoExtra,
                  ),
                ],
              );
            },
          ),
          if (_guardando)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

// ── Tab: catálogo base con toggles ────────────────────────────────────────────

class _TabCatalogoBase extends StatelessWidget {
  final String empresaId;
  final List<String> ocultos;
  final Map<String, dynamic> imagenes;
  final void Function(String) onToggleOculto;
  final void Function(String) onCambiarImagen;

  const _TabCatalogoBase({
    required this.empresaId,
    required this.ocultos,
    required this.imagenes,
    required this.onToggleOculto,
    required this.onCambiarImagen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('catalogo')
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text('Sin productos en el catálogo base.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            final nombre = data['nombre'] as String? ?? '—';
            final precio = (data['precio'] as num?)?.toDouble() ?? 0;
            final oculto = ocultos.contains(d.id);
            final tieneImagenPersonal = imagenes.containsKey(d.id);

            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Switch(
                  value: !oculto,
                  onChanged: (_) => onToggleOculto(d.id),
                  activeThumbColor: const Color(0xFF1565C0),
                ),
                title: Text(nombre,
                    style: TextStyle(
                        decoration:
                            oculto ? TextDecoration.lineThrough : null,
                        color: oculto ? Colors.grey : null)),
                subtitle: Text('€${precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: Icon(
                    tieneImagenPersonal
                        ? Icons.image
                        : Icons.add_photo_alternate_outlined,
                    color: tieneImagenPersonal
                        ? const Color(0xFF1565C0)
                        : Colors.grey,
                    size: 22,
                  ),
                  tooltip: tieneImagenPersonal
                      ? 'Imagen personalizada activa'
                      : 'Añadir imagen personalizada',
                  onPressed: () => onCambiarImagen(d.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab: productos extra ──────────────────────────────────────────────────────

class _TabProductosExtra extends StatelessWidget {
  final DocumentReference docRef;
  final VoidCallback onAgregar;
  final void Function(String) onEliminar;

  const _TabProductosExtra({
    required this.docRef,
    required this.onAgregar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: docRef.collection('productos_extra').snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Productos exclusivos de este TPV (no están en la base)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onAgregar,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir'),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text('Sin productos extra.',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final data = d.data() as Map<String, dynamic>;
                        final nombre = data['nombre'] as String? ?? '—';
                        final precio =
                            (data['precio'] as num?)?.toDouble() ?? 0;
                        final cat = data['categoria'] as String? ?? '';
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(nombre),
                            subtitle: Text(
                              '€${precio.toStringAsFixed(2)}'
                              '${cat.isNotEmpty ? '  ·  $cat' : ''}',
                              style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w600),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                              onPressed: () => onEliminar(d.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

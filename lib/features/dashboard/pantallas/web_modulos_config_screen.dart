import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/flux_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA: Configuración de módulos web por empresa
// Accesible desde GestionNegociosScreen (rol propietario).
// Permite al propietario configurar, para cualquier empresa:
//   · Secciones dinámicas (web_secciones): nombre, tipo, visibilidad, orden
//   · Módulos fijos: visibilidad y nombre personalizado
// ─────────────────────────────────────────────────────────────────────────────

// Todos los tipos que la app puede renderizar, con etiqueta e icono
const _kTipos = [
  _TipoInfo('blog',         'Blog / Noticias',      Icons.article_rounded),
  _TipoInfo('catalogo',     'Catálogo',              Icons.category_rounded),
  _TipoInfo('agenda',       'Agenda / Eventos',      Icons.event_note_rounded),
  _TipoInfo('carta',        'Carta / Menú',          Icons.restaurant_menu_rounded),
  _TipoInfo('menu_semanal', 'Menú semanal',          Icons.today_rounded),
  _TipoInfo('galeria',      'Galería de fotos',      Icons.photo_library_rounded),
  _TipoInfo('reservas',     'Reservas',              Icons.calendar_month_rounded),
  _TipoInfo('noticias',     'Noticias',              Icons.newspaper_rounded),
  _TipoInfo('entrevistas',  'Entrevistas',           Icons.mic_rounded),
  _TipoInfo('autores',      'Autores',               Icons.people_rounded),
  _TipoInfo('seleccion',    'Selección / Curaduria', Icons.star_rounded),
  _TipoInfo('ofertas',      'Ofertas',               Icons.local_offer_rounded),
  _TipoInfo('horarios',     'Horarios',              Icons.schedule_rounded),
  _TipoInfo('texto',        'Texto / Anuncio',       Icons.format_quote_rounded),
];

const _kModulosFijosDefault = [
  _ModFijo('mensajes',  'Mensajes',      Icons.chat_bubble_rounded,  Color(0xFF059669)),
  _ModFijo('analytics', 'Analytics',     Icons.bar_chart_rounded,    Color(0xFF0EA5E9)),
  _ModFijo('campanas',  'Campañas Email',Icons.campaign_rounded,     Color(0xFFE11D48)),
  _ModFijo('config',    'Configuración', Icons.settings_rounded,     Color(0xFF7C3AED)),
];

class WebModulosConfigScreen extends StatefulWidget {
  final String empresaId;
  final String nombreEmpresa;

  const WebModulosConfigScreen({
    super.key,
    required this.empresaId,
    required this.nombreEmpresa,
  });

  @override
  State<WebModulosConfigScreen> createState() => _WebModulosConfigScreenState();
}

class _WebModulosConfigScreenState extends State<WebModulosConfigScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late final TabController _tabs;

  // ── Estado secciones dinámicas ───────────────────────────────────────────
  List<_SeccionItem> _secciones = [];
  bool _cargandoSecciones = true;

  // ── Estado módulos fijos ─────────────────────────────────────────────────
  // clave: id (mensajes, analytics, campanas, config)
  Map<String, _ModFijoConfig> _fijosCfg = {};
  bool _cargandoFijos = true;
  bool _guardandoFijos = false;

  CollectionReference<Map<String, dynamic>> get _colSecciones => _db
      .collection('empresas').doc(widget.empresaId).collection('web_secciones');

  DocumentReference<Map<String, dynamic>> get _docModulosCfg => _db
      .collection('empresas').doc(widget.empresaId)
      .collection('configuracion').doc('web_modulos');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargarSecciones();
    _cargarFijos();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Carga secciones dinámicas ────────────────────────────────────────────

  Future<void> _cargarSecciones() async {
    setState(() => _cargandoSecciones = true);
    try {
      final snap = await _colSecciones.orderBy('orden').get();
      setState(() {
        _secciones = snap.docs.map(_SeccionItem.fromDoc).toList();
        _cargandoSecciones = false;
      });
    } catch (_) {
      setState(() => _cargandoSecciones = false);
    }
  }

  // ── Carga config módulos fijos ───────────────────────────────────────────

  Future<void> _cargarFijos() async {
    setState(() => _cargandoFijos = true);
    try {
      final doc = await _docModulosCfg.get();
      final data = doc.data() ?? {};
      final fijosRaw = data['fijos'] as List<dynamic>? ?? [];
      final mapa = <String, _ModFijoConfig>{};
      for (final f in fijosRaw) {
        final m = f as Map<String, dynamic>;
        final id = m['id'] as String? ?? '';
        if (id.isNotEmpty) {
          mapa[id] = _ModFijoConfig(
            id: id,
            nombre: m['nombre'] as String? ?? id,
            visible: m['visible'] as bool? ?? true,
          );
        }
      }
      // Asegurar que todos los módulos fijos tienen entrada
      for (final def in _kModulosFijosDefault) {
        mapa.putIfAbsent(def.id, () => _ModFijoConfig(
          id: def.id, nombre: def.nombre, visible: true,
        ));
      }
      setState(() { _fijosCfg = mapa; _cargandoFijos = false; });
    } catch (_) {
      final mapa = <String, _ModFijoConfig>{};
      for (final def in _kModulosFijosDefault) {
        mapa[def.id] = _ModFijoConfig(id: def.id, nombre: def.nombre, visible: true);
      }
      setState(() { _fijosCfg = mapa; _cargandoFijos = false; });
    }
  }

  // ── Guardar módulos fijos ────────────────────────────────────────────────

  Future<void> _guardarFijos() async {
    setState(() => _guardandoFijos = true);
    try {
      await _docModulosCfg.set({
        'fijos': _fijosCfg.values.map((c) => c.toMap()).toList(),
        'actualizado_en': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) FluxToast.exito(context, 'Módulos fijos guardados');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error guardando: $e');
    } finally {
      if (mounted) setState(() => _guardandoFijos = false);
    }
  }

  // ── CRUD secciones dinámicas ─────────────────────────────────────────────

  Future<void> _toggleSeccion(String docId, bool activa) async {
    await _colSecciones.doc(docId).update({'activa': activa});
    setState(() {
      final i = _secciones.indexWhere((s) => s.id == docId);
      if (i >= 0) _secciones[i] = _secciones[i].copyWith(activa: activa);
    });
  }

  Future<void> _guardarSeccion(_SeccionItem sec) async {
    await _colSecciones.doc(sec.id).update({
      'nombre': sec.nombre,
      'tipo':   sec.tipo,
      'activa': sec.activa,
    });
    final i = _secciones.indexWhere((s) => s.id == sec.id);
    if (i >= 0) setState(() => _secciones[i] = sec);
    if (mounted) FluxToast.exito(context, 'Sección actualizada');
  }

  Future<void> _crearSeccion(String nombre, String tipo) async {
    final orden = _secciones.length;
    final ref = await _colSecciones.add({
      'nombre': nombre,
      'tipo':   tipo,
      'activa': true,
      'orden':  orden,
      'creado_en': FieldValue.serverTimestamp(),
    });
    setState(() => _secciones.add(_SeccionItem(
      id: ref.id, nombre: nombre, tipo: tipo, orden: orden, activa: true,
    )));
    if (mounted) FluxToast.exito(context, 'Sección "$nombre" creada');
  }

  Future<void> _reordenar(int oldIdx, int newIdx) async {
    if (newIdx > oldIdx) newIdx--;
    final item = _secciones.removeAt(oldIdx);
    _secciones.insert(newIdx, item);
    setState(() {});
    // Actualizar orden en Firestore
    final batch = _db.batch();
    for (int i = 0; i < _secciones.length; i++) {
      batch.update(_colSecciones.doc(_secciones[i].id), {'orden': i});
    }
    await batch.commit();
  }

  // ── Diálogos ─────────────────────────────────────────────────────────────

  Future<void> _mostrarDialogoEditar(_SeccionItem sec) async {
    final nameCtrl  = TextEditingController(text: sec.nombre);
    String tipoSel  = sec.tipo;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Editar sección'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre visible'),
              ),
              const SizedBox(height: 16),
              const Text('Comportamiento / tipo', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _kTipos.map((t) {
                final sel = tipoSel == t.id;
                return ChoiceChip(
                  label: Text(t.label, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(t.icono, size: 14),
                  selected: sel,
                  onSelected: (_) => ss(() => tipoSel = t.id),
                  selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.15),
                );
              }).toList()),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _guardarSeccion(sec.copyWith(
                  nombre: nameCtrl.text.trim().isEmpty ? sec.nombre : nameCtrl.text.trim(),
                  tipo: tipoSel,
                ));
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _mostrarDialogoNueva() async {
    final nameCtrl = TextEditingController();
    String tipoSel = 'blog';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Nueva sección'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre visible en el hub'),
              ),
              const SizedBox(height: 16),
              const Text('Comportamiento / tipo', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _kTipos.map((t) {
                final sel = tipoSel == t.id;
                return ChoiceChip(
                  label: Text(t.label, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(t.icono, size: 14),
                  selected: sel,
                  onSelected: (_) => ss(() => tipoSel = t.id),
                  selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.15),
                );
              }).toList()),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final n = nameCtrl.text.trim();
                if (n.isEmpty) return;
                Navigator.pop(ctx);
                _crearSeccion(n, tipoSel);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _editarNombreFijo(String id) async {
    final cfg = _fijosCfg[id]!;
    final ctrl = TextEditingController(text: cfg.nombre);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar módulo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre visible'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final n = ctrl.text.trim();
              if (n.isNotEmpty) setState(() => _fijosCfg[id] = cfg.copyWith(nombre: n));
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: FluixAppBar(
        titulo: 'Módulos web — ${widget.nombreEmpresa}',
        showLeading: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.view_module_rounded), text: 'Secciones'),
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Módulos fijos'),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (_, __) => _tabs.index == 0
            ? FloatingActionButton.extended(
                onPressed: _mostrarDialogoNueva,
                icon: const Icon(Icons.add),
                label: const Text('Añadir sección'),
                backgroundColor: const Color(0xFF1565C0),
              )
            : FloatingActionButton.extended(
                onPressed: _guardandoFijos ? null : _guardarFijos,
                icon: _guardandoFijos
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('Guardar cambios'),
                backgroundColor: const Color(0xFF059669),
              ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildTabSecciones(),
          _buildTabFijos(),
        ],
      ),
    );
  }

  // ── Tab 1: Secciones dinámicas ───────────────────────────────────────────

  Widget _buildTabSecciones() {
    if (_cargandoSecciones) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_secciones.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.web_asset_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('Sin secciones. Pulsa + para crear la primera.',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ));
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _secciones.length,
      onReorder: _reordenar,
      proxyDecorator: (child, _, __) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemBuilder: (_, i) {
        final s = _secciones[i];
        final tipo = _kTipos.firstWhere((t) => t.id == s.tipo,
            orElse: () => const _TipoInfo('blog', 'Blog', Icons.article_rounded));
        return _SeccionCard(
          key: ValueKey(s.id),
          seccion: s,
          tipo: tipo,
          onToggle: (v) => _toggleSeccion(s.id, v),
          onEdit: () => _mostrarDialogoEditar(s),
        );
      },
    );
  }

  // ── Tab 2: Módulos fijos ─────────────────────────────────────────────────

  Widget _buildTabFijos() {
    if (_cargandoFijos) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            border: Border.all(color: const Color(0xFFFDD835)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFFF57F17), size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Estos módulos son fijos en la app. Puedes ocultarlos o cambiarles el nombre visible. '
              'Pulsa "Guardar cambios" para aplicar.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF5D4037)),
            )),
          ]),
        ),
        ..._kModulosFijosDefault.map((def) {
          final cfg = _fijosCfg[def.id] ?? _ModFijoConfig(id: def.id, nombre: def.nombre, visible: true);
          return _ModFijoCard(
            def: def,
            cfg: cfg,
            onVisibleChange: (v) => setState(() =>
                _fijosCfg[def.id] = cfg.copyWith(visible: v)),
            onEditNombre: () => _editarNombreFijo(def.id),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _SeccionCard extends StatelessWidget {
  final _SeccionItem seccion;
  final _TipoInfo tipo;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  const _SeccionCard({
    super.key,
    required this.seccion,
    required this.tipo,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: seccion.activa ? const Color(0xFFE2E8F0) : const Color(0xFFFFCDD2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: seccion.activa ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(tipo.icono,
              color: const Color(0xFF1565C0).withValues(alpha: seccion.activa ? 1 : 0.4),
              size: 20),
        ),
        title: Text(seccion.nombre,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: seccion.activa ? const Color(0xFF1E293B) : Colors.grey,
            )),
        subtitle: Text('${tipo.label} · orden ${seccion.orden}',
            style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              onPressed: onEdit,
              tooltip: 'Editar',
              color: const Color(0xFF1565C0),
            ),
            Switch.adaptive(
              value: seccion.activa,
              onChanged: onToggle,
              activeColor: const Color(0xFF1565C0),
            ),
            const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ModFijoCard extends StatelessWidget {
  final _ModFijo def;
  final _ModFijoConfig cfg;
  final ValueChanged<bool> onVisibleChange;
  final VoidCallback onEditNombre;

  const _ModFijoCard({
    required this.def,
    required this.cfg,
    required this.onVisibleChange,
    required this.onEditNombre,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cfg.visible ? const Color(0xFFE2E8F0) : const Color(0xFFFFCDD2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: def.color.withValues(alpha: cfg.visible ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(def.icono, color: def.color.withValues(alpha: cfg.visible ? 1 : 0.4), size: 20),
        ),
        title: Text(cfg.nombre,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cfg.visible ? const Color(0xFF1E293B) : Colors.grey,
            )),
        subtitle: Text('ID fijo: ${def.id}', style: const TextStyle(fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: onEditNombre,
            tooltip: 'Renombrar',
            color: const Color(0xFF1565C0),
          ),
          Switch.adaptive(
            value: cfg.visible,
            onChanged: onVisibleChange,
            activeColor: def.color,
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS INTERNOS
// ─────────────────────────────────────────────────────────────────────────────

class _TipoInfo {
  final String id;
  final String label;
  final IconData icono;
  const _TipoInfo(this.id, this.label, this.icono);
}

class _ModFijo {
  final String id;
  final String nombre;
  final IconData icono;
  final Color color;
  const _ModFijo(this.id, this.nombre, this.icono, this.color);
}

class _ModFijoConfig {
  final String id;
  final String nombre;
  final bool visible;
  const _ModFijoConfig({required this.id, required this.nombre, required this.visible});

  _ModFijoConfig copyWith({String? nombre, bool? visible}) =>
      _ModFijoConfig(id: id, nombre: nombre ?? this.nombre, visible: visible ?? this.visible);

  Map<String, dynamic> toMap() => {'id': id, 'nombre': nombre, 'visible': visible};
}

class _SeccionItem {
  final String id;
  final String nombre;
  final String tipo;
  final int orden;
  final bool activa;

  const _SeccionItem({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.orden,
    required this.activa,
  });

  factory _SeccionItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return _SeccionItem(
      id:     doc.id,
      nombre: d['nombre'] as String? ?? 'Sección',
      tipo:   (d['tipo'] as String? ?? 'blog').toLowerCase(),
      orden:  (d['orden'] as num?)?.toInt() ?? 0,
      activa: d['activa'] as bool? ?? true,
    );
  }

  _SeccionItem copyWith({String? nombre, String? tipo, bool? activa}) => _SeccionItem(
    id: id,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    orden: orden,
    activa: activa ?? this.activa,
  );
}

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../../models/negocio_publico_model.dart';
import '../../../services/negocios_publicos_service.dart';

class _EmpresaItem {
  final String id;
  final String nombre;
  const _EmpresaItem({required this.id, required this.nombre});
}

class GestionNegociosScreen extends StatefulWidget {
  final bool abrirCreacion;
  const GestionNegociosScreen({super.key, this.abrirCreacion = false});

  @override
  State<GestionNegociosScreen> createState() => _GestionNegociosScreenState();
}

class _GestionNegociosScreenState extends State<GestionNegociosScreen> {
  final NegociosPublicosService _service = NegociosPublicosService();
  final ImagePicker _picker = ImagePicker();

  CategoriaNegocio? _categoriaFiltro;
  String _busqueda = '';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    if (widget.abrirCreacion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _crearNegocio());
    }
  }

  static const Color _azul = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Negocios'),
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add_business), onPressed: _crearNegocio, tooltip: 'Nuevo negocio'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {}), tooltip: 'Actualizar'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'seed') await _ejecutarSeed();
              else if (value == 'eliminar_todos') await _confirmarEliminarTodos();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'seed', child: ListTile(
                  leading: Icon(Icons.auto_fix_high, color: Color(0xFF7C4DFF)),
                  title: Text('Cargar negocios Guadalajara'), contentPadding: EdgeInsets.zero)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'eliminar_todos', child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('Eliminar todos', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: Column(children: [
        _buildFiltros(),
        Expanded(child: _cargando
            ? const Center(child: CircularProgressIndicator(color: _azul))
            : _buildListaNegocios()),
      ]),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(children: [
        TextField(
          onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Buscar negocio...',
            prefixIcon: const Icon(Icons.search),
            filled: true, fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip(null, 'Todos', Icons.store),
            ...CategoriaNegocio.values.map((c) => _chip(c, c.label, _icono(c))),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(CategoriaNegocio? cat, String label, IconData icono) {
    final sel = _categoriaFiltro == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 16, color: sel ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 6),
          Text(label),
        ]),
        selected: sel,
        onSelected: (_) => setState(() => _categoriaFiltro = cat),
        backgroundColor: Colors.grey[100],
        selectedColor: _azul,
        labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey[700]),
      ),
    );
  }

  Widget _buildListaNegocios() {
    return StreamBuilder<List<NegocioPublico>>(
      stream: _service.obtenerTodos(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _azul));
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        var negocios = snap.data ?? [];
        if (_categoriaFiltro != null) negocios = negocios.where((n) => n.categoria == _categoriaFiltro).toList();
        if (_busqueda.isNotEmpty) negocios = negocios.where((n) =>
        n.nombre.toLowerCase().contains(_busqueda) ||
            (n.descripcion?.toLowerCase().contains(_busqueda) ?? false)).toList();
        if (negocios.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: negocios.length,
          itemBuilder: (context, i) => _buildTarjeta(negocios[i]),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.store_outlined, size: 80, color: Colors.grey[400]),
      const SizedBox(height: 16),
      Text('No hay negocios todavía', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _crearNegocio,
        icon: const Icon(Icons.add_business),
        label: const Text('Crear nuevo negocio'),
        style: ElevatedButton.styleFrom(backgroundColor: _azul, foregroundColor: Colors.white),
      ),
    ]));
  }

  Widget _buildTarjeta(NegocioPublico negocio) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirEdicion(negocio),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Column(children: [
              _miniSlotFoto(url: negocio.fotoUrl, label: 'Principal',
                  color: _colorCat(negocio.categoria), onTap: () => _cambiarFoto(negocio, secundaria: false)),
              const SizedBox(height: 6),
              _miniSlotFoto(url: negocio.fotoSecundariaUrl, label: 'Secundaria',
                  color: _colorCat(negocio.categoria).withValues(alpha: 0.5),
                  onTap: () => _cambiarFoto(negocio, secundaria: true)),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(negocio.nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                _badgeCategoria(negocio.categoria),
                if (negocio.ratingGoogle != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 13, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(negocio.ratingGoogle!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ]),
              if (negocio.descripcion != null) ...[
                const SizedBox(height: 4),
                Text(negocio.descripcion!, style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ])),
            Column(children: [
              Icon(negocio.activo ? Icons.check_circle : Icons.cancel,
                  color: negocio.activo ? Colors.green : Colors.red, size: 20),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _abrirEdicion(negocio),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: _azul.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.edit, size: 16, color: _azul),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _miniSlotFoto({required String? url, required String label, required Color color, required VoidCallback onTap}) {
    final tieneUrl = url != null && url.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          width: 72, height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: tieneUrl ? _azul.withValues(alpha: 0.3) : Colors.grey[300]!),
          ),
          child: tieneUrl
              ? ClipRRect(borderRadius: BorderRadius.circular(7),
              child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _iconoSinFoto(color)))
              : _iconoSinFoto(color),
        ),
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7))),
            child: Text(label, style: const TextStyle(fontSize: 8, color: Colors.white), textAlign: TextAlign.center),
          ),
        ),
        Positioned(top: 3, right: 3,
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(color: _azul, borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.camera_alt, size: 11, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  Widget _iconoSinFoto(Color color) => Center(
      child: Icon(Icons.add_photo_alternate_outlined, size: 22, color: color.withValues(alpha: 0.5)));

  Widget _badgeCategoria(CategoriaNegocio cat) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: _colorCat(cat).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(cat.label, style: TextStyle(fontSize: 10, color: _colorCat(cat), fontWeight: FontWeight.w500)),
  );

  Future<void> _crearNegocio() async {
    final negocioVacio = NegocioPublico(id: '', nombre: '', categoria: CategoriaNegocio.restaurantes, activo: true);
    await _abrirEdicion(negocioVacio, esNuevo: true);
  }

  Future<void> _abrirEdicion(NegocioPublico negocio, {bool esNuevo = false}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PanelEdicionNegocio(
        negocio: negocio, esNuevo: esNuevo, service: _service, picker: _picker,
        onFotoChanged: (sec) => _cambiarFoto(negocio, secundaria: sec),
      ),
    );
  }

  Future<void> _cambiarFoto(NegocioPublico negocio, {bool secundaria = false}) async {
    if (negocio.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Guarda el negocio primero'), backgroundColor: Colors.orange));
      return;
    }
    try {
      final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery,
          maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (imagen == null) return;
      setState(() => _cargando = true);
      if (kIsWeb) {
        final bytes = await imagen.readAsBytes();
        if (secundaria) await _service.subirFotoSecundariaBytes(negocio.id, bytes, imagen.name);
        else await _service.subirFotoBytes(negocio.id, bytes, imagen.name);
      } else {
        if (secundaria) await _service.subirFotoSecundaria(negocio.id, File(imagen.path));
        else await _service.subirFoto(negocio.id, File(imagen.path));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Foto ${secundaria ? 'secundaria' : 'principal'} actualizada'),
          backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ejecutarSeed() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cargar negocios'),
      content: const Text('Se cargarán negocios de ejemplo de Guadalajara. ¿Continuar?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), foregroundColor: Colors.white),
            child: const Text('Cargar')),
      ],
    ));
    if (ok != true) return;
    setState(() => _cargando = true);
    try {
      await _service.seedNegociosGuadalajara();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Negocios cargados'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmarEliminarTodos() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Eliminar todos'),
      content: const Text('¿Eliminar TODOS los negocios? No se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    setState(() => _cargando = true);
    try {
      await _service.eliminarTodos();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Eliminados'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Color _colorCat(CategoriaNegocio cat) {
    switch (cat) {
      case CategoriaNegocio.restaurantes: return const Color(0xFFE65100);
      case CategoriaNegocio.esteticas:    return const Color(0xFFE91E63);
      case CategoriaNegocio.peluquerias:  return const Color(0xFF9C27B0);
      case CategoriaNegocio.carnicerias:  return const Color(0xFFC62828);
      case CategoriaNegocio.tatuajes:     return const Color(0xFF1976D2);
      case CategoriaNegocio.general:      return const Color(0xFF607D8B);
      case CategoriaNegocio.clinicas:     return const Color(0xFF00897B);
      case CategoriaNegocio.gimnasios:    return const Color(0xFFE53935);
      case CategoriaNegocio.hoteles:      return const Color(0xFF8E24AA);
      case CategoriaNegocio.tiendas:      return const Color(0xFFFF6F00);
      case CategoriaNegocio.fruterias:    return const Color(0xFF4CAF50);
    }
  }

  IconData _icono(CategoriaNegocio cat) {
    switch (cat) {
      case CategoriaNegocio.restaurantes: return Icons.restaurant;
      case CategoriaNegocio.esteticas:    return Icons.spa;
      case CategoriaNegocio.peluquerias:  return Icons.content_cut;
      case CategoriaNegocio.carnicerias:  return Icons.storefront;
      case CategoriaNegocio.tatuajes:     return Icons.brush;
      case CategoriaNegocio.general:      return Icons.business;
      case CategoriaNegocio.clinicas:     return Icons.local_hospital;
      case CategoriaNegocio.gimnasios:    return Icons.fitness_center;
      case CategoriaNegocio.hoteles:      return Icons.hotel;
      case CategoriaNegocio.tiendas:      return Icons.shopping_bag;
      case CategoriaNegocio.fruterias:    return Icons.local_grocery_store;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PANEL DE EDICIÓN — ahora con 6 tabs (+ Servicios)
// ══════════════════════════════════════════════════════════════════════════════

class _PanelEdicionNegocio extends StatefulWidget {
  final NegocioPublico negocio;
  final bool esNuevo;
  final NegociosPublicosService service;
  final ImagePicker picker;
  final Function(bool secundaria) onFotoChanged;

  const _PanelEdicionNegocio({
    required this.negocio, required this.esNuevo,
    required this.service, required this.picker,
    required this.onFotoChanged,
  });

  @override
  State<_PanelEdicionNegocio> createState() => _PanelEdicionNegocioState();
}

class _PanelEdicionNegocioState extends State<_PanelEdicionNegocio>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _webCtrl;
  late final TextEditingController _instagramCtrl;
  late final TextEditingController _facebookCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _emailNotificacionesCtrl;
  late final TextEditingController _googleMapsCtrl;
  late final TextEditingController _ratingCtrl;
  late final TextEditingController _numResenasCtrl;
  late final TextEditingController _precioMedioCtrl;
  late final TextEditingController _especialidadesCtrl;
  late final TextEditingController _taglineCtrl;
  late final TextEditingController _placeIdCtrl;
  late final TextEditingController _formularioTituloCtrl;
  late final TextEditingController _formularioBotonCtrl;
  late List<CampoPersonalizado> _camposFormulario;

  String _empresaIdVinculada = '';
  List<_EmpresaItem> _empresasDisponibles = [];
  bool _cargandoEmpresas = true;

  late CategoriaNegocio _categoria;
  late bool _activo, _destacado, _aceptaTarjeta, _tieneParking;
  late bool _accesibleSillaRuedas, _tieneWifi, _admiteMascotas, _tieneTerraza, _reservasOnline;
  bool _guardando = false;

  final Map<String, Map<String, dynamic>> _horario = {};
  static const List<String> _dias = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
  static const Color _azul = Color(0xFF0D47A1);

  // ── Colores y categorías rápidas para servicios ──────────────────────────
  static const _categoriasServicio = [
    'Corte', 'Color', 'Manicura', 'Pedicura', 'Masaje',
    'Facial', 'Barba', 'Depilación', 'Tratamientos', 'Peinados',
    'Reservas', 'Experiencias',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this); // ← 6 tabs
    final n = widget.negocio;
    _nombreCtrl              = TextEditingController(text: n.nombre);
    _descripcionCtrl         = TextEditingController(text: n.descripcion ?? '');
    _direccionCtrl           = TextEditingController(text: n.direccion ?? '');
    _telefonoCtrl            = TextEditingController(text: n.telefono ?? '');
    _emailCtrl               = TextEditingController(text: n.email ?? '');
    _webCtrl                 = TextEditingController(text: n.web ?? '');
    _instagramCtrl           = TextEditingController(text: n.instagram ?? '');
    _facebookCtrl            = TextEditingController(text: n.facebook ?? '');
    _whatsappCtrl            = TextEditingController(text: n.whatsapp ?? '');
    _emailNotificacionesCtrl = TextEditingController(text: n.emailNotificaciones ?? '');
    _googleMapsCtrl          = TextEditingController(text: n.googleMapsUrl ?? '');
    _empresaIdVinculada      = n.empresaIdVinculada;
    _ratingCtrl              = TextEditingController(text: n.ratingGoogle?.toStringAsFixed(1) ?? '');
    _numResenasCtrl          = TextEditingController(text: n.numResenas != null ? '${n.numResenas}' : '');
    _precioMedioCtrl         = TextEditingController(text: n.precioMedio ?? '');
    _especialidadesCtrl      = TextEditingController(text: (n.especialidades ?? []).join(', '));
    _taglineCtrl             = TextEditingController(text: n.tagline ?? '');
    _placeIdCtrl             = TextEditingController(text: n.placeId ?? '');
    _formularioTituloCtrl    = TextEditingController(text: n.formularioTitulo ?? '');
    _formularioBotonCtrl     = TextEditingController(text: n.formularioBoton ?? '');
    _camposFormulario        = List<CampoPersonalizado>.from(n.camposPersonalizados ?? []);
    _categoria               = n.categoria;
    _activo                  = n.activo;
    _destacado               = n.destacado ?? false;
    _aceptaTarjeta           = n.aceptaTarjeta ?? false;
    _tieneParking            = n.tieneParking ?? false;
    _accesibleSillaRuedas    = n.accesibleSillaRuedas ?? false;
    _tieneWifi               = n.tieneWifi ?? false;
    _admiteMascotas          = n.admiteMascotas ?? false;
    _tieneTerraza            = n.tieneTerraza ?? false;
    _reservasOnline          = n.reservasOnline ?? false;
    for (final dia in _dias) {
      final e = n.horario?[dia];
      _horario[dia] = {'cerrado': e?['cerrado'] ?? false, 'apertura': e?['apertura'] ?? '09:00', 'cierre': e?['cierre'] ?? '21:00'};
    }
    _cargarEmpresas();
  }

  Future<void> _cargarEmpresas() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('empresas').orderBy('nombre').get();
      final items = snap.docs.map((d) => _EmpresaItem(id: d.id, nombre: (d.data()['nombre'] as String?) ?? d.id)).toList();
      if (mounted) setState(() { _empresasDisponibles = items; _cargandoEmpresas = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoEmpresas = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_nombreCtrl, _descripcionCtrl, _direccionCtrl, _telefonoCtrl,
      _emailCtrl, _webCtrl, _instagramCtrl, _facebookCtrl, _whatsappCtrl,
      _emailNotificacionesCtrl, _googleMapsCtrl, _ratingCtrl, _numResenasCtrl,
      _precioMedioCtrl, _especialidadesCtrl, _taglineCtrl, _placeIdCtrl,
      _formularioTituloCtrl, _formularioBotonCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.97, minChildSize: 0.5, expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: Text(
                  widget.esNuevo ? 'Nuevo negocio' : 'Editar: ${widget.negocio.nombre}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
              Row(children: [
                Text(_activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(fontSize: 12, color: _activo ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                Switch(value: _activo, onChanged: (v) => setState(() => _activo = v), activeColor: Colors.green),
              ]),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(backgroundColor: _azul),
                child: _guardando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.esNuevo ? 'Crear' : 'Guardar'),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            labelColor: _azul, unselectedLabelColor: Colors.grey,
            indicatorColor: _azul, isScrollable: true,
            tabs: const [
              Tab(text: 'Info'),
              Tab(text: 'Contacto'),
              Tab(text: 'Horario'),
              Tab(text: 'Servicios'), // ← NUEVA TAB
              Tab(text: 'Extras'),
              Tab(text: 'Formulario'),
            ],
          ),
          Expanded(child: TabBarView(controller: _tabs, children: [
            _tabInfo(scroll),
            _tabContacto(scroll),
            _tabHorario(scroll),
            _tabServicios(),      // ← NUEVA TAB
            _tabExtras(scroll),
            _tabFormulario(scroll),
          ])),
        ]),
      ),
    );
  }

  // ── TAB SERVICIOS ──────────────────────────────────────────────────────────
  Widget _tabServicios() {
    // Necesitamos el negocioId — si es nuevo aún no existe
    if (widget.esNuevo || widget.negocio.id.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.content_cut_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Crea el negocio primero',
              style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Una vez guardado podrás añadir el catálogo de servicios desde aquí.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
        ]),
      ));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(widget.negocio.id)
          .collection('servicios')
          .orderBy('orden')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _azul));
        }
        final docs = snap.data?.docs ?? [];

        return Column(children: [
          // Header con contador y botón añadir
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(children: [
              Text('${docs.length} servicio${docs.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _mostrarDialogoServicio(negocioId: widget.negocio.id, orden: docs.length),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              ),
            ]),
          ),

          // Lista
          Expanded(
            child: docs.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.spa_outlined, size: 52, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('Sin servicios todavía', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text('Pulsa "Añadir" para crear el primer servicio',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final doc  = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final nombre   = data['nombre'] as String? ?? '';
                final categoria = data['categoria'] as String? ?? '';
                final precio   = data['precio'] as num?;
                final precioD  = data['precio_desde'] as num?;
                final duracion = data['duracion'] as int?;
                final publico  = data['publico'] as String? ?? 'todos';
                final activo   = data['activo'] as bool? ?? true;

                final precioTxt = precio != null
                    ? '€${precio.toStringAsFixed(precio % 1 == 0 ? 0 : 2)}'
                    : precioD != null
                    ? 'Desde €${precioD.toStringAsFixed(precioD % 1 == 0 ? 0 : 2)}'
                    : '—';

                final colorPublico = publico == 'femenino' || publico == 'mujer'
                    ? const Color(0xFFE91E63)
                    : publico == 'masculino' || publico == 'hombre'
                    ? const Color(0xFF1976D2)
                    : _azul;

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _mostrarDialogoServicio(
                        negocioId: widget.negocio.id, doc: doc, orden: i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        // Barra color
                        Container(width: 3, height: 44,
                            decoration: BoxDecoration(
                                color: activo ? colorPublico : Colors.grey[300],
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        // Icono
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: colorPublico.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(_iconCatServicio(categoria), size: 16, color: colorPublico),
                        ),
                        const SizedBox(width: 10),
                        // Info
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(nombre,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: activo ? Colors.black87 : Colors.grey),
                                overflow: TextOverflow.ellipsis)),
                            if (!activo)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.red.shade200)),
                                child: Text('Oculto', style: TextStyle(fontSize: 9, color: Colors.red.shade700)),
                              ),
                          ]),
                          const SizedBox(height: 3),
                          Row(children: [
                            Text(precioTxt,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: activo ? colorPublico : Colors.grey)),
                            if (duracion != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.access_time_rounded, size: 11, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Text(duracion >= 60
                                  ? '${duracion ~/ 60}h${duracion % 60 > 0 ? ' ${duracion % 60}m' : ''}'
                                  : '${duracion}min',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ],
                            if (categoria.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                    color: colorPublico.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(categoria,
                                    style: TextStyle(fontSize: 9, color: colorPublico, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ]),
                        ])),
                        // Acciones
                        IconButton(
                          onPressed: () => _mostrarDialogoServicio(
                              negocioId: widget.negocio.id, doc: doc, orden: i),
                          icon: const Icon(Icons.edit_outlined, size: 18, color: _azul),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _eliminarServicio(widget.negocio.id, doc.id, nombre),
                          icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _mostrarDialogoServicio({
    required String negocioId,
    QueryDocumentSnapshot? doc,
    required int orden,
  }) async {
    final data = doc?.data() as Map<String, dynamic>?;

    final nombreCtrl    = TextEditingController(text: data?['nombre'] ?? '');
    final descCtrl      = TextEditingController(text: data?['descripcion'] ?? '');
    final catCtrl       = TextEditingController(text: data?['categoria'] ?? '');
    final precioCtrl    = TextEditingController(text: data?['precio']?.toString() ?? '');
    final precioDesdeCtrl = TextEditingController(text: data?['precio_desde']?.toString() ?? '');

    bool usaPrecioDesde = data?['precio_desde'] != null;
    int duracion = data?['duracion'] as int? ?? 60;
    String publico = data?['publico'] as String? ?? 'todos';
    bool activo = data?['activo'] as bool? ?? true;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: BoxDecoration(
                  color: _azul.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(children: [
                  Icon(Icons.content_cut_rounded, color: _azul, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(doc == null ? 'Nuevo servicio' : 'Editar servicio',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  Row(children: [
                    Text(activo ? 'Visible' : 'Oculto',
                        style: TextStyle(fontSize: 11, color: activo ? Colors.green : Colors.red)),
                    Switch(value: activo, onChanged: (v) => setSt(() => activo = v),
                        activeColor: Colors.green, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ]),
                ]),
              ),

              // Contenido scrollable
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Nombre
                  TextField(controller: nombreCtrl, autofocus: true,
                      decoration: _deco('Nombre del servicio *', Icons.label_outline)),
                  const SizedBox(height: 12),

                  // Descripción
                  TextField(controller: descCtrl, maxLines: 2,
                      decoration: _deco('Descripción (opcional)', Icons.notes)),
                  const SizedBox(height: 12),

                  // Categoría
                  TextField(controller: catCtrl,
                      decoration: _deco('Categoría', Icons.category_outlined)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6,
                    children: _categoriasServicio.map((cat) {
                      final sel = catCtrl.text == cat;
                      return GestureDetector(
                        onTap: () => setSt(() => catCtrl.text = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel ? _azul : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(cat, style: TextStyle(
                              fontSize: 11, color: sel ? Colors.white : Colors.grey[700],
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Precio
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('Precio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setSt(() => usaPrecioDesde = !usaPrecioDesde),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: usaPrecioDesde ? _azul.withValues(alpha: 0.1) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: usaPrecioDesde ? _azul : Colors.grey[300]!),
                            ),
                            child: Text('Desde', style: TextStyle(
                                fontSize: 10, color: usaPrecioDesde ? _azul : Colors.grey[600],
                                fontWeight: usaPrecioDesde ? FontWeight.w700 : FontWeight.w400)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      TextField(
                        controller: usaPrecioDesde ? precioDesdeCtrl : precioCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _deco(usaPrecioDesde ? 'Precio mínimo €' : 'Precio fijo €', Icons.euro),
                      ),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Duración', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(child: Slider(
                          value: duracion.toDouble(), min: 10, max: 240, divisions: 23,
                          activeColor: _azul, inactiveColor: Colors.grey[200]!,
                          onChanged: (v) => setSt(() => duracion = v.toInt()),
                        )),
                        Text(duracion >= 60
                            ? '${duracion ~/ 60}h${duracion % 60 > 0 ? '${duracion % 60}m' : ''}'
                            : '${duracion}m',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _azul)),
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 12),

                  // Público
                  const Text('Público', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (final opt in [('todos','Todos',_azul), ('femenino','Mujer',const Color(0xFFE91E63)), ('masculino','Hombre',const Color(0xFF1976D2))])
                      Expanded(child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setSt(() => publico = opt.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: publico == opt.$1 ? opt.$3.withValues(alpha: 0.1) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: publico == opt.$1 ? opt.$3 : Colors.grey[300]!,
                                  width: publico == opt.$1 ? 1.5 : 0.8),
                            ),
                            child: Text(opt.$2, textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12,
                                    color: publico == opt.$1 ? opt.$3 : Colors.grey[600],
                                    fontWeight: publico == opt.$1 ? FontWeight.w700 : FontWeight.w400)),
                          ),
                        ),
                      )),
                  ]),
                ]),
              )),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: FilledButton(
                    onPressed: () async {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) return;
                      final precioVal = double.tryParse(
                          (usaPrecioDesde ? precioDesdeCtrl : precioCtrl).text.trim());
                      final datos = <String, dynamic>{
                        'nombre':      nombre,
                        'descripcion': descCtrl.text.trim(),
                        'categoria':   catCtrl.text.trim(),
                        'duracion':    duracion,
                        'publico':     publico,
                        'activo':      activo,
                        'orden':       orden,
                      };
                      if (precioVal != null) {
                        if (usaPrecioDesde) datos['precio_desde'] = precioVal;
                        else datos['precio'] = precioVal;
                      }
                      Navigator.pop(ctx);
                      try {
                        final col = FirebaseFirestore.instance
                            .collection('negocios_publicos').doc(negocioId).collection('servicios');
                        if (doc == null) await col.add(datos);
                        else await col.doc(doc.id).update(datos);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(doc == null ? '✅ Servicio añadido' : '✅ Servicio actualizado'),
                            backgroundColor: Colors.green));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: _azul),
                    child: Text(doc == null ? 'Añadir' : 'Guardar',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
    nombreCtrl.dispose(); descCtrl.dispose(); catCtrl.dispose();
    precioCtrl.dispose(); precioDesdeCtrl.dispose();
  }

  Future<void> _eliminarServicio(String empresaId, String docId, String nombre) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar servicio'),
      content: Text('¿Eliminar "$nombre"? No se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('empresas').doc(empresaId).collection('servicios').doc(docId).delete();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Servicio eliminado'), backgroundColor: Colors.orange));
  }

  IconData _iconCatServicio(String cat) {
    switch (cat.toLowerCase()) {
      case 'corte': case 'pelo':        return Icons.content_cut_rounded;
      case 'color': case 'tinte':       return Icons.color_lens_rounded;
      case 'manicura': case 'pedicura': return Icons.spa_rounded;
      case 'masaje':                    return Icons.self_improvement_rounded;
      case 'facial':                    return Icons.face_retouching_natural_rounded;
      case 'barba':                     return Icons.face_rounded;
      case 'depilación':                return Icons.auto_fix_high_rounded;
      case 'tratamientos':              return Icons.science_rounded;
      case 'reservas':                  return Icons.event_available_rounded;
      default:                          return Icons.star_rounded;
    }
  }

  // ── RESTO DE TABS (sin cambios) ────────────────────────────────────────────

  Widget _tabInfo(ScrollController scroll) {
    return ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
      Row(children: [
        Expanded(flex: 6, child: _slotFotoGrande(url: widget.negocio.fotoUrl, label: 'Foto principal', onTap: () => widget.onFotoChanged(false))),
        const SizedBox(width: 8),
        Expanded(flex: 4, child: _slotFotoGrande(url: widget.negocio.fotoSecundariaUrl, label: 'Foto secundaria', onTap: () => widget.onFotoChanged(true), esSecundaria: true)),
      ]),
      const SizedBox(height: 16),
      _campo(_nombreCtrl, 'Nombre del negocio *', Icons.store, capitalizacion: TextCapitalization.words),
      const SizedBox(height: 12),
      _campo(_taglineCtrl, 'Slogan / Tagline', Icons.format_quote, hint: 'Ej: El mejor sabor de la ciudad'),
      const SizedBox(height: 12),
      TextField(controller: _descripcionCtrl, maxLines: 4, textCapitalization: TextCapitalization.sentences,
          decoration: _deco('Descripción', Icons.description, hint: 'Descripción completa del negocio')),
      const SizedBox(height: 12),
      DropdownButtonFormField<CategoriaNegocio>(
        value: _categoria, decoration: _deco('Categoría', Icons.category),
        items: CategoriaNegocio.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
        onChanged: (v) => setState(() => _categoria = v ?? _categoria),
      ),
      const SizedBox(height: 12),
      _campo(_precioMedioCtrl, 'Precio medio', Icons.euro, hint: 'Ej: 10-20€ por persona'),
      const SizedBox(height: 12),
      _campo(_especialidadesCtrl, 'Especialidades (separadas por coma)', Icons.star_outline, hint: 'Ej: Pizza, Pasta, Vinos'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _campo(_ratingCtrl, 'Rating Google', Icons.star, keyboard: TextInputType.numberWithOptions(decimal: true), hint: '4.5')),
        const SizedBox(width: 12),
        Expanded(child: _campo(_numResenasCtrl, 'Nº de reseñas', Icons.rate_review, keyboard: TextInputType.number, hint: '120')),
      ]),
      const SizedBox(height: 12),
      _campo(_placeIdCtrl, 'Google Place ID', Icons.place, hint: 'ChIJ...'),
    ]);
  }

  Widget _tabContacto(ScrollController scroll) {
    return ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
      _campo(_direccionCtrl, 'Dirección', Icons.location_on, capitalizacion: TextCapitalization.words),
      const SizedBox(height: 12),
      _campo(_telefonoCtrl, 'Teléfono', Icons.phone, keyboard: TextInputType.phone),
      const SizedBox(height: 12),
      _campo(_whatsappCtrl, 'WhatsApp', Icons.chat, keyboard: TextInputType.phone, hint: '+34 600 000 000'),
      const SizedBox(height: 12),
      _campo(_emailCtrl, 'Email público', Icons.email, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 12),
      _campo(_emailNotificacionesCtrl, 'Email notificaciones', Icons.mark_email_read, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 12),
      _campo(_webCtrl, 'Página web', Icons.language, keyboard: TextInputType.url, hint: 'https://...'),
      const SizedBox(height: 12),
      _campo(_instagramCtrl, 'Instagram', Icons.camera_alt, hint: '@nombreusuario'),
      const SizedBox(height: 12),
      _campo(_facebookCtrl, 'Facebook', Icons.facebook, hint: 'URL de Facebook'),
      const SizedBox(height: 12),
      _campo(_googleMapsCtrl, 'Google Maps URL', Icons.map, keyboard: TextInputType.url),
    ]);
  }

  Widget _tabHorario(ScrollController scroll) {
    return ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
      const Text('Horario de apertura', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _copiarHorarioSemana,
        icon: const Icon(Icons.content_copy, size: 16),
        label: const Text('Aplicar horario L-V a todos los días', style: TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 12),
      ..._dias.map((dia) => _filaHorario(dia)),
    ]);
  }

  Widget _filaHorario(String dia) {
    final h = _horario[dia]!;
    final cerrado = h['cerrado'] as bool;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          SizedBox(width: 80, child: Text(dia, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Switch(value: !cerrado, onChanged: (v) => setState(() => h['cerrado'] = !v),
              activeColor: Colors.green, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          if (cerrado)
            const Expanded(child: Text('Cerrado', style: TextStyle(fontSize: 12, color: Colors.red)))
          else ...[
            Expanded(child: DropdownButton<String>(
              value: h['apertura'], isDense: true,
              items: _slotsHorario().map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => h['apertura'] = v),
            )),
            const Text(' – ', style: TextStyle(color: Colors.grey)),
            Expanded(child: DropdownButton<String>(
              value: h['cierre'], isDense: true,
              items: _slotsHorario().map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => h['cierre'] = v),
            )),
          ],
        ]),
      ),
    );
  }

  List<String> _slotsHorario() {
    final slots = <String>[];
    for (var h = 0; h < 24; h++) {
      for (var m = 0; m < 60; m += 30) {
        slots.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      }
    }
    return slots;
  }

  void _copiarHorarioSemana() {
    final lunes = _horario['Lunes']!;
    setState(() { for (final dia in _dias) _horario[dia] = Map<String, dynamic>.from(lunes); });
  }

  Widget _tabExtras(ScrollController scroll) {
    return ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
      const Text('Empresa vinculada', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (_cargandoEmpresas)
        const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(strokeWidth: 2)))
      else
        DropdownButtonFormField<String>(
          value: _empresaIdVinculada.isEmpty ? null : _empresaIdVinculada,
          decoration: _deco('Empresa vinculada', Icons.business),
          hint: const Text('Sin vinculación'),
          items: [
            const DropdownMenuItem<String>(value: '', child: Text('— Sin vinculación —')),
            ..._empresasDisponibles.map((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.nombre, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => setState(() => _empresaIdVinculada = v ?? ''),
        ),
      const Divider(height: 28),
      _switchRow('Negocio destacado', Icons.star, _destacado, (v) => setState(() => _destacado = v)),
      _switchRow('Reservas online activadas', Icons.event_available, _reservasOnline, (v) => setState(() => _reservasOnline = v)),
      const Divider(height: 24),
      const Text('Características', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _switchRow('Acepta tarjeta', Icons.credit_card, _aceptaTarjeta, (v) => setState(() => _aceptaTarjeta = v)),
      _switchRow('Tiene parking', Icons.local_parking, _tieneParking, (v) => setState(() => _tieneParking = v)),
      _switchRow('Accesible silla de ruedas', Icons.accessible, _accesibleSillaRuedas, (v) => setState(() => _accesibleSillaRuedas = v)),
      _switchRow('Tiene WiFi', Icons.wifi, _tieneWifi, (v) => setState(() => _tieneWifi = v)),
      _switchRow('Admite mascotas', Icons.pets, _admiteMascotas, (v) => setState(() => _admiteMascotas = v)),
      _switchRow('Tiene terraza', Icons.outdoor_grill, _tieneTerraza, (v) => setState(() => _tieneTerraza = v)),
      const SizedBox(height: 24),
      if (!widget.esNuevo)
        OutlinedButton.icon(
          onPressed: _confirmarEliminar,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: const Text('Eliminar este negocio', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 44)),
        ),
    ]);
  }

  static const _tiposFormulario = <(String, String)>[
    ('texto', 'Texto libre'), ('textarea', 'Párrafo'), ('numero', 'Número'),
    ('fecha', 'Fecha'), ('hora', 'Hora'), ('selector', 'Desplegable'),
    ('checkbox', 'Casilla'), ('email', 'Email'), ('telefono', 'Teléfono'),
  ];

  Widget _tabFormulario(ScrollController scroll) {
    return ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
      const Text('Título y botón', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(controller: _formularioTituloCtrl, decoration: _deco('Título del formulario', Icons.title, hint: 'ej: Reservar mesa')),
      const SizedBox(height: 10),
      TextField(controller: _formularioBotonCtrl, decoration: _deco('Texto del botón', Icons.touch_app, hint: 'ej: Confirmar reserva')),
      const SizedBox(height: 20),
      Row(children: [
        const Text('Campos del formulario', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16), label: const Text('Añadir campo', style: TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(backgroundColor: _azul),
          onPressed: () => _abrirDialogoCampo(null),
        ),
      ]),
      const SizedBox(height: 8),
      if (_camposFormulario.isEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 18), SizedBox(width: 10),
            Expanded(child: Text('Sin campos personalizados. Se usará el formulario por defecto.',
                style: TextStyle(fontSize: 12, color: Colors.blue))),
          ]),
        )
      else
        ReorderableListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          onReorder: (o, n) => setState(() { final item = _camposFormulario.removeAt(o); _camposFormulario.insert(n > o ? n - 1 : n, item); }),
          itemCount: _camposFormulario.length,
          itemBuilder: (ctx, i) {
            final c = _camposFormulario[i];
            return Card(
              key: ValueKey(c.id), margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(dense: true,
                leading: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                title: Text(c.label, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${c.tipo}${c.obligatorio ? ' • Obligatorio' : ''}',
                    style: TextStyle(fontSize: 11, color: c.obligatorio ? Colors.red.shade700 : Colors.grey)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue), onPressed: () => _abrirDialogoCampo(i), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => setState(() => _camposFormulario.removeAt(i)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ]),
              ),
            );
          },
        ),
    ]);
  }

  Future<void> _abrirDialogoCampo(int? editIdx) async {
    final existing = editIdx != null ? _camposFormulario[editIdx] : null;
    String tipoSel = existing?.tipo ?? 'texto';
    final labelCtrl   = TextEditingController(text: existing?.label ?? '');
    final opcionesCtrl = TextEditingController(text: (existing?.opciones ?? []).join(', '));
    bool obligatorio  = existing?.obligatorio ?? false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: Text(existing == null ? 'Nuevo campo' : 'Editar campo'),
        content: SizedBox(width: 340, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Nombre del campo *', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: tipoSel, decoration: const InputDecoration(labelText: 'Tipo de campo', border: OutlineInputBorder(), isDense: true),
            items: _tiposFormulario.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setSt(() => tipoSel = v!),
          ),
          if (tipoSel == 'selector') ...[
            const SizedBox(height: 12),
            TextField(controller: opcionesCtrl, decoration: const InputDecoration(labelText: 'Opciones (separadas por coma)', border: OutlineInputBorder(), isDense: true)),
          ],
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: obligatorio,
              onChanged: (v) => setSt(() => obligatorio = v ?? false),
              title: const Text('Campo obligatorio', style: TextStyle(fontSize: 13)), activeColor: _azul),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _azul),
              onPressed: () {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) return;
                final campo = CampoPersonalizado(
                  id: existing?.id ?? '${DateTime.now().millisecondsSinceEpoch}',
                  label: label, tipo: tipoSel, obligatorio: obligatorio,
                  opciones: tipoSel == 'selector'
                      ? opcionesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                      : null,
                );
                setState(() { if (editIdx != null) _camposFormulario[editIdx] = campo; else _camposFormulario.add(campo); });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar')),
        ],
      )),
    );
    labelCtrl.dispose(); opcionesCtrl.dispose();
  }

  Widget _slotFotoGrande({required String? url, required String label, required VoidCallback onTap, bool esSecundaria = false}) {
    final tieneUrl = url != null && url.isNotEmpty;
    return GestureDetector(onTap: onTap, child: Container(
      height: 130,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[100],
          border: Border.all(color: tieneUrl ? _azul.withValues(alpha: 0.3) : Colors.grey[300]!, width: tieneUrl ? 1.5 : 1)),
      child: Stack(children: [
        if (tieneUrl) ClipRRect(borderRadius: BorderRadius.circular(11),
            child: Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                errorBuilder: (_, __, ___) => _placeholderGrande(esSecundaria)))
        else _placeholderGrande(esSecundaria),
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11))),
          child: Row(children: [
            const Icon(Icons.camera_alt, size: 12, color: Colors.white), const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
          ]),
        )),
      ]),
    ));
  }

  Widget _placeholderGrande(bool esSecundaria) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(esSecundaria ? Icons.add_photo_alternate_outlined : Icons.photo_camera_outlined, size: 28, color: Colors.grey[400]),
    const SizedBox(height: 4),
    Text('Toca para añadir', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
  ]));

  Widget _switchRow(String label, IconData icono, bool valor, ValueChanged<bool> onChanged) => SwitchListTile(
    dense: true,
    title: Row(children: [Icon(icono, size: 18, color: Colors.grey[600]), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 13))]),
    value: valor, onChanged: onChanged, activeColor: _azul, contentPadding: EdgeInsets.zero,
  );

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _guardando = true);
    try {
      final especialidades = _especialidadesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final negocioActualizado = widget.negocio.copyWith(
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        emailNotificaciones: _emailNotificacionesCtrl.text.trim().isEmpty ? null : _emailNotificacionesCtrl.text.trim(),
        web: _webCtrl.text.trim().isEmpty ? null : _webCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
        facebook: _facebookCtrl.text.trim().isEmpty ? null : _facebookCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        googleMapsUrl: _googleMapsCtrl.text.trim().isEmpty ? null : _googleMapsCtrl.text.trim(),
        ratingGoogle: double.tryParse(_ratingCtrl.text.replaceAll(',', '.')),
        numResenas: int.tryParse(_numResenasCtrl.text),
        precioMedio: _precioMedioCtrl.text.trim().isEmpty ? null : _precioMedioCtrl.text.trim(),
        especialidades: especialidades.isEmpty ? null : especialidades,
        tagline: _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
        placeId: _placeIdCtrl.text.trim().isEmpty ? null : _placeIdCtrl.text.trim(),
        empresaIdVinculada: _empresaIdVinculada,
        categoria: _categoria, activo: _activo, destacado: _destacado,
        aceptaTarjeta: _aceptaTarjeta, tieneParking: _tieneParking,
        accesibleSillaRuedas: _accesibleSillaRuedas, tieneWifi: _tieneWifi,
        admiteMascotas: _admiteMascotas, tieneTerraza: _tieneTerraza,
        reservasOnline: _reservasOnline, horario: _horario,
        formularioTitulo: _formularioTituloCtrl.text.trim().isEmpty ? null : _formularioTituloCtrl.text.trim(),
        formularioBoton: _formularioBotonCtrl.text.trim().isEmpty ? null : _formularioBotonCtrl.text.trim(),
        camposPersonalizados: _camposFormulario.isEmpty ? null : _camposFormulario,
      );
      if (widget.esNuevo) await widget.service.crear(negocioActualizado);
      else await widget.service.actualizar(negocioActualizado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.esNuevo ? '✅ Negocio creado' : '✅ Cambios guardados'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarEliminar() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('¿Eliminar negocio?'),
      content: Text('Se eliminará "${widget.negocio.nombre}". No se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      await widget.service.eliminar(widget.negocio.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Eliminado'), backgroundColor: Colors.orange)); Navigator.pop(context); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icono,
      {TextInputType keyboard = TextInputType.text, TextCapitalization capitalizacion = TextCapitalization.none, String? hint}) =>
      TextField(controller: ctrl, keyboardType: keyboard, textCapitalization: capitalizacion, decoration: _deco(label, icono, hint: hint));

  InputDecoration _deco(String label, IconData icono, {String? hint}) => InputDecoration(
    labelText: label, hintText: hint,
    prefixIcon: Icon(icono, size: 20),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    filled: true, fillColor: Colors.grey[50],
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), isDense: true,
  );
}
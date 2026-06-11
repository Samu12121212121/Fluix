import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../../../core/mixins/safe_stream_mixin.dart';
import '../../../core/utils/permisos_service.dart';

class ModuloServiciosScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloServiciosScreen({super.key, required this.empresaId, this.sesion});

  @override
  State<ModuloServiciosScreen> createState() => _ModuloServiciosScreenState();
}

class _ModuloServiciosScreenState extends State<ModuloServiciosScreen>
    with SafeStreamMixin {
  final _firestore = FirebaseFirestore.instance;
  String _categoriaFiltro = 'Todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('servicios')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          var servicios = snapshot.data?.docs ?? [];

          // Obtener categorías únicas
          final categorias = ['Todos', ...{
            ...servicios.map((s) {
              final d = s.data() as Map<String, dynamic>;
              return d['categoria']?.toString() ?? 'Sin categoría';
            })
          }];

          if (_categoriaFiltro != 'Todos') {
            servicios = servicios.where((s) {
              final d = s.data() as Map<String, dynamic>;
              return (d['categoria'] ?? 'Sin categoría') == _categoriaFiltro;
            }).toList();
          }

          if (servicios.isEmpty && _categoriaFiltro == 'Todos') {
            return _buildVacio();
          }

          final todosLosDocs = snapshot.data?.docs ?? [];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildResumen(todosLosDocs, todosLosDocs)),
              // Filtro por categoría
              if (categorias.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: categorias.length,
                      itemBuilder: (context, i) {
                        final cat = categorias[i];
                        final seleccionada = _categoriaFiltro == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _categoriaFiltro = cat),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: seleccionada ? const Color(0xFF7B1FA2) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: seleccionada ? const Color(0xFF7B1FA2) : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: seleccionada ? Colors.white : Colors.grey[700],
                                fontWeight: seleccionada ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (servicios.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No hay servicios en "$_categoriaFiltro"',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final data = servicios[i].data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _TarjetaServicio(
                          id: servicios[i].id,
                          data: data,
                          onEditar: () => _abrirFormulario(id: servicios[i].id, data: data),
                          onToggle: () => _toggleActivo(servicios[i].id, data['activo'] ?? true),
                          onEliminar: () => _eliminarServicio(servicios[i].id, data['nombre'] ?? ''),
                        ),
                      );
                    },
                    childCount: servicios.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: (widget.sesion?.puedeGestionarServicios ?? true)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'fab_csv',
                  onPressed: _importarCsv,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF7B1FA2),
                  tooltip: 'Importar CSV',
                  elevation: 2,
                  child: const Icon(Icons.upload_file),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'fab_servicios',
                  onPressed: _abrirFormulario,
                  backgroundColor: const Color(0xFF7B1FA2),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo servicio'),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildResumen(List<QueryDocumentSnapshot> servicios, List<QueryDocumentSnapshot> todos) {
    final activos = servicios.where((s) {
      final d = s.data() as Map<String, dynamic>;
      return d['activo'] != false;
    }).length;

    final precios = servicios.map((s) {
      final d = s.data() as Map<String, dynamic>;
      return (d['precio'] ?? 0.0 as num).toDouble();
    }).toList();

    final precioMedio = precios.isEmpty ? 0.0 : precios.reduce((a, b) => a + b) / precios.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(label: 'Total', valor: '${servicios.length}', icono: Icons.miscellaneous_services),
              _StatChip(label: 'Activos', valor: '$activos', icono: Icons.check_circle),
              _StatChip(label: 'Precio medio', valor: '€${precioMedio.toStringAsFixed(0)}', icono: Icons.euro),
            ],
          ),
          if (todos.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _eliminarTodos(todos),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_sweep, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('Borrar todos los servicios',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.miscellaneous_services, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay servicios registrados',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Pulsa el botón para crear el primero', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Future<void> _toggleActivo(String id, bool actual) async {
    await _firestore
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('servicios')
        .doc(id)
        .update({'activo': !actual});
  }

  Future<void> _eliminarTodos(List<QueryDocumentSnapshot> servicios) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar todos los servicios'),
        content: Text('¿Eliminar los ${servicios.length} servicios? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Borrar todos'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final batch = _firestore.batch();
    for (final doc in servicios) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Todos los servicios eliminados'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _eliminarServicio(String id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _firestore
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('servicios')
        .doc(id)
        .delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$nombre" eliminado'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _importarCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.first.path;
    if (path == null) return;

    try {
      final content = await File(path).readAsString();
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      if (rows.isEmpty) return;

      // Detectar si la primera fila es cabecera
      final primeraFila = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final tieneCabecera = primeraFila.any((c) =>
          c.contains('nombre') || c.contains('precio') || c.contains('categor'));
      final datos = tieneCabecera ? rows.skip(1).toList() : rows;

      // Índices de columnas (intenta detectar por cabecera o usar posición)
      int iNombre = 0, iCategoria = 1, iPrecio = 2, iDescripcion = 3, iDuracion = 4;
      if (tieneCabecera) {
        iNombre     = primeraFila.indexWhere((c) => c.contains('nombre'));
        iCategoria  = primeraFila.indexWhere((c) => c.contains('categor'));
        iPrecio     = primeraFila.indexWhere((c) => c.contains('precio'));
        iDescripcion = primeraFila.indexWhere((c) => c.contains('desc'));
        iDuracion   = primeraFila.indexWhere((c) => c.contains('dur') || c.contains('min'));
        if (iNombre < 0) iNombre = 0;
        if (iCategoria < 0) iCategoria = 1;
        if (iPrecio < 0) iPrecio = 2;
        if (iDescripcion < 0) iDescripcion = 3;
        if (iDuracion < 0) iDuracion = 4;
      }

      int importados = 0;
      int errores = 0;
      final batch = _firestore.batch();
      final col = _firestore.collection('empresas').doc(widget.empresaId).collection('servicios');

      for (final row in datos) {
        if (row.isEmpty) continue;
        String get(int idx) => idx < row.length ? row[idx].toString().trim() : '';
        final nombre = get(iNombre);
        if (nombre.isEmpty) { errores++; continue; }
        final precio = double.tryParse(get(iPrecio).replaceAll(',', '.')) ?? 0.0;
        final duracion = int.tryParse(get(iDuracion)) ?? 60;
        batch.set(col.doc(), {
          'nombre': nombre,
          'categoria': get(iCategoria).isNotEmpty ? get(iCategoria) : 'General',
          'precio': precio,
          'descripcion': get(iDescripcion),
          'duracion_minutos': duracion,
          'activo': true,
          'iva_porcentaje': 21.0,
          'precio_con_iva': false,
          'fecha_creacion': FieldValue.serverTimestamp(),
        });
        importados++;
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$importados servicio${importados == 1 ? '' : 's'} importado${importados == 1 ? '' : 's'}'
              '${errores > 0 ? ' ($errores filas con error)' : ''}'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abrirFormulario({String? id, Map<String, dynamic>? data}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioServicio(
        empresaId: widget.empresaId,
        id: id,
        data: data,
      ),
    );
  }
}

// ── TARJETA SERVICIO ──────────────────────────────────────────────────────────

class _TarjetaServicio extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEditar;
  final VoidCallback onToggle;
  final VoidCallback onEliminar;

  const _TarjetaServicio({required this.id, required this.data, required this.onEditar, required this.onToggle, required this.onEliminar});

  String _duracionFormateada(int minutos) {
    if (minutos >= 60) {
      final h = minutos ~/ 60;
      final m = minutos % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }
    return '${minutos}min';
  }

  @override
  Widget build(BuildContext context) {
    final activo = data['activo'] ?? true;
    final precio = (data['precio'] ?? 0.0 as num).toDouble();
    final duracion = data['duracion_minutos'] ?? 60;
    final categoria = data['categoria'] ?? 'Sin categoría';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icono
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: activo
                    ? const Color(0xFF7B1FA2).withValues(alpha: 0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.spa,
                color: activo ? const Color(0xFF7B1FA2) : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['nombre'] ?? 'Sin nombre',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: activo ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ),
                      if (!activo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Inactivo', style: TextStyle(fontSize: 10, color: Colors.red)),
                        ),
                    ],
                  ),
                  if (data['descripcion'] != null && data['descripcion'] != '')
                    Text(
                      data['descripcion'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(categoria, style: const TextStyle(color: Color(0xFF7B1FA2), fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.timer, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(_duracionFormateada(duracion), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€${precio.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF7B1FA2)),
                ),
                const SizedBox(height: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  onSelected: (v) {
                    if (v == 'editar') onEditar();
                    if (v == 'toggle') onToggle();
                    if (v == 'eliminar') onEliminar();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'editar', child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Editar'),
                      contentPadding: EdgeInsets.zero,
                    )),
                    PopupMenuItem(value: 'toggle', child: ListTile(
                      leading: Icon(activo ? Icons.visibility_off : Icons.visibility),
                      title: Text(activo ? 'Desactivar' : 'Activar'),
                      contentPadding: EdgeInsets.zero,
                    )),
                    const PopupMenuItem(value: 'eliminar', child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── FORMULARIO SERVICIO ───────────────────────────────────────────────────────

class _FormularioServicio extends StatefulWidget {
  final String empresaId;
  final String? id;
  final Map<String, dynamic>? data;

  const _FormularioServicio({required this.empresaId, this.id, this.data});

  @override
  State<_FormularioServicio> createState() => _FormularioServicioState();
}

class _FormularioServicioState extends State<_FormularioServicio> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  late TextEditingController _nombreCtrl;
  late TextEditingController _descripcionCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _duracionCtrl;
  late TextEditingController _categoriaCtrl;
  bool _guardando = false;

  // IVA por servicio
  double _ivaPorcentaje = 21.0;
  bool _precioConIva = false; // true = el precio ya incluye IVA

  // Variables para gestión de empleados
  bool _cargandoEmpleados = true;
  List<Map<String, dynamic>> _empleadosDisponibles = [];
  Set<String> _empleadosSeleccionados = {};

  bool get _esEdicion => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.data?['nombre'] ?? '');
    _descripcionCtrl = TextEditingController(text: widget.data?['descripcion'] ?? '');
    _precioCtrl = TextEditingController(text: (widget.data?['precio'] ?? '').toString());
    _duracionCtrl = TextEditingController(text: (widget.data?['duracion_minutos'] ?? 60).toString());
    _categoriaCtrl = TextEditingController(text: widget.data?['categoria'] ?? '');
    _ivaPorcentaje = (widget.data?['iva_porcentaje'] as num?)?.toDouble() ?? 21.0;
    _precioConIva  = widget.data?['precio_con_iva'] as bool? ?? false;
    
    // Cargar empleados disponibles
    _cargarEmpleados();
  }
  
  Future<void> _cargarEmpleados() async {
    try {
      final empleadosSnap = await _firestore
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('activo', isEqualTo: true)
          .get();
      
      if (mounted) {
        setState(() {
          _empleadosDisponibles = empleadosSnap.docs
              .map((doc) => {'id': doc.id, 'nombre': doc.data()['nombre'] ?? 'Sin nombre'})
              .toList();
          
          // Si es edición, cargar empleados ya asignados
          if (widget.data != null && widget.data!['empleados_ids'] != null) {
            _empleadosSeleccionados = Set<String>.from(widget.data!['empleados_ids'] as List? ?? []);
          }
          
          _cargandoEmpleados = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando empleados: $e');
      if (mounted) {
        setState(() => _cargandoEmpleados = false);
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _duracionCtrl.dispose();
    _categoriaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final datos = {
        'nombre': _nombreCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'precio': double.tryParse(_precioCtrl.text.trim()) ?? 0.0,
        'duracion_minutos': int.tryParse(_duracionCtrl.text.trim()) ?? 60,
        'categoria': _categoriaCtrl.text.trim().isEmpty ? 'General' : _categoriaCtrl.text.trim(),
        'activo': true,
        'imagenes': [],
        'empleados_ids': _empleadosSeleccionados.toList(),
        'iva_porcentaje': _ivaPorcentaje,
        'precio_con_iva': _precioConIva,
        'fecha_modificacion': DateTime.now().toIso8601String(),
      };

      final ref = _firestore
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('servicios');

      if (_esEdicion) {
        await ref.doc(widget.id).update(datos);
      } else {
        await ref.add({...datos, 'fecha_creacion': DateTime.now().toIso8601String()});
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion ? '✅ Servicio actualizado' : '✅ Servicio creado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _esEdicion ? 'Editar Servicio' : 'Nuevo Servicio',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombreCtrl,
                decoration: _inputDeco('Nombre del servicio *', Icons.spa),
                validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionCtrl,
                decoration: _inputDeco('Descripción', Icons.description),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _precioCtrl,
                      decoration: _inputDeco('Precio (€) *', Icons.euro),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _duracionCtrl,
                      decoration: _inputDeco('Duración (min) *', Icons.timer),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () => FocusScope.of(context).unfocus(),
                      validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── IVA ─────────────────────────────────────────────────────────
              Row(children: [
                const Icon(Icons.percent, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('IVA:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                ...[0.0, 4.0, 10.0, 21.0].map((v) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${v.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11)),
                    selected: _ivaPorcentaje == v,
                    onSelected: (_) => setState(() => _ivaPorcentaje = v),
                    selectedColor: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                    visualDensity: VisualDensity.compact,
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Precio ya incluye IVA (PVP)',
                    style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  _precioConIva
                      ? 'La base imponible se calculará dividiendo el precio entre ${(1 + _ivaPorcentaje / 100).toStringAsFixed(2)}'
                      : 'El IVA se añadirá encima del precio al facturar',
                  style: const TextStyle(fontSize: 11),
                ),
                value: _precioConIva,
                onChanged: (v) => setState(() => _precioConIva = v),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _categoriaCtrl,
                decoration: _inputDeco('Categoría (ej: Cabello, Masajes...)', Icons.category),
              ),
              const SizedBox(height: 16),
              
              // Selector de empleados
              if (_cargandoEmpleados)
                const Center(child: CircularProgressIndicator())
              else if (_empleadosDisponibles.isNotEmpty) ...[
                const Text('Empleados asignados', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _empleadosDisponibles.map((emp) {
                    final seleccionado = _empleadosSeleccionados.contains(emp['id']);
                    return FilterChip(
                      label: Text(emp['nombre']),
                      selected: seleccionado,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _empleadosSeleccionados.add(emp['id']);
                          } else {
                            _empleadosSeleccionados.remove(emp['id']);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF7B1FA2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  _empleadosSeleccionados.isEmpty
                      ? 'Cualquier empleado puede realizar este servicio'
                      : '${_empleadosSeleccionados.length} empleado(s) asignado(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _guardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_esEdicion ? 'Guardar cambios' : 'Crear servicio', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── STAT CHIP ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icono;

  const _StatChip({required this.label, required this.valor, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}




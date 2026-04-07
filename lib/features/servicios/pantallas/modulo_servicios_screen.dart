import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/permisos_service.dart';

class ModuloServiciosScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloServiciosScreen({super.key, required this.empresaId, this.sesion});

  @override
  State<ModuloServiciosScreen> createState() => _ModuloServiciosScreenState();
}

class _ModuloServiciosScreenState extends State<ModuloServiciosScreen> {
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

          return Column(
            children: [
              _buildResumen(snapshot.data?.docs ?? []),
              // Filtro por categoría
              if (categorias.length > 1)
                SizedBox(
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
              const SizedBox(height: 8),
              Expanded(
                child: servicios.isEmpty
                    ? Center(
                        child: Text(
                          'No hay servicios en "$_categoriaFiltro"',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: servicios.length,
                        itemBuilder: (context, i) {
                          final data = servicios[i].data() as Map<String, dynamic>;
                          return _TarjetaServicio(
                            id: servicios[i].id,
                            data: data,
                            onEditar: () => _abrirFormulario(id: servicios[i].id, data: data),
                            onToggle: () => _toggleActivo(servicios[i].id, data['activo'] ?? true),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: (widget.sesion?.puedeGestionarServicios ?? true)
          ? FloatingActionButton.extended(
              onPressed: _abrirFormulario,
              backgroundColor: const Color(0xFF7B1FA2),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo servicio'),
            )
          : null,
    );
  }

  Widget _buildResumen(List<QueryDocumentSnapshot> servicios) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Total', valor: '${servicios.length}', icono: Icons.miscellaneous_services),
          _StatChip(label: 'Activos', valor: '$activos', icono: Icons.check_circle),
          _StatChip(label: 'Precio medio', valor: '€${precioMedio.toStringAsFixed(0)}', icono: Icons.euro),
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

  const _TarjetaServicio({required this.id, required this.data, required this.onEditar, required this.onToggle});

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

  bool get _esEdicion => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.data?['nombre'] ?? '');
    _descripcionCtrl = TextEditingController(text: widget.data?['descripcion'] ?? '');
    _precioCtrl = TextEditingController(text: (widget.data?['precio'] ?? '').toString());
    _duracionCtrl = TextEditingController(text: (widget.data?['duracion_minutos'] ?? 60).toString());
    _categoriaCtrl = TextEditingController(text: widget.data?['categoria'] ?? '');
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
                      validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _duracionCtrl,
                      decoration: _inputDeco('Duración (min) *', Icons.timer),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoriaCtrl,
                decoration: _inputDeco('Categoría (ej: Cabello, Masajes...)', Icons.category),
              ),
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




import 'package:flutter/material.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

class DialogNuevaSeccion extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService contenidoService;

  const DialogNuevaSeccion({
    super.key,
    required this.empresaId,
    required this.contenidoService,
  });

  @override
  State<DialogNuevaSeccion> createState() => _DialogNuevaSeccionState();
}

class _DialogNuevaSeccionState extends State<DialogNuevaSeccion> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  TipoSeccionWeb _tipoSeleccionado = TipoSeccionWeb.ofertas;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add, color: Color(0xFF1976D2)),
          SizedBox(width: 8),
          Text('Nueva Sección'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la sección',
                hintText: 'Ej: Ofertas Especiales',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'El nombre es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoSeccionWeb>(
              value: _tipoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Tipo de sección',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: TipoSeccionWeb.values.map((tipo) => DropdownMenuItem(
                value: tipo,
                child: Row(
                  children: [
                    Icon(tipo.icono, size: 20),
                    const SizedBox(width: 8),
                    Text(tipo.nombre),
                  ],
                ),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _tipoSeleccionado = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _crearSeccion,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
          ),
          child: const Text('Crear'),
        ),
      ],
    );
  }

  void _crearSeccion() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final seccion = SeccionWeb(
          id: _nombreController.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_'),
          nombre: _nombreController.text,
          tipo: _tipoSeleccionado.id,
          activa: true,
          elementos: [],
          configuracion: _tipoSeleccionado == TipoSeccionWeb.ofertas ||
              _tipoSeleccionado == TipoSeccionWeb.carta
              ? {'mostrar_precio': true}
              : {},
          fechaCreacion: DateTime.now(),
        );

        await widget.contenidoService.crearSeccion(widget.empresaId, seccion);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sección "${seccion.nombre}" creada'),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFF44336),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }
}

class DialogAgregarElemento extends StatefulWidget {
  final String empresaId;
  final String seccionId;
  final String tipoSeccion;
  final ContenidoWebService contenidoService;

  const DialogAgregarElemento({
    super.key,
    required this.empresaId,
    required this.seccionId,
    required this.tipoSeccion,
    required this.contenidoService,
  });

  @override
  State<DialogAgregarElemento> createState() => _DialogAgregarElementoState();
}

class _DialogAgregarElementoState extends State<DialogAgregarElemento> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_box, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Text('Nuevo Elemento'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej: Pizza Margarita',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'El título es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: Tomate, mozzarella y albahaca',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              if (widget.tipoSeccion == 'ofertas' || widget.tipoSeccion == 'carta' || widget.tipoSeccion == 'servicios')
                TextFormField(
                  controller: _precioController,
                  decoration: const InputDecoration(
                    labelText: 'Precio (opcional)',
                    hintText: '12.50',
                    prefixIcon: Icon(Icons.euro),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  validator: (value) {
                    if (value?.isNotEmpty ?? false) {
                      final precio = double.tryParse(value!);
                      if (precio == null) {
                        return 'Formato de precio inválido';
                      }
                    }
                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _agregarElemento,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Agregar'),
        ),
      ],
    );
  }

  void _agregarElemento() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final elemento = ElementoContenido(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          titulo: _tituloController.text,
          descripcion: _descripcionController.text.isEmpty ? null : _descripcionController.text,
          precio: _precioController.text.isEmpty ? null : double.parse(_precioController.text),
          camposPersonalizados: {},
          visible: true,
          orden: DateTime.now().millisecondsSinceEpoch,
        );

        await widget.contenidoService.agregarElemento(widget.empresaId, widget.seccionId, elemento);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Elemento "${elemento.titulo}" agregado'),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFF44336),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    super.dispose();
  }
}

// Página de edición de sección (versión simplificada)
class EditorSeccionPage extends StatefulWidget {
  final String empresaId;
  final SeccionWeb seccion;
  final ContenidoWebService contenidoService;

  const EditorSeccionPage({
    super.key,
    required this.empresaId,
    required this.seccion,
    required this.contenidoService,
  });

  @override
  State<EditorSeccionPage> createState() => _EditorSeccionPageState();
}

class _EditorSeccionPageState extends State<EditorSeccionPage> {
  late List<ElementoContenido> _elementos;

  @override
  void initState() {
    super.initState();
    _elementos = [...widget.seccion.elementos];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar: ${widget.seccion.nombre}'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _guardarCambios,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: _elementos.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay elementos',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega elementos para comenzar',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      )
          : ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _elementos.length,
        itemBuilder: (context, index) {
          final elemento = _elementos[index];
          return Card(
            key: ValueKey(elemento.id),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.drag_handle),
              title: Text(elemento.titulo),
              subtitle: elemento.descripcion != null
                  ? Text(elemento.descripcion!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (elemento.precio != null)
                    Text(
                      '€${elemento.precio!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFF44336)),
                    onPressed: () => _eliminarElemento(index),
                  ),
                ],
              ),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final elemento = _elementos.removeAt(oldIndex);
            _elementos.insert(newIndex, elemento);
          });
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_agregar_elemento',
        onPressed: _agregarNuevoElemento,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Elemento'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  void _agregarNuevoElemento() {
    showDialog(
      context: context,
      builder: (context) => DialogAgregarElemento(
        empresaId: widget.empresaId,
        seccionId: widget.seccion.id,
        tipoSeccion: widget.seccion.tipo,
        contenidoService: widget.contenidoService,
      ),
    ).then((_) {
      setState(() {});
    });
  }

  void _eliminarElemento(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Elemento'),
        content: Text('¿Estás seguro de que quieres eliminar "${_elementos[index].titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.contenidoService.eliminarElemento(
                widget.empresaId,
                widget.seccion.id,
                _elementos[index].id,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF44336)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _guardarCambios() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cambios guardados'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }
}
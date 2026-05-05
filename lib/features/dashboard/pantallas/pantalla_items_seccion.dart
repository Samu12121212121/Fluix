import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA ITEMS GENÉRICOS — Lo que ve el cliente
// ═════════════════════════════════════════════════════════════════════════════

class PantallaItemsSeccion extends StatefulWidget {
  final String empresaId;
  final SeccionWeb seccion;
  final ContenidoWebService svc;

  const PantallaItemsSeccion({
    super.key,
    required this.empresaId,
    required this.seccion,
    required this.svc,
  });

  @override
  State<PantallaItemsSeccion> createState() => _PantallaItemsSeccionState();
}

class _PantallaItemsSeccionState extends State<PantallaItemsSeccion> {
  late List<Map<String, dynamic>> _items;
  late TextEditingController _nombreCtrl;
  bool _editandoNombre = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(
      widget.seccion.contenido.items.map((e) => Map<String, dynamic>.from(e)),
    );
    _nombreCtrl = TextEditingController(text: widget.seccion.nombre);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  // ── Guardar todo ──────────────────────────────────────────────────────────

  Future<void> _guardarItems() async {
    setState(() => _guardando = true);
    try {
      await widget.svc.guardarItemsGenericos(
          widget.empresaId, widget.seccion.id, _items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('¡Guardado! Cambios visibles en la web'),
          ]),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Guardar nombre ────────────────────────────────────────────────────────

  Future<void> _guardarNombre() async {
    final nuevoNombre = _nombreCtrl.text.trim();
    if (nuevoNombre.isEmpty) return;
    setState(() => _editandoNombre = false);
    try {
      await widget.svc.actualizarNombreSeccion(
          widget.empresaId, widget.seccion.id, nuevoNombre);
    } catch (_) {}
  }

  // ── Añadir item ───────────────────────────────────────────────────────────

  void _anadirItem() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final nuevoItem = <String, dynamic>{
      'id': id,
      'nombre': '',
      'disponible': true,
    };
    setState(() => _items.add(nuevoItem));
    _editarItem(_items.length - 1);
  }

  // ── Eliminar item ─────────────────────────────────────────────────────────

  void _eliminarItem(int index) {
    final item = _items[index];
    final nombre = item['nombre'] ?? 'Sin nombre';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar item'),
        content: Text('¿Eliminar "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _items.removeAt(index));
              Navigator.pop(ctx);
              _guardarItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── Editar item (BottomSheet genérico) ─────────────────────────────────────

  void _editarItem(int index) {
    final item = Map<String, dynamic>.from(_items[index]);
    final controllers = <String, TextEditingController>{};

    // Crear controllers para cada campo
    for (final key in item.keys) {
      if (key == 'id' || key == 'disponible') continue;
      controllers[key] = TextEditingController(
        text: item[key]?.toString() ?? '',
      );
    }

    // Si es un item nuevo sin campos, añadir los básicos
    if (controllers.isEmpty) {
      controllers['nombre'] = TextEditingController();
      controllers['precio'] = TextEditingController();
      controllers['descripcion'] = TextEditingController();
    }

    bool disponible = item['disponible'] as bool? ?? true;
    String? nuevoCampoNombre;
    final idCtrl = TextEditingController(text: item['id']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final color = context.read<AppConfigProvider>().colorPrimario;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    item['nombre']?.toString().isNotEmpty == true
                        ? 'Editar "${item['nombre']}"'
                        : 'Nuevo item',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),

                  // ── ID del item (para data-fluix-item) ──────────────────
                  TextField(
                    controller: idCtrl,
                    decoration: InputDecoration(
                      labelText: 'ID del item',
                      hintText: 'ej: croquetas, anchoas',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      helperText: 'Usa este ID en data-fluix-item="..."',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: idCtrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ID copiado'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Disponible ──────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.visibility, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Disponible',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      Switch(
                        value: disponible,
                        onChanged: (v) => setSheet(() => disponible = v),
                        activeThumbColor: color,
                      ),
                    ],
                  ),
                  const Divider(),

                  // ── Campos dinámicos ────────────────────────────────────
                  ...controllers.entries.map((e) {
                    final campo = e.key;
                    final ctrl = e.value;
                    final esImagen = ctrl.text.startsWith('http');
                    final esNumero = campo == 'precio' ||
                        double.tryParse(ctrl.text) != null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (esImagen && ctrl.text.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                ctrl.text,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: esNumero
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true)
                                      : TextInputType.text,
                                  maxLines: campo == 'descripcion' ? 3 : 1,
                                  decoration: InputDecoration(
                                    labelText: _formatearNombreCampo(campo),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: esImagen
                                        ? IconButton(
                                            icon: Icon(Icons.photo_camera,
                                                color: color),
                                            onPressed: () async {
                                              final url = await widget.svc
                                                  .subirImagenDesdeGaleria(
                                                      widget.empresaId,
                                                      'generico/${widget.seccion.id}');
                                              if (url != null) {
                                                setSheet(
                                                    () => ctrl.text = url);
                                              }
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              // Botón eliminar campo
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () {
                                  setSheet(() => controllers.remove(campo));
                                },
                                tooltip: 'Quitar campo',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // ── Añadir campo ────────────────────────────────────────
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Nuevo campo (ej: alergenos)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => nuevoCampoNombre = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: color, size: 32),
                        onPressed: () {
                          final campo = nuevoCampoNombre
                              ?.trim()
                              .toLowerCase()
                              .replaceAll(' ', '_');
                          if (campo == null || campo.isEmpty) return;
                          if (controllers.containsKey(campo)) return;
                          setSheet(() {
                            controllers[campo] = TextEditingController();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Botón guardar ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final finalId = idCtrl.text.trim().isNotEmpty
                            ? idCtrl.text.trim()
                            : (item['id'] ??
                                DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString());
                        final resultado = <String, dynamic>{
                          'id': finalId,
                          'disponible': disponible,
                        };
                        for (final e in controllers.entries) {
                          final val = e.value.text.trim();
                          if (val.isEmpty) continue;
                          // Intentar parsear como número
                          final num? numVal = double.tryParse(val);
                          resultado[e.key] = numVal ?? val;
                        }
                        setState(() => _items[index] = resultado);
                        Navigator.pop(ctx);
                        _guardarItems();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatearNombreCampo(String campo) {
    return campo
        .replaceAll('_', ' ')
        .split(' ')
        .map((p) => p.isNotEmpty
            ? '${p[0].toUpperCase()}${p.substring(1)}'
            : '')
        .join(' ');
  }

  // ── Mostrar HTML de ejemplo ────────────────────────────────────────────────

  void _mostrarHtmlEjemplo(BuildContext context) {
    final secId = widget.seccion.id;
    final buf = StringBuffer();
    buf.writeln('<section data-fluix-seccion="$secId">');
    buf.writeln('  <h2 data-fluix-titulo></h2>');
    buf.writeln();
    for (final item in _items) {
      final id = item['id'] ?? '???';
      buf.writeln('  <div data-fluix-item="$id">');
      for (final key in item.keys) {
        if (key == 'id' || key == 'disponible') continue;
        final valor = item[key];
        if (valor is String && valor.startsWith('http')) {
          buf.writeln('    <img data-fluix-campo="$key">');
        } else {
          buf.writeln('    <span data-fluix-campo="$key"></span>');
        }
      }
      buf.writeln('  </div>');
      buf.writeln();
    }
    buf.writeln('</section>');

    final html = buf.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(children: [
                Icon(Icons.code, color: Color(0xFF455A64)),
                SizedBox(width: 8),
                Text('HTML de ejemplo',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
              const SizedBox(height: 8),
              Text(
                'Copia este HTML y pégalo en la web del cliente. '
                'El script rellenará los valores automáticamente.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: SelectableText(
                    html,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF9CDCFE),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'El HTML está listo para usar. El script lo rellenará automáticamente.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      },
    );
  }


  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    const tipoColor = Color(0xFF455A64);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: _editandoNombre
            ? TextField(
                controller: _nombreCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Nombre de la sección',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                onSubmitted: (_) => _guardarNombre(),
              )
            : GestureDetector(
                onTap: () => setState(() => _editandoNombre = true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _nombreCtrl.text,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit, size: 16, color: Colors.white70),
                  ],
                ),
              ),
        actions: [
          if (_editandoNombre)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _guardarNombre,
            )
          else ...[
            // Botón Ver HTML
            IconButton(
              icon: const Icon(Icons.code, size: 22),
              tooltip: 'Ver HTML de ejemplo',
              onPressed: () => _mostrarHtmlEjemplo(context),
            ),
            // Botón Ver HTML
            IconButton(
              icon: const Icon(Icons.code, size: 22),
              tooltip: 'Ver HTML de ejemplo',
              onPressed: () => _mostrarHtmlEjemplo(context),
            ),
            if (_guardando)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_item',
        onPressed: _anadirItem,
        backgroundColor: tipoColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Sin items todavía',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  Text('Pulsa + Añadir para crear el primero',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
                _guardarItems();
              },
              itemBuilder: (ctx, i) {
                final item = _items[i];
                final nombre =
                    item['nombre']?.toString() ?? 'Sin nombre';
                final precio = item['precio'];
                final disponible = item['disponible'] as bool? ?? true;
                final imagen = item['imagen'] as String? ??
                    item['imagen_url'] as String?;

                return Container(
                  key: ValueKey(item['id'] ?? i),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: !disponible
                        ? Border.all(
                            color: Colors.orange.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    leading: imagen != null && imagen.startsWith('http')
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imagen,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: tipoColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image,
                                    color: tipoColor, size: 24),
                              ),
                            ),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: tipoColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit_note,
                                color: tipoColor, size: 24),
                          ),
                    title: Text(
                      nombre.isEmpty ? 'Sin nombre' : nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: disponible ? Colors.black87 : Colors.grey,
                        decoration: disponible
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: precio != null
                        ? Text(
                            '${precio is num ? precio.toStringAsFixed(2) : precio}€',
                            style: const TextStyle(
                              color: tipoColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!disponible)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Oculto',
                                style: TextStyle(
                                    color: Colors.orange, fontSize: 10)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          color: tipoColor,
                          onPressed: () => _editarItem(i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red,
                          onPressed: () => _eliminarItem(i),
                        ),
                      ],
                    ),
                    onTap: () => _editarItem(i),
                  ),
                );
              },
            ),
    );
  }
}









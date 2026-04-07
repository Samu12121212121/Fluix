import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

class ModuloContenidoWebSimplificado extends StatefulWidget {
  final String empresaId;
  const ModuloContenidoWebSimplificado({super.key, required this.empresaId});

  @override
  State<ModuloContenidoWebSimplificado> createState() => _ModuloContenidoWebSimplificadoState();
}

class _ModuloContenidoWebSimplificadoState extends State<ModuloContenidoWebSimplificado> {
  final ContenidoWebService _contenidoService = ContenidoWebService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          _buildHeader(context),

          // Lista de secciones
          Expanded(
            child: StreamBuilder<List<SeccionWeb>>(
              stream: _contenidoService.obtenerSecciones(widget.empresaId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEstadoVacio(context);
                }

                final secciones = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: secciones.length,
                  itemBuilder: (context, index) => _buildSeccionCard(context, secciones[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_codigo',
        onPressed: () => _generarCodigoWeb(context),
        icon: const Icon(Icons.code),
        label: const Text('Generar Código'),
        backgroundColor: const Color(0xFF21759B),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editor de Contenido Web',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Edita el contenido de tu página web',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _mostrarInfo(context),
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Solo puedes editar el contenido de las secciones. Para crear nuevas secciones, contacta al administrador de tu web.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoVacio(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.web_asset_off, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay secciones disponibles',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'El administrador de tu web debe crear las secciones primero',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _contactarAdministrador(context),
              icon: const Icon(Icons.contact_support),
              label: const Text('Solicitar Secciones'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionCard(BuildContext context, SeccionWeb seccion) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editarContenido(context, seccion),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de la sección
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: seccion.activa ? const Color(0xFF4CAF50) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      IconosSeccion.obtenerIcono(seccion.nombre),
                      color: seccion.activa ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seccion.nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          seccion.descripcion,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: seccion.activa,
                    onChanged: (value) => _toggleSeccion(seccion.id, value),
                    activeThumbColor: const Color(0xFF4CAF50),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Preview del contenido actual
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Título: ${seccion.contenido.titulo.isEmpty ? 'Sin título' : seccion.contenido.titulo}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Texto: ${seccion.contenido.texto.isEmpty ? 'Sin contenido' : seccion.contenido.texto}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (seccion.contenido.imagenUrl != null && seccion.contenido.imagenUrl!.isNotEmpty)
                          const SizedBox(height: 4),
                        if (seccion.contenido.imagenUrl != null && seccion.contenido.imagenUrl!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.image, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Imagen incluida',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () => _editarContenido(context, seccion),
                        icon: const Icon(Icons.edit, color: Color(0xFF1976D2)),
                        tooltip: 'Editar contenido',
                      ),
                      Text(
                        'Editar',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSeccion(String seccionId, bool activa) async {
    try {
      await _contenidoService.toggleSeccion(widget.empresaId, seccionId, activa);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sección ${activa ? 'activada' : 'desactivada'}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }

  void _editarContenido(BuildContext context, SeccionWeb seccion) {
    showDialog(
      context: context,
      builder: (context) => _DialogEditarContenido(
        empresaId: widget.empresaId,
        seccion: seccion,
        contenidoService: _contenidoService,
      ),
    );
  }

  void _generarCodigoWeb(BuildContext context) async {
    try {
      final codigo = await _contenidoService.generarCodigoCompleto(widget.empresaId);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.code, color: Color(0xFF21759B)),
              SizedBox(width: 8),
              Text('Código para tu Web'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                const Text(
                  'Copia este código y pégalo en tu web para mostrar el contenido:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        codigo,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codigo));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado al portapapeles'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('📋 Copiar Código'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando código: $e'),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }

  void _contactarAdministrador(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar Secciones'),
        content: const Text(
          'Para añadir nuevas secciones a tu web (como ofertas, carta, servicios, etc.), '
          'contacta con el administrador de tu página web.\n\n'
          'Una vez que las secciones estén creadas, podrás editar su contenido desde aquí.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _mostrarInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Cómo Funciona'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Editor de Contenido Controlado',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Solo puedes editar el contenido de las secciones existentes\n'
                '• No puedes crear o eliminar secciones\n'
                '• Puedes cambiar títulos, textos e imágenes\n'
                '• Puedes activar/desactivar secciones',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'Para cada sección puedes editar:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '✏️ Título principal\n'
                '📝 Texto descriptivo\n'
                '🖼️ URL de imagen',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'Los cambios se reflejan automáticamente en tu web.',
                style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _DialogEditarContenido extends StatefulWidget {
  final String empresaId;
  final SeccionWeb seccion;
  final ContenidoWebService contenidoService;

  const _DialogEditarContenido({
    required this.empresaId,
    required this.seccion,
    required this.contenidoService,
  });

  @override
  State<_DialogEditarContenido> createState() => _DialogEditarContenidoState();
}

class _DialogEditarContenidoState extends State<_DialogEditarContenido> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _textoController;
  String? _imagenUrl;
  bool _subiendoImagen = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.seccion.contenido.titulo);
    _textoController = TextEditingController(text: widget.seccion.contenido.texto);
    _imagenUrl = widget.seccion.contenido.imagenUrl;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(IconosSeccion.obtenerIcono(widget.seccion.nombre), color: const Color(0xFF1976D2)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editar: ${widget.seccion.nombre}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.seccion.descripcion,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej: Ofertas especiales de temporada',
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
                controller: _textoController,
                decoration: const InputDecoration(
                  labelText: 'Texto',
                  hintText: 'Describe el contenido de esta sección...',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'El texto es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Imagen de la sección ──────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Imagen de la sección',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  if (_imagenUrl != null && _imagenUrl!.isNotEmpty) ...[
                    // Preview de la imagen actual
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _imagenUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 140,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _subiendoImagen ? null : _cambiarImagen,
                            icon: _subiendoImagen
                                ? const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.photo_camera, size: 16),
                            label: Text(_subiendoImagen ? 'Subiendo...' : 'Cambiar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _subiendoImagen ? null : _eliminarImagen,
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          label: const Text('Quitar', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Botón para subir imagen nueva
                    InkWell(
                      onTap: _subiendoImagen ? null : _cambiarImagen,
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: _subiendoImagen
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      size: 32, color: Colors.grey[500]),
                                  const SizedBox(height: 6),
                                  Text('Toca para subir imagen',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los cambios se verán reflejados inmediatamente en tu página web.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
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
          onPressed: _guardarContenido,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _cambiarImagen() async {
    setState(() => _subiendoImagen = true);
    try {
      final url = await widget.contenidoService.subirImagenSeccion(
          widget.empresaId, widget.seccion.id);
      if (url != null && mounted) {
        setState(() => _imagenUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Imagen actualizada en la web'),
            backgroundColor: Color(0xFF4CAF50),
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
      if (mounted) setState(() => _subiendoImagen = false);
    }
  }

  void _eliminarImagen() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar imagen'),
        content: const Text('¿Seguro que quieres quitar la imagen de esta sección?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.contenidoService.eliminarImagenSeccion(
          widget.empresaId, widget.seccion.id);
      if (mounted) setState(() => _imagenUrl = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _guardarContenido() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final nuevoContenido = ContenidoSeccion(
          titulo: _tituloController.text,
          texto: _textoController.text,
          imagenUrl: (_imagenUrl?.isEmpty ?? true) ? null : _imagenUrl,
        );

        await widget.contenidoService.actualizarContenido(
          widget.empresaId,
          widget.seccion.id,
          nuevoContenido,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contenido actualizado correctamente'),
              backgroundColor: Color(0xFF4CAF50),
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
    _textoController.dispose();
    super.dispose();
  }
}


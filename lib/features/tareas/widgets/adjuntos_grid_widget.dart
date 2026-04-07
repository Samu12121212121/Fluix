import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/modelos/adjunto_tarea.dart';
import '../../../services/adjuntos_tarea_service.dart';

/// Grid de adjuntos de una tarea con opciones para subir y eliminar.
class AdjuntosGridWidget extends StatefulWidget {
  final String empresaId;
  final String tareaId;
  final String usuarioId;
  final bool puedeEditar;

  const AdjuntosGridWidget({
    super.key,
    required this.empresaId,
    required this.tareaId,
    required this.usuarioId,
    this.puedeEditar = true,
  });

  @override
  State<AdjuntosGridWidget> createState() => _AdjuntosGridWidgetState();
}

class _AdjuntosGridWidgetState extends State<AdjuntosGridWidget> {
  final AdjuntosTareaService _svc = AdjuntosTareaService();
  final Map<String, double> _progreso = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdjuntoTarea>>(
      stream: _svc.listarStream(widget.empresaId, widget.tareaId),
      builder: (context, snap) {
        final adjuntos = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_file, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Text(
                  'Adjuntos (${adjuntos.length}/${AdjuntosTareaService.kMaxAdjuntos})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Spacer(),
                if (widget.puedeEditar &&
                    adjuntos.length < AdjuntosTareaService.kMaxAdjuntos)
                  IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: Color(0xFF1976D2)),
                    onPressed: () => _mostrarOpcionesSubida(adjuntos),
                  ),
              ],
            ),
            if (adjuntos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.attach_file,
                          size: 40, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('Sin adjuntos',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: adjuntos.length,
                itemBuilder: (context, i) =>
                    _buildItem(adjuntos, i),
              ),
            // Indicadores de progreso de subida activos
            ..._progreso.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subiendo... ${(e.value * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12)),
                      LinearProgressIndicator(value: e.value),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildItem(List<AdjuntoTarea> adjuntos, int index) {
    final adj = adjuntos[index];
    return GestureDetector(
      onTap: () => _abrir(adjuntos, index),
      onLongPress: widget.puedeEditar ? () => _confirmarEliminar(adj) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (adj.tipo == TipoAdjunto.imagen)
              CachedNetworkImage(
                imageUrl: adj.thumbnailUrl ?? adj.url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))),
                errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey)),
              )
            else
              Container(
                color: adj.tipo == TipoAdjunto.pdf
                    ? Colors.red.shade50
                    : Colors.blue.shade50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      adj.tipo == TipoAdjunto.pdf
                          ? Icons.picture_as_pdf
                          : Icons.insert_drive_file,
                      color: adj.tipo == TipoAdjunto.pdf
                          ? Colors.red
                          : Colors.blue,
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        adj.nombre,
                        style: const TextStyle(fontSize: 9),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.puedeEditar)
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _confirmarEliminar(adj),
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _abrir(List<AdjuntoTarea> adjuntos, int index) {
    final adj = adjuntos[index];
    if (adj.tipo == TipoAdjunto.imagen) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VisorImagenesScreen(
            adjuntos: adjuntos
                .where((a) => a.tipo == TipoAdjunto.imagen)
                .toList(),
            indiceInicial: adjuntos
                .where((a) => a.tipo == TipoAdjunto.imagen)
                .toList()
                .indexOf(adj),
          ),
        ),
      );
    } else if (adj.tipo == TipoAdjunto.pdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VisorPdfScreen(adjunto: adj),
        ),
      );
    }
  }

  Future<void> _mostrarOpcionesSubida(List<AdjuntoTarea> adjuntos) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AdjuntarArchivoSheet(
        onCamara: () => _subirDesde(ImageSource.camera),
        onGaleria: () => _subirDesde(ImageSource.gallery),
        onDocumento: _subirDocumento,
      ),
    );
  }

  Future<void> _subirDesde(ImageSource fuente) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: fuente);
    if (xFile == null || !mounted) return;
    await _subir(File(xFile.path));
  }

  Future<void> _subirDocumento() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
    );
    if (resultado == null || resultado.files.isEmpty || !mounted) return;
    final path = resultado.files.first.path;
    if (path == null) return;
    await _subir(File(path));
  }

  Future<void> _subir(File archivo) async {
    final key = archivo.path;
    try {
      setState(() => _progreso[key] = 0);
      await _svc.subir(
        empresaId: widget.empresaId,
        tareaId: widget.tareaId,
        archivo: archivo,
        subidoPorId: widget.usuarioId,
        onProgress: (p) => setState(() => _progreso[key] = p),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al subir: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _progreso.remove(key));
    }
  }

  Future<void> _confirmarEliminar(AdjuntoTarea adj) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar adjunto'),
        content: Text('¿Eliminar "${adj.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _svc.eliminar(
      empresaId: widget.empresaId,
      tareaId: widget.tareaId,
      adjunto: adj,
    );
  }
}

// ── BOTTOM SHEET ADJUNTAR ────────────────────────────────────────────────────

class _AdjuntarArchivoSheet extends StatelessWidget {
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final VoidCallback onDocumento;

  const _AdjuntarArchivoSheet({
    required this.onCamara,
    required this.onGaleria,
    required this.onDocumento,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Adjuntar archivo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _OpcionAdjunto(
                  icono: Icons.photo_camera,
                  color: const Color(0xFF1976D2),
                  label: 'Cámara',
                  onTap: () {
                    Navigator.pop(context);
                    onCamara();
                  },
                ),
                _OpcionAdjunto(
                  icono: Icons.photo_library,
                  color: const Color(0xFF4CAF50),
                  label: 'Galería',
                  onTap: () {
                    Navigator.pop(context);
                    onGaleria();
                  },
                ),
                _OpcionAdjunto(
                  icono: Icons.upload_file,
                  color: const Color(0xFFF57C00),
                  label: 'Documento',
                  onTap: () {
                    Navigator.pop(context);
                    onDocumento();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OpcionAdjunto extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _OpcionAdjunto({
    required this.icono,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icono, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ── VISOR IMÁGENES ───────────────────────────────────────────────────────────

class _VisorImagenesScreen extends StatelessWidget {
  final List<AdjuntoTarea> adjuntos;
  final int indiceInicial;

  const _VisorImagenesScreen({
    required this.adjuntos,
    required this.indiceInicial,
  });

  @override
  Widget build(BuildContext context) {
    final pageController =
        PageController(initialPage: indiceInicial.clamp(0, adjuntos.length - 1));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          adjuntos.isEmpty ? '' : adjuntos[indiceInicial].nombre,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: pageController,
        itemCount: adjuntos.length,
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: adjuntos[i].url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 60),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── VISOR PDF ────────────────────────────────────────────────────────────────

class _VisorPdfScreen extends StatelessWidget {
  final AdjuntoTarea adjunto;
  const _VisorPdfScreen({required this.adjunto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(adjunto.nombre),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(adjunto.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(adjunto.tamanioFormateado,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            // Nota: flutter_pdfview requiere el archivo descargado localmente.
            // Para una implementación completa, descargar el PDF primero.
            OutlinedButton.icon(
              onPressed: () {
                // TODO: descargar y abrir con flutter_pdfview
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir PDF'),
            ),
          ],
        ),
      ),
    );
  }
}




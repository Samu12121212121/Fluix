import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/producto_imagen_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PRODUCTO IMAGEN PICKER — para formularios
// ═════════════════════════════════════════════════════════════════════════════

class ProductoImagenPicker extends StatefulWidget {
  final String empresaId;
  final String productoId; // pre-generado antes de guardar el doc
  final String? imagenUrl;
  final ValueChanged<String?> onImagenCambiada;

  const ProductoImagenPicker({
    super.key,
    required this.empresaId,
    required this.productoId,
    this.imagenUrl,
    required this.onImagenCambiada,
  });

  @override
  State<ProductoImagenPicker> createState() => _ProductoImagenPickerState();
}

class _ProductoImagenPickerState extends State<ProductoImagenPicker> {
  final _svc = ProductoImagenService();
  bool _subiendo = false;
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = widget.imagenUrl;
  }

  @override
  void didUpdateWidget(ProductoImagenPicker old) {
    super.didUpdateWidget(old);
    if (old.imagenUrl != widget.imagenUrl) setState(() => _url = widget.imagenUrl);
  }

  Future<void> _mostrarOpciones() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Imagen del producto',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1565C0),
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 20)),
              title: const Text('Tomar foto con la cámara'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFF2E7D32),
                  child: Icon(Icons.photo_library, color: Colors.white, size: 20)),
              title: const Text('Elegir de la galería'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            if (_url != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.delete, color: Colors.white, size: 20)),
                title: const Text('Eliminar imagen actual',
                    style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _eliminar(); },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Permiso de cámara denegado'),
            action: SnackBarAction(label: 'Configuración', onPressed: openAppSettings),
          ));
        }
        return;
      }
    }
    setState(() => _subiendo = true);
    try {
      final url = await _svc.seleccionarYSubirConRetry(
        empresaId: widget.empresaId,
        productoId: widget.productoId,
        source: source,
        urlAnterior: _url,
      );
      if (url != null && mounted) {
        setState(() => _url = url);
        widget.onImagenCambiada(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _pickImage(source)),
        ));
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminar() async {
    setState(() => _subiendo = true);
    try {
      await _svc.eliminarImagen(
          empresaId: widget.empresaId, productoId: widget.productoId);
      if (mounted) {
        setState(() => _url = null);
        widget.onImagenCambiada(null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _subiendo ? null : _mostrarOpciones,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _url != null
                ? const Color(0xFF1976D2).withValues(alpha: 0.4)
                : Colors.grey[300]!,
            width: _url != null ? 2 : 1,
          ),
        ),
        child: _subiendo
            ? const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 8),
                  Text('Procesando...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]))
            : _url != null
                ? Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: CachedNetworkImage(
                        imageUrl: _url!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (_, __, ___) =>
                            const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ]),
                      ),
                    ),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_outlined, size: 44, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Añadir imagen',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('Cámara o galería · Recorte 1:1 · 800×800px',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRODUCTO IMAGEN DISPLAY — para listas y detalle
// ═════════════════════════════════════════════════════════════════════════════

/// Muestra imagen con thumbnail preferida. Fallback: iniciales con color.
class ProductoImagenDisplay extends StatelessWidget {
  final String? imagenUrl;
  final String? thumbnailUrl;
  final String nombre;
  final double size;
  final double borderRadius;

  const ProductoImagenDisplay({
    super.key,
    this.imagenUrl,
    this.thumbnailUrl,
    required this.nombre,
    this.size = 52,
    this.borderRadius = 10,
  });

  static const _colores = [
    Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFF6A1B9A),
    Color(0xFFE65100), Color(0xFF00838F), Color(0xFFC62828),
    Color(0xFF37474F), Color(0xFF4527A0),
  ];

  String get _iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }

  Color get _color => _colores[nombre.hashCode.abs() % _colores.length];
  String? get _url => thumbnailUrl ?? imagenUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size, height: size,
        child: _url != null
            ? CachedNetworkImage(
                imageUrl: _url!,
                fit: BoxFit.cover,
                memCacheWidth: (size * 2).toInt(),
                memCacheHeight: (size * 2).toInt(),
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: _color.withValues(alpha: 0.12),
        child: Center(
          child: Text(_iniciales,
              style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.34)),
        ),
      );
}


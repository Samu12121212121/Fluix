import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/storage_service.dart';
import 'avatar_empleado_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SELECTOR FOTO EMPLEADO — bottom sheet con galería / cámara
// ─────────────────────────────────────────────────────────────────────────────

class SelectorFotoEmpleado extends StatefulWidget {
  final String empresaId;
  final String empleadoId;
  final String nombreEmpleado;

  const SelectorFotoEmpleado({
    super.key,
    required this.empresaId,
    required this.empleadoId,
    required this.nombreEmpleado,
  });

  @override
  State<SelectorFotoEmpleado> createState() => _SelectorFotoEmpleadoState();
}

class _SelectorFotoEmpleadoState extends State<SelectorFotoEmpleado> {
  final _storageSvc = StorageService();
  bool _subiendo = false;

  String get _iniciales {
    final partes = widget.nombreEmpleado.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return widget.nombreEmpleado.isNotEmpty
        ? widget.nombreEmpleado[0].toUpperCase()
        : 'E';
  }

  Future<void> _seleccionar(ImageSource source) async {
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final file = await _storageSvc.seleccionarFoto(source: source);
      if (file == null) return;

      if (mounted) setState(() => _subiendo = true);

      final url = await _storageSvc.subirFotoEmpleado(
        empresaId: widget.empresaId,
        empleadoId: widget.empleadoId,
        fotoFile: file,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Foto de perfil actualizada'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
      debugPrint('Foto subida: $url');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir la foto: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Estás seguro de que deseas eliminar la foto de perfil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    if (mounted) Navigator.pop(context);

    try {
      await _storageSvc.eliminarFotoEmpleado(
        empresaId: widget.empresaId,
        empleadoId: widget.empleadoId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto eliminada'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
          const SizedBox(height: 20),
          Row(
            children: [
              AvatarEmpleado(
                iniciales: _iniciales,
                color: const Color(0xFF0D47A1),
                size: 48,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto de perfil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    widget.nombreEmpleado,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_subiendo)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Subiendo foto…', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else ...[
            _opcionTile(
              icon: Icons.photo_library,
              color: const Color(0xFF0D47A1),
              label: 'Elegir desde galería',
              subtitulo: 'Fotos del dispositivo',
              onTap: () => _seleccionar(ImageSource.gallery),
            ),
            const Divider(height: 1),
            _opcionTile(
              icon: Icons.camera_alt,
              color: const Color(0xFF00796B),
              label: 'Hacer una foto',
              subtitulo: 'Usar cámara del dispositivo',
              onTap: () => _seleccionar(ImageSource.camera),
            ),
            const Divider(height: 1),
            _opcionTile(
              icon: Icons.delete_outline,
              color: Colors.red,
              label: 'Eliminar foto',
              subtitulo: 'Volver a las iniciales',
              onTap: _eliminar,
            ),
          ],
        ],
      ),
    );
  }

  Widget _opcionTile({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitulo, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      onTap: onTap,
    );
  }
}



import 'dart:async';
import 'package:flutter/material.dart';

/// Sistema de notificaciones estilo WhatsApp — esquina inferior izquierda.
/// Sin sonido, sin registro, solo visual.
class FluxToast {
  static final _queue = <_ToastData>[];
  static OverlayEntry? _current;
  static Timer? _timer;
  static final GlobalKey<_ToastOverlayState> _key = GlobalKey();

  /// Muestra una notificación desde cualquier parte de la app.
  static void show(
    BuildContext context,
    String message, {
    String? title,
    IconData icon = Icons.info_outline_rounded,
    Color? color,
    Duration duration = const Duration(seconds: 3),
    ToastTipo tipo = ToastTipo.info,
  }) {
    final data = _ToastData(
      message: message,
      title: title,
      icon: icon,
      color: color ?? tipo.color,
      duration: duration,
    );

    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      if (_current == null) {
        _showEntry(overlay, data);
      } else {
        // Actualizar el existente o encolar
        _key.currentState?.updateData(data);
        _timer?.cancel();
        _timer = Timer(data.duration, _dismiss);
      }
    } catch (_) {}
  }

  static void _showEntry(OverlayState overlay, _ToastData data) {
    _current = OverlayEntry(
      builder: (_) => _ToastOverlay(key: _key, data: data, onDismiss: _dismiss),
    );
    overlay.insert(_current!);
    _timer = Timer(data.duration, _dismiss);
  }

  static void _dismiss() {
    _key.currentState?.dismiss().then((_) {
      _current?.remove();
      _current = null;
      _timer?.cancel();
      _timer = null;
    });
  }

  // Atajos de tipo
  static void exito(BuildContext ctx, String msg,
          {String? title, Duration duration = const Duration(seconds: 3)}) =>
      show(ctx, msg, title: title ?? 'Listo', icon: Icons.check_circle_rounded,
          tipo: ToastTipo.exito, duration: duration);
  static void error(BuildContext ctx, String msg,
          {String? title, Duration duration = const Duration(seconds: 4)}) =>
      show(ctx, msg, title: title ?? 'Error', icon: Icons.error_outline_rounded,
          tipo: ToastTipo.error, duration: duration);
  static void aviso(BuildContext ctx, String msg,
          {String? title, Duration duration = const Duration(seconds: 3)}) =>
      show(ctx, msg, title: title ?? 'Aviso', icon: Icons.warning_amber_rounded,
          tipo: ToastTipo.aviso, duration: duration);
  static void info(BuildContext ctx, String msg,
          {String? title, Duration duration = const Duration(seconds: 3)}) =>
      show(ctx, msg, title: title, icon: Icons.info_outline_rounded,
          tipo: ToastTipo.info, duration: duration);
}

enum ToastTipo {
  exito,
  error,
  aviso,
  info;

  Color get color => switch (this) {
    ToastTipo.exito => const Color(0xFF25D366), // verde WhatsApp
    ToastTipo.error => const Color(0xFFE53935),
    ToastTipo.aviso => const Color(0xFFF59E0B),
    ToastTipo.info  => const Color(0xFF1A73E8),
  };
}

class _ToastData {
  final String message;
  final String? title;
  final IconData icon;
  final Color color;
  final Duration duration;

  const _ToastData({
    required this.message,
    required this.icon,
    required this.color,
    required this.duration,
    this.title,
  });
}

// ── Widget overlay ──────────────────────────────────────────────────────────

class _ToastOverlay extends StatefulWidget {
  final _ToastData data;
  final VoidCallback onDismiss;

  const _ToastOverlay({super.key, required this.data, required this.onDismiss});

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  late _ToastData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  void updateData(_ToastData data) {
    if (!mounted) return;
    setState(() => _data = data);
    _ctrl.forward(from: 0);
  }

  Future<void> dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 24,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2C34), // fondo oscuro estilo WhatsApp
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono de color
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _data.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_data.icon, color: _data.color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    // Texto
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_data.title != null)
                            Text(
                              _data.title!,
                              style: TextStyle(
                                color: _data.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          if (_data.title != null) const SizedBox(height: 2),
                          Text(
                            _data.message,
                            style: const TextStyle(
                              color: Color(0xFFE9EDEF),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

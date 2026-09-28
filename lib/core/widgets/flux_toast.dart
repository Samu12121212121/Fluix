import 'dart:async';
import 'package:flutter/material.dart';

/// Toast global via root Overlay — visible en todas las pantallas.
class FluxToast {
  static OverlayEntry? _current;
  static Timer? _timer;
  static final GlobalKey<_ToastOverlayState> _key = GlobalKey();

  static void show(
    BuildContext context,
    String message, {
    String? title,
    IconData icon = Icons.info_outline_rounded,
    Color? color,
    Duration duration = const Duration(seconds: 4),
    ToastTipo tipo = ToastTipo.info,
    bool persistente = false,
  }) {
    final data = _ToastData(
      message: message,
      title: title,
      icon: icon,
      color: color ?? tipo.color,
      duration: duration,
      persistente: persistente,
    );

    // Eliminar el toast anterior de inmediato (sin animación) para evitar
    // conflicto de GlobalKey si la animación de salida aún no terminó.
    _timer?.cancel();
    _timer = null;
    final toRemove = _current;
    _current = null;
    try { toRemove?.remove(); } catch (_) {}

    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      _current = OverlayEntry(
        builder: (_) => _ToastOverlay(key: _key, data: data, onDismiss: _forceClose),
      );
      overlay.insert(_current!);
      if (!persistente) {
        _timer = Timer(duration, _forceClose);
      }
    } catch (_) {}
  }

  static void _forceClose() {
    _timer?.cancel();
    _timer = null;
    // Capturar la referencia ANTES de setear null para que el callback
    // asíncrono no elimine un toast posterior.
    final toRemove = _current;
    _current = null;
    if (toRemove == null) return;
    try {
      _key.currentState?.dismiss().then((_) {
        try { toRemove.remove(); } catch (_) {}
      }).catchError((_) {
        try { toRemove.remove(); } catch (_) {}
      });
      if (_key.currentState == null) {
        try { toRemove.remove(); } catch (_) {}
      }
    } catch (_) {
      try { toRemove.remove(); } catch (_) {}
    }
  }

  static void dismiss() => _forceClose();

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
  exito, error, aviso, info;

  Color get color => switch (this) {
    ToastTipo.exito => const Color(0xFF25D366),
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
  final bool persistente;

  const _ToastData({
    required this.message,
    required this.icon,
    required this.color,
    required this.duration,
    this.title,
    this.persistente = false,
  });
}

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
  late Animation<double> _fade;
  late _ToastData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  void updateData(_ToastData data) {
    if (!mounted) return;
    setState(() => _data = data);
    _ctrl.forward(from: 0);
  }

  Future<void> dismiss() async {
    if (!mounted) return;
    try { await _ctrl.reverse(); } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _data.color.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _data.color.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Barra superior de color
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _data.color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _data.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_data.icon, color: _data.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_data.title != null)
                      Text(_data.title!,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _data.color)),
                    if (_data.title != null) const SizedBox(height: 2),
                    Text(_data.message,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151), height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

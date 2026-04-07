import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR EMPLEADO — foto de red, archivo local o iniciales
// ─────────────────────────────────────────────────────────────────────────────

class AvatarEmpleado extends StatelessWidget {
  final String? fotoUrl;
  final File? fotoLocal;
  final String iniciales;
  final Color color;
  final double size;
  final bool mostrarBotonCamara;

  const AvatarEmpleado({
    super.key,
    this.fotoUrl,
    this.fotoLocal,
    required this.iniciales,
    required this.color,
    this.size = 56,
    this.mostrarBotonCamara = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    Widget avatar;

    if (fotoLocal != null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(fotoLocal!),
      );
    } else if (fotoUrl != null && fotoUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.1),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: fotoUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
            errorWidget: (_, __, ___) => _inicialesWidget(radius),
          ),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.12),
        child: _inicialesWidget(radius),
      );
    }

    if (!mostrarBotonCamara) return avatar;

    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(
              Icons.camera_alt,
              size: size * 0.2,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _inicialesWidget(double radius) => Text(
        iniciales,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      );
}


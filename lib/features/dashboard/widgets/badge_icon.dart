import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — Badge numérico reutilizable (envuelve cualquier icono)
//
// Uso:
//   BadgeIcon(icon: Icons.task_alt, count: 5, color: Colors.red)
// ─────────────────────────────────────────────────────────────────────────────

class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color? iconColor;
  final Color badgeColor;
  final double iconSize;
  final VoidCallback? onTap;

  const BadgeIcon({
    super.key,
    required this.icon,
    required this.count,
    this.iconColor,
    this.badgeColor = Colors.red,
    this.iconSize = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          if (count > 0)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 14),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


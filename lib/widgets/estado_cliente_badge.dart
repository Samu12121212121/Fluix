import 'package:flutter/material.dart';
import '../../domain/modelos/cliente.dart';

/// Widget reutilizable tipo "pill" que muestra el estado del cliente.
/// - Verde: Activo
/// - Gris: Inactivo
/// - Azul: Contacto
class EstadoClienteBadge extends StatelessWidget {
  final EstadoCliente estado;
  final bool compact;

  const EstadoClienteBadge({
    super.key,
    required this.estado,
    this.compact = false,
  });

  /// Crea un badge a partir del string del campo Firestore.
  factory EstadoClienteBadge.fromString(String? estadoStr, {bool compact = false}) {
    final estado = EstadoCliente.values.firstWhere(
      (e) => e.name == estadoStr,
      orElse: () => EstadoCliente.contacto,
    );
    return EstadoClienteBadge(estado: estado, compact: compact);
  }

  Color get _color => switch (estado) {
        EstadoCliente.activo => const Color(0xFF4CAF50),
        EstadoCliente.inactivo => const Color(0xFF9E9E9E),
        EstadoCliente.contacto => const Color(0xFF2196F3),
      };

  String get _texto => switch (estado) {
        EstadoCliente.activo => 'Activo',
        EstadoCliente.inactivo => 'Inactivo',
        EstadoCliente.contacto => 'Contacto',
      };

  IconData get _icono => switch (estado) {
        EstadoCliente.activo => Icons.check_circle,
        EstadoCliente.inactivo => Icons.pause_circle_filled,
        EstadoCliente.contacto => Icons.person_outline,
      };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _color.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icono, size: 12, color: _color),
          const SizedBox(width: 4),
          Text(
            _texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de "Ficha incompleta" para clientes creados rápidamente.
class FichaIncompletaBadge extends StatelessWidget {
  const FichaIncompletaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note, size: 11, color: Colors.orange),
          SizedBox(width: 3),
          Text(
            'Ficha incompleta',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}


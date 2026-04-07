import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CabeceraDashboard extends StatelessWidget {
  const CabeceraDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar del usuario
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF1976D2),
              child: Text(
                _obtenerIniciales(user?.displayName ?? user?.email ?? 'Usuario'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Información del usuario
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola, ${_obtenerPrimerNombre(user?.displayName ?? user?.email ?? 'Usuario')}!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Propietario',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF1976D2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Estado
            _buildEstadoSuscripcion(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoSuscripcion(BuildContext context) {
    const color = Color(0xFF4CAF50); // Verde para activa

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            'Activa',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _obtenerIniciales(String nombre) {
    final nombres = nombre.trim().split(' ');
    if (nombres.length >= 2) {
      return '${nombres[0][0]}${nombres[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';
  }

  String _obtenerPrimerNombre(String nombre) {
    if (nombre.contains('@')) {
      // Si es un email, usar la parte antes del @
      return nombre.split('@').first.split('.').first;
    }
    return nombre.trim().split(' ').first;
  }
}

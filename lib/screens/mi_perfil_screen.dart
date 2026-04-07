import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class MiPerfilScreen extends StatelessWidget {
  final AppUser user;

  const MiPerfilScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF0D47A1),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildInfoTile(
            icon: Icons.person,
            label: 'Nombre',
            value: user.name,
          ),
          _buildInfoTile(
            icon: Icons.email,
            label: 'Correo electrónico',
            value: user.email,
          ),
          _buildInfoTile(
            icon: Icons.badge,
            label: 'Rol',
            value: user.isCompanyAdmin
                ? 'Administrador'
                : user.isCompanyManager
                    ? 'Manager'
                    : 'Usuario',
          ),
          _buildInfoTile(
            icon: Icons.business,
            label: 'ID Empresa',
            value: user.companyId ?? 'Sin empresa asignada',
          ),
          _buildInfoTile(
            icon: Icons.calendar_today,
            label: 'Cuenta creada',
            value:
                '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
          ),

          const SizedBox(height: 32),

          // Cambiar contraseña
          OutlinedButton.icon(
            onPressed: () => _cambiarContrasena(context),
            icon: const Icon(Icons.lock_reset),
            label: const Text('Cambiar contraseña'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D47A1),
              side: const BorderSide(color: Color(0xFF0D47A1)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0D47A1)),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle:
            Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _cambiarContrasena(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Enlace de cambio de contraseña enviado a tu correo.',
            ),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


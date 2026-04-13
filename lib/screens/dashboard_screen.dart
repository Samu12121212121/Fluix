// ⚠️ ARCHIVO LEGACY — NO USAR
// Este archivo es código scaffolding anterior (carpeta screens/) y NO está
// integrado en la app de producción.
// El dashboard real está en:
//   lib/features/dashboard/pantallas/pantalla_dashboard.dart
//
// Puede eliminarse cuando se limpie la carpeta screens/ completa.
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import 'welcome_screen.dart';
import 'manage_managers_screen.dart';

class DashboardScreen extends StatelessWidget {
  final AppUser user;
  final Company? company;

  const DashboardScreen({
    super.key,
    required this.user,
    this.company,
  });

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  String _getRoleDisplayName() {
    switch (user.role) {
      case UserRole.companyAdmin:
        return 'Administrador';
      case UserRole.companyManager:
        return 'Manager';
      case UserRole.normalUser:
        return 'Usuario';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(company?.name ?? 'Fluix CRM'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de bienvenida
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF0D47A1),
                          child: Text(
                            user.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bienvenido, ${user.name}',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _getRoleDisplayName(),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Información de la empresa
            if (company != null) ...[
              Text(
                'Información de la Empresa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.business, color: Color(0xFF0D47A1)),
                  title: Text(company!.name),
                  subtitle: Text('Creada: ${_formatDate(company!.createdAt)}'),
                  trailing: Icon(
                    company!.isActive ? Icons.check_circle : Icons.cancel,
                    color: company!.isActive ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Funcionalidades según el rol
            Text(
              'Funcionalidades',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (user.isCompanyAdmin) ...[
              _buildFeatureCard(
                context,
                icon: Icons.people,
                title: 'Gestionar Managers',
                subtitle: 'Agregar o remover managers de la empresa',
                onTap: () {
                  if (company != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageManagersScreen(
                          company: company!,
                          currentUser: user,
                        ),
                      ),
                    );
                  }
                },
              ),
              _buildFeatureCard(
                context,
                icon: Icons.settings,
                title: 'Configuración de Empresa',
                subtitle: 'Modificar configuraciones generales',
                onTap: () {
                  // TODO: Implementar configuración
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente: Configuración')),
                  );
                },
              ),
            ] else if (user.isCompanyManager) ...[
              _buildFeatureCard(
                context,
                icon: Icons.dashboard,
                title: 'Panel de Control',
                subtitle: 'Ver métricas y estadísticas',
                onTap: () {
                  // TODO: Implementar panel de control
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente: Panel de control')),
                  );
                },
              ),
              _buildFeatureCard(
                context,
                icon: Icons.assignment,
                title: 'Gestionar Tareas',
                subtitle: 'Administrar tareas y proyectos',
                onTap: () {
                  // TODO: Implementar gestión de tareas
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente: Gestión de tareas')),
                  );
                },
              ),
            ] else ...[
              _buildFeatureCard(
                context,
                icon: Icons.person,
                title: 'Mi Perfil',
                subtitle: 'Ver y editar información personal',
                onTap: () {
                  // TODO: Implementar perfil
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente: Mi perfil')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0D47A1)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

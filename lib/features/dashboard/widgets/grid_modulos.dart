import 'package:flutter/material.dart';

class GridModulos extends StatelessWidget {
  const GridModulos({super.key});

  @override
  Widget build(BuildContext context) {
    final modulos = [
      _ItemModulo(
        titulo: 'Reservas',
        descripcion: 'Gestión de citas',
        icono: Icons.calendar_today,
        color: const Color(0xFF1976D2),
        valor: '24',
      ),
      _ItemModulo(
        titulo: 'Clientes',
        descripcion: 'Base de datos',
        icono: Icons.people,
        color: const Color(0xFF388E3C),
        valor: '156',
      ),
      _ItemModulo(
        titulo: 'Servicios',
        descripcion: 'Catálogo',
        icono: Icons.room_service,
        color: const Color(0xFF7B1FA2),
        valor: '8',
      ),
      _ItemModulo(
        titulo: 'Finanzas',
        descripcion: 'Ingresos y gastos',
        icono: Icons.account_balance,
        color: const Color(0xFF689F38),
        valor: '\$2,450',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Módulos Activos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: modulos.length,
          itemBuilder: (context, index) {
            final modulo = modulos[index];
            return _TarjetaModulo(
              item: modulo,
              onTap: () => _navegarAModulo(context, modulo.titulo),
            );
          },
        ),
      ],
    );
  }

  void _navegarAModulo(BuildContext context, String modulo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$modulo próximamente'),
        backgroundColor: const Color(0xFF2196F3),
      ),
    );
  }
}

class _ItemModulo {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;
  final String valor;

  const _ItemModulo({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.color,
    required this.valor,
  });
}

class _TarjetaModulo extends StatelessWidget {
  final _ItemModulo item;
  final VoidCallback onTap;

  const _TarjetaModulo({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono principal
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icono,
                  color: item.color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              // Título del módulo
              Text(
                item.titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: item.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Valor/estadística
              Text(
                item.valor,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              // Descripción
              const SizedBox(height: 4),
              Text(
                item.descripcion,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

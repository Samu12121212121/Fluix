import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON LOADERS — Placeholders animados para el dashboard
//
// Se muestran mientras los datos reales cargan de Firestore.
// Usan el paquete `shimmer` que ya está en pubspec.yaml.
// ─────────────────────────────────────────────────────────────────────────────

/// Tarjeta skeleton genérica con efecto shimmer.
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Skeleton del módulo de estadísticas (gráfico + KPIs).
class SkeletonEstadisticas extends StatelessWidget {
  const SkeletonEstadisticas({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonCard(height: 200), // Gráfico
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 80)),
            Expanded(child: SkeletonCard(height: 80)),
          ],
        ),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 80)),
            Expanded(child: SkeletonCard(height: 80)),
          ],
        ),
      ],
    );
  }
}

/// Skeleton de una lista de items (reservas, tareas, etc.).
class SkeletonLista extends StatelessWidget {
  final int items;
  const SkeletonLista({super.key, this.items = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        items,
        (_) => const SkeletonCard(height: 72),
      ),
    );
  }
}

/// Skeleton completo del dashboard (para la primera carga).
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: 8),
          // KPIs superiores
          Row(
            children: [
              Expanded(child: SkeletonCard(height: 90)),
              Expanded(child: SkeletonCard(height: 90)),
            ],
          ),
          // Gráfico principal
          SkeletonCard(height: 180),
          // Lista de items recientes
          SkeletonCard(height: 72),
          SkeletonCard(height: 72),
          SkeletonCard(height: 72),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Widget helper que muestra skeleton o contenido real.
///
/// Uso:
/// ```dart
/// SkeletonSwitch(
///   cargando: _cargando,
///   skeleton: const SkeletonLista(),
///   child: ListaReservasReal(...),
/// )
/// ```
class SkeletonSwitch extends StatelessWidget {
  final bool cargando;
  final Widget skeleton;
  final Widget child;

  const SkeletonSwitch({
    super.key,
    required this.cargando,
    required this.skeleton,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: cargando ? skeleton : child,
    );
  }
}


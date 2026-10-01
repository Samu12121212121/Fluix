import 'package:flutter/material.dart';
import '../utils/app_settings.dart';
import '../utils/permisos_service.dart';
import '../../services/bandeja_notificaciones_service.dart';
import '../../features/dashboard/widgets/badge_icon.dart';
import '../../features/dashboard/pantallas/bandeja_notificaciones_screen.dart';
import '../../features/perfil/pantallas/pantalla_perfil.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FluixBottomNav — barra de navegación inferior compartida
//
// Se usa como bottomNavigationBar en FluixModuleShell para que TODOS los
// módulos tengan la misma barra inferior que el dashboard.
//
// Navegación:
//   🏠 Inicio   → pop al dashboard, tab 0 (home)
//   ⚡ Módulos  → pop al dashboard, tab 1 (lista de módulos)
//   ＋ Acciones → vuelve al dashboard (que abre el modal)
//   🔔 Notif    → navega a BandejaNotificaciones
//   👤 Perfil   → navega a PantallaPerfil
// ─────────────────────────────────────────────────────────────────────────────

class FluixBottomNav extends StatelessWidget {
  final String? empresaId;
  final bool esPropietario;

  const FluixBottomNav({super.key, this.empresaId, this.esPropietario = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.darkMode,
      builder: (_, isDark, __) => _buildBar(context, isDark),
    );
  }

  Widget _buildBar(BuildContext context, bool isDark) {
    final bg        = isDark ? const Color(0xFF1E2139) : Colors.white;
    final unselected = isDark ? const Color(0xFF6B7280) : Colors.grey.shade500;
    const selected  = Color(0xFF3B82F6);
    final divColor  = isDark ? Colors.white12 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: divColor)),
        boxShadow: isDark
            ? []
            : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              )],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            // 🏠 Inicio
            _navItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              color: unselected,
              onTap: () {
                AppSettings.setTargetTab(0);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),

            // ⚡ Módulos
            _navItem(
              icon: Icons.grid_view_rounded,
              label: 'Módulos',
              color: unselected,
              onTap: () {
                AppSettings.setTargetTab(1);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),

            // ＋ Volver al dashboard para acciones rápidas
            GestureDetector(
              onTap: () {
                AppSettings.setTargetTab(0);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: Container(
                width: 50, height: 50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: Color(0x663B82F6),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  )],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
              ),
            ),

            // 🔔 Notificaciones
            if (empresaId != null)
              StreamBuilder<int>(
                stream: BandejaNotificacionesService().noLeidasCount(empresaId!),
                builder: (_, snap) => _navItem(
                  icon: Icons.notifications_outlined,
                  label: 'Notif.',
                  color: unselected,
                  badge: snap.data ?? 0,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BandejaNotificacionesScreen(empresaId: empresaId!, esPropietario: esPropietario),
                  )),
                ),
              )
            else
              _navItem(
                icon: Icons.notifications_outlined,
                label: 'Notif.',
                color: unselected,
                onTap: () {},
              ),

            // 👤 Perfil
            _navItem(
              icon: Icons.person_outline_rounded,
              label: 'Perfil',
              color: unselected,
              onTap: () {
                final sesion = PermisosService().sesion;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PantallaPerfil(
                    sesion: sesion,
                    dark: AppSettings.darkMode.value,
                  ),
                ));
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            badge > 0
                ? BadgeIcon(
                    icon: icon,
                    count: badge,
                    iconColor: color,
                    iconSize: 22,
                  )
                : Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.normal,
              color: color,
            ), maxLines: 1),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// FluixModuleShell — shell transparente que añade FluixBottomNav a cualquier
// widget sin modificar la pantalla interna.
//
// Uso en _abrirModulo del dashboard:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => FluixModuleShell(child: screen, empresaId: eid),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

class FluixModuleShell extends StatelessWidget {
  final Widget child;
  final String? empresaId;

  const FluixModuleShell({super.key, required this.child, this.empresaId});

  @override
  Widget build(BuildContext context) {
    final size             = MediaQuery.of(context).size;
    final isPortraitMobile = size.shortestSide < 600 && size.height > size.width;

    // Solo mostrar la barra inferior en portrait mobile
    if (!isPortraitMobile) return child;

    return Scaffold(
      // backgroundColor transparente para que el inner Scaffold se vea
      backgroundColor: Colors.transparent,
      // No AppBar — cada módulo gestiona su propio header/appBar
      body: child,
      bottomNavigationBar: FluixBottomNav(empresaId: empresaId),
    );
  }
}

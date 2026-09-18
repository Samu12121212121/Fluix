import 'package:flutter/material.dart';
import '../layout/fluix_module_actions.dart';
import '../utils/app_settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FluixAppBar — AppBar compartido de la app
//
// Uso:
//   Scaffold(
//     appBar: FluixAppBar(
//       titulo: 'Clientes',           // null = solo logo
//       onCambiarEmpresa: () => ...,  // null = no muestra el botón
//       extraActions: [IconButton(...)],
//       onManejarMenu: (v) => ...,    // null = no muestra 3-dots
//       onToggleDark: () => ...,
//       empresaId: id,
//       esPropietarioPlatforma: true,
//       empresaActiva: id != idPropia,
//     ),
//   )
//
// Comportamiento responsivo:
//   - Portrait mobile (< 600px ancho): oculta modo oscuro y 3-puntos
//     porque el BottomNavigationBar ya cubre esas acciones.
//   - "Cambiar empresa" solo aparece si AppSettings.numEmpresas > 1
//     y esPropietarioPlatforma == true.
// ─────────────────────────────────────────────────────────────────────────────

class FluixAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? titulo;
  /// Breadcrumb multi-nivel. Cuando se proporciona, reemplaza a [titulo].
  /// El último item se muestra resaltado; los anteriores son clicables.
  /// Ejemplo: [Inicio onTap=popToHome, Facturación onTap=popOne, Modelos]
  final List<FluixBreadcrumbItem>? breadcrumbItems;
  final bool esPropietarioPlatforma;
  final bool empresaActiva;        // true si está viendo una empresa distinta a la propia
  final VoidCallback? onCambiarEmpresa;
  final String? empresaIdActiva;   // para badge de notificaciones
  final void Function(String)? onManejarMenu;
  final List<Widget> extraActions; // botones específicos de la pantalla
  final Widget? notifWidget;       // widget de campana (con badge)
  final bool showLeading;          // mostrar < antes del logo
  final bool titleNavigatesBack;   // el logo/título navega atrás sin mostrar <

  const FluixAppBar({
    super.key,
    this.titulo,
    this.breadcrumbItems,
    this.esPropietarioPlatforma = false,
    this.empresaActiva = false,
    this.onCambiarEmpresa,
    this.empresaIdActiva,
    this.onManejarMenu,
    this.extraActions = const [],
    this.notifWidget,
    this.showLeading = false,
    this.titleNavigatesBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Reactive a cambios de dark mode sin setState en el padre
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.darkMode,
      builder: (context, isDark, _) => _buildBar(context, isDark),
    );
  }

  Widget _buildBar(BuildContext context, bool isDark) {
    final size            = MediaQuery.of(context).size;
    final isPortraitMobile = size.shortestSide < 600 && size.height > size.width;

    final iconColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151);
    final bg        = isDark ? const Color(0xFF0A0F23) : Colors.white;

    // Mostrar "cambiar empresa" siempre para propietario_plataforma
    final mostrarSelectorEmpresa =
        esPropietarioPlatforma &&
        onCambiarEmpresa != null;

    final VoidCallback? backFn = (showLeading || titleNavigatesBack)
        ? () => Navigator.of(context).pop()
        : null;

    return AppBar(
      backgroundColor:       bg,
      elevation:             isDark ? 0 : 0.5,
      scrolledUnderElevation: 0,
      surfaceTintColor:      Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle:           false,
      titleSpacing:          20,
      title: _FluixTitle(
        titulo: titulo,
        breadcrumbItems: breadcrumbItems,
        isDark: isDark,
        onBack: showLeading ? backFn : null,
        onTapTitle: titleNavigatesBack ? backFn : null,
        iconColor: iconColor,
      ),
      actions: [
        // ── Acciones específicas de la pantalla ───────────────────────────
        ...extraActions,

        // ── Selector de empresa (solo propietario plataforma con > 1) ─────
        if (mostrarSelectorEmpresa)
          IconButton(
            tooltip: empresaActiva ? 'Cambiar empresa' : 'Mi empresa',
            icon: Stack(clipBehavior: Clip.none, children: [
              Icon(Icons.business_rounded,
                  color: empresaActiva ? const Color(0xFF00FFC8) : iconColor,
                  size: 22),
              if (empresaActiva)
                Positioned(top: -2, right: -2, child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B35), shape: BoxShape.circle),
                )),
            ]),
            onPressed: onCambiarEmpresa,
          ),

        // ── Notificaciones ─────────────────────────────────────────────────
        if (notifWidget != null) notifWidget!,

        // ── Modo oscuro (visible siempre, incluso en portrait mobile) ──────
        _DarkToggle(isDark: isDark),

        // ── 3-dots menu (oculto en portrait mobile) ────────────────────────
        if (!isPortraitMobile && onManejarMenu != null)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: iconColor),
            onSelected: onManejarMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'perfil', child: ListTile(
                leading: Icon(Icons.person),
                title: Text('Mi Perfil'),
                contentPadding: EdgeInsets.zero,
              )),
              PopupMenuDivider(),
              PopupMenuItem(value: 'vista_usuario', child: ListTile(
                leading: Icon(Icons.storefront_rounded, color: Color(0xFF00ACC1)),
                title: Text('Explorar', style: TextStyle(color: Color(0xFF00ACC1))),
                contentPadding: EdgeInsets.zero,
              )),
              PopupMenuDivider(),
              PopupMenuItem(value: 'cerrar_sesion', child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              )),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo: 4 cuadrados morados en 2×2
// ─────────────────────────────────────────────────────────────────────────────

class FluixLogo extends StatelessWidget {
  final double size;
  const FluixLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final sq = size / 2 - 1;
    return SizedBox(
      width: size, height: size,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          _square(sq), const SizedBox(width: 2), _square(sq),
        ]),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _square(sq), const SizedBox(width: 2), _square(sq),
        ]),
      ]),
    );
  }

  Widget _square(double s) => Container(
    width: s, height: s,
    decoration: BoxDecoration(
      color: const Color(0xFF7C3AED),
      borderRadius: BorderRadius.circular(s * 0.25),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Título del AppBar: logo + breadcrumb "Fluix > Módulo"
// ─────────────────────────────────────────────────────────────────────────────

class _FluixTitle extends StatelessWidget {
  final String? titulo;
  final List<FluixBreadcrumbItem>? breadcrumbItems;
  final bool isDark;
  final VoidCallback? onBack;
  final VoidCallback? onTapTitle;
  final Color? iconColor;
  const _FluixTitle({
    this.titulo,
    this.breadcrumbItems,
    required this.isDark,
    this.onBack,
    this.onTapTitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF);
    final ic        = iconColor ?? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151));

    // Breadcrumb multi-nivel (tiene prioridad sobre titulo)
    final items = breadcrumbItems;
    if (items != null && items.isNotEmpty) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (onBack != null) ...[
          GestureDetector(onTap: onBack,
              child: Icon(Icons.arrow_back_ios_rounded, size: 18, color: ic)),
          const SizedBox(width: 6),
        ],
        const FluixLogo(size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: _BreadcrumbRow(items: items, textColor: textColor, subColor: subColor),
        ),
      ]);
    }

    // Modo legacy: solo titulo (backward compat)
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      if (onBack != null) ...[
        GestureDetector(
          onTap: onBack,
          child: Icon(Icons.arrow_back_ios_rounded, size: 18, color: ic),
        ),
        const SizedBox(width: 6),
      ],
      const FluixLogo(size: 22),
      const SizedBox(width: 8),
      if (titulo != null) ...[
        // "Inicio" como primer nivel del breadcrumb (antes era "Fluix")
        GestureDetector(
          onTap: onBack,
          child: Text('Inicio', style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.3,
            color: subColor,
          )),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right_rounded, size: 16, color: subColor),
        ),
        Flexible(
          child: Text(titulo!, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2,
            color: textColor,
          ), overflow: TextOverflow.ellipsis),
        ),
      ] else
        Text('Fluix', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.3,
          color: textColor,
        )),
    ]);

    if (onTapTitle != null) {
      return GestureDetector(onTap: onTapTitle, child: row);
    }
    return row;
  }
}

// Widget auxiliar para renderizar el breadcrumb multi-nivel
class _BreadcrumbRow extends StatelessWidget {
  final List<FluixBreadcrumbItem> items;
  final Color textColor;
  final Color subColor;
  const _BreadcrumbRow({required this.items, required this.textColor, required this.subColor});

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;
      if (isLast) {
        widgets.add(Flexible(
          child: Text(item.label,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16,
                letterSpacing: -0.2, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ));
      } else {
        widgets.add(GestureDetector(
          onTap: item.onTap,
          child: Text(item.label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                letterSpacing: -0.2, color: subColor),
          ),
        ));
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.chevron_right_rounded, size: 14, color: subColor),
        ));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle modo oscuro (mismo diseño que el del dashboard)
// ─────────────────────────────────────────────────────────────────────────────

class _DarkToggle extends StatelessWidget {
  final bool isDark;
  const _DarkToggle({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      onPressed: () => AppSettings.setDark(!isDark),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: isDark
            ? const Icon(Icons.nightlight_round,
                key: ValueKey('moon'), size: 20, color: Color(0xFF93C5FD))
            : const Icon(Icons.wb_sunny_rounded,
                key: ValueKey('sun'), size: 20, color: Color(0xFFF59E0B)),
      ),
    );
  }
}

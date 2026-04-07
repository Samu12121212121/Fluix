import 'package:flutter/material.dart';

// ── PLANES DE SUSCRIPCIÓN ─────────────────────────────────────────────────────

enum PlanModulo {
  /// Incluido en todos los planes (300€/año base)
  basico,
  /// Pack Gestión + WhatsApp: 350€/año
  gestion,
  /// Pack Tienda Online (pedidos + facturación): 450€/año
  tienda,
}

extension PlanModuloExt on PlanModulo {
  String get nombre {
    switch (this) {
      case PlanModulo.basico:   return 'Plan Base';
      case PlanModulo.gestion:  return 'Pack Gestión';
      case PlanModulo.tienda:   return 'Pack Tienda Online';
    }
  }

  String get precio {
    switch (this) {
      case PlanModulo.basico:   return '300€/año';
      case PlanModulo.gestion:  return '350€/año';
      case PlanModulo.tienda:   return '450€/año';
    }
  }

  Color get color {
    switch (this) {
      case PlanModulo.basico:   return const Color(0xFF1976D2);
      case PlanModulo.gestion:  return const Color(0xFF7B1FA2);
      case PlanModulo.tienda:   return const Color(0xFFE65100);
    }
  }

  IconData get icono {
    switch (this) {
      case PlanModulo.basico:   return Icons.star_outline;
      case PlanModulo.gestion:  return Icons.workspace_premium;
      case PlanModulo.tienda:   return Icons.storefront;
    }
  }
}

// ── MÓDULOS DE TAB (pestañas del menú) ───────────────────────────────────────

/// Representa un módulo/pestaña del menú principal (no solo widget del dashboard)
class ModuloConfig {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  final bool activo;
  final PlanModulo plan;
  /// true = viene por defecto en el plan, false = add-on de pago adicional
  final bool incluidoEnPlan;
  /// Precio adicional si es add-on (ej: WhatsApp 50€/año extra)
  final String? precioAdicional;

  const ModuloConfig({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icono,
    required this.activo,
    required this.plan,
    this.incluidoEnPlan = true,
    this.precioAdicional,
  });

  ModuloConfig copyWith({bool? activo}) => ModuloConfig(
    id: id,
    nombre: nombre,
    descripcion: descripcion,
    icono: icono,
    activo: activo ?? this.activo,
    plan: plan,
    incluidoEnPlan: incluidoEnPlan,
    precioAdicional: precioAdicional,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'activo': activo,
  };

  factory ModuloConfig.fromMap(Map<String, dynamic> map, ModuloConfig base) =>
      base.copyWith(activo: map['activo'] as bool? ?? base.activo);
}

// ── CATÁLOGO COMPLETO DE MÓDULOS ──────────────────────────────────────────────

class ModulosDisponibles {
  static List<ModuloConfig> get todos => [
    // ── MÓDULO PROPIETARIO (solo visible en Fluixtech) ────────────────
    ModuloConfig(
      id: 'propietario',
      nombre: 'Panel Propietario',
      descripcion: 'Estadísticas globales de la plataforma (solo Fluixtech)',
      icono: Icons.admin_panel_settings,
      activo: false,
      plan: PlanModulo.basico,
    ),
    // ── PLAN BASE (300€/año) ───────────────────────────────────────────────
    ModuloConfig(
      id: 'dashboard',
      nombre: 'Dashboard',
      descripcion: 'Resumen general del negocio con widgets personalizables',
      icono: Icons.dashboard,
      activo: true, // Siempre activo — no se puede desactivar
      plan: PlanModulo.basico,
    ),
    ModuloConfig(
      id: 'valoraciones',
      nombre: 'Valoraciones',
      descripcion: 'Gestiona las reseñas y valoraciones de clientes',
      icono: Icons.star,
      activo: false,
      plan: PlanModulo.basico,
    ),
    ModuloConfig(
      id: 'estadisticas',
      nombre: 'Estadísticas',
      descripcion: 'Métricas y KPIs del negocio en tiempo real',
      icono: Icons.analytics,
      activo: false,
      plan: PlanModulo.basico,
    ),
    ModuloConfig(
      id: 'reservas',
      nombre: 'Reservas',
      descripcion: 'Gestión de citas y reservas de clientes',
      icono: Icons.calendar_today,
      activo: false,
      plan: PlanModulo.basico,
    ),
    ModuloConfig(
      id: 'citas',
      nombre: 'Citas',
      descripcion: 'Agenda de citas con el mismo estilo visual que reservas',
      icono: Icons.event_available,
      activo: false,
      plan: PlanModulo.basico,
    ),
    ModuloConfig(
      id: 'web',
      nombre: 'Contenido Web',
      descripcion: 'Gestiona el contenido dinámico de tu página web',
      icono: Icons.web,
      activo: false,
      plan: PlanModulo.basico,
    ),
    // ── PACK GESTIÓN (350€/año) ────────────────────────────────────────────
    ModuloConfig(
      id: 'whatsapp',
      nombre: 'WhatsApp',
      descripcion: 'Gestiona pedidos y comunicaciones por WhatsApp',
      icono: Icons.chat_bubble_outline,
      activo: false,
      plan: PlanModulo.gestion,
    ),
    ModuloConfig(
      id: 'facturacion',
      nombre: 'Facturación',
      descripcion: 'Facturas, IVA, resumen fiscal y estadísticas de cobros',
      icono: Icons.receipt_long,
      activo: false,
      plan: PlanModulo.gestion,
    ),
    // ── PACK TIENDA ONLINE (450€/año) ──────────────────────────────────────
    ModuloConfig(
      id: 'pedidos',
      nombre: 'Pedidos',
      descripcion: 'Catálogo de productos y gestión de pedidos online',
      icono: Icons.shopping_bag_outlined,
      activo: false,
      plan: PlanModulo.tienda,
    ),
    // ── ADD-ON: TAREAS ────────────────────────────────────────────────────
    ModuloConfig(
      id: 'tareas',
      nombre: 'Tareas',
      descripcion: 'Gestión de tareas y productividad por usuario',
      icono: Icons.task_alt,
      activo: false,
      plan: PlanModulo.basico,
      incluidoEnPlan: false,
      precioAdicional: 'Precio por usuario/mes',
    ),
    // ── CRM ───────────────────────────────────────────────────────────────
    ModuloConfig(
      id: 'clientes',
      nombre: 'Clientes',
      descripcion: 'Gestión de clientes, historial y CRM',
      icono: Icons.people,
      activo: false,
      plan: PlanModulo.basico,
    ),
    ModuloConfig(
      id: 'empleados',
      nombre: 'Empleados',
      descripcion: 'Gestión del equipo y roles de acceso',
      icono: Icons.badge,
      activo: false,
      plan: PlanModulo.basico,
    ),
    ModuloConfig(
      id: 'nominas',
      nombre: 'Nóminas',
      descripcion: 'Cálculo automático, IRPF y envío de nóminas 2026',
      icono: Icons.payments,
      activo: false,
      plan: PlanModulo.gestion,
    ),
    ModuloConfig(
      id: 'vacaciones',
      nombre: 'Vacaciones',
      descripcion: 'Gestión de vacaciones, ausencias y permisos retribuidos',
      icono: Icons.beach_access,
      activo: false,
      plan: PlanModulo.gestion,
    ),
    ModuloConfig(
      id: 'servicios',
      nombre: 'Servicios',
      descripcion: 'Catálogo de servicios, precios y categorías',
      icono: Icons.miscellaneous_services,
      activo: false,
      plan: PlanModulo.basico,
    ),
  ];

  /// Módulos siempre activos que no se pueden desactivar
  static const List<String> siempreActivos = [
    'dashboard', // El dashboard principal siempre visible
  ];

  /// Módulos opcionales pero recomendados del plan básico (se pueden desactivar)
  static const List<String> opcionalesBasico = [
    'citas',
  ];

  /// Módulos activos por defecto al inicializar (solo dashboard)
  /// El resto el usuario los activa explícitamente desde Ajustes
  static List<String> get activosPorDefecto => ['dashboard'];
}


// ── WIDGET CONFIG (dashboard) ─────────────────────────────────────────────────

class WidgetConfig {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  final bool activo;
  final int orden;
  final Map<String, dynamic> configuracion;

  WidgetConfig({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.icono,
    this.activo = true,
    required this.orden,
    this.configuracion = const {},
  });

  factory WidgetConfig.fromMap(Map<String, dynamic> map) {
    return WidgetConfig(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      icono: _iconFromString(map['icono'] ?? ''),
      activo: map['activo'] ?? true,
      orden: map['orden'] ?? 0,
      configuracion: map['configuracion'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'icono': _iconToString(icono),
      'activo': activo,
      'orden': orden,
      'configuracion': configuracion,
    };
  }

  WidgetConfig copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    IconData? icono,
    bool? activo,
    int? orden,
    Map<String, dynamic>? configuracion,
  }) {
    return WidgetConfig(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      icono: icono ?? this.icono,
      activo: activo ?? this.activo,
      orden: orden ?? this.orden,
      configuracion: configuracion ?? this.configuracion,
    );
  }

  static IconData _iconFromString(String iconString) {
    switch (iconString) {
      case 'calendar_view_week':    return Icons.calendar_view_week;
      case 'analytics':             return Icons.analytics;
      case 'star':                  return Icons.star;
      case 'calendar_today':        return Icons.calendar_today;
      case 'trending_up':           return Icons.trending_up;
      case 'people':                return Icons.people;
      case 'euro':                  return Icons.euro;
      case 'notifications':         return Icons.notifications;
      case 'local_offer':           return Icons.local_offer;
      case 'schedule':              return Icons.schedule;
      case 'web':                   return Icons.web;
      case 'task_alt':              return Icons.task_alt;
      case 'shopping_bag':          return Icons.shopping_bag_outlined;
      case 'chat_bubble':           return Icons.chat_bubble_outline;
      case 'receipt_long':          return Icons.receipt_long;
      case 'wb_sunny':              return Icons.wb_sunny;
      case 'gavel':                 return Icons.gavel;
      case 'event_available':       return Icons.event_available;
      case 'notifications_active':  return Icons.notifications_active;
    }
  }

  static String _iconToString(IconData icon) {
    if (icon == Icons.calendar_view_week)    return 'calendar_view_week';
    if (icon == Icons.analytics)             return 'analytics';
    if (icon == Icons.star)                  return 'star';
    if (icon == Icons.calendar_today)        return 'calendar_today';
    if (icon == Icons.trending_up)           return 'trending_up';
    if (icon == Icons.people)                return 'people';
    if (icon == Icons.euro)                  return 'euro';
    if (icon == Icons.notifications)         return 'notifications';
    if (icon == Icons.local_offer)           return 'local_offer';
    if (icon == Icons.schedule)              return 'schedule';
    if (icon == Icons.web)                   return 'web';
    if (icon == Icons.task_alt)              return 'task_alt';
    if (icon == Icons.shopping_bag_outlined) return 'shopping_bag';
    if (icon == Icons.chat_bubble_outline)   return 'chat_bubble';
    if (icon == Icons.receipt_long)          return 'receipt_long';
    if (icon == Icons.wb_sunny)              return 'wb_sunny';
    if (icon == Icons.gavel)                 return 'gavel';
    if (icon == Icons.event_available)       return 'event_available';
    if (icon == Icons.notifications_active)  return 'notifications_active';
    return 'widgets';
  }

  static List<WidgetConfig> obtenerWidgetsDefault() {
    return [
      // ── IMPLEMENTADOS Y ACTIVOS POR DEFECTO ───────────────────────────────
      WidgetConfig(
        id: 'briefing_matutino',
        nombre: 'Briefing Matutino',
        descripcion: 'Resumen inteligente del día (visible de 6h a 12h)',
        icono: Icons.wb_sunny,
        activo: true,
        orden: 0,
      ),
      WidgetConfig(
      WidgetConfig(
        id: 'proximos_dias',
        nombre: 'Próximos 3 Días',
        descripcion: 'Reservas y alertas de los próximos días',
        icono: Icons.calendar_view_week,
        activo: true,
        orden: 1,
      ),
      WidgetConfig(
        id: 'reservas_hoy',
        nombre: 'Reservas de Hoy',
        descripcion: 'Citas y reservas del día en curso',
        icono: Icons.calendar_today,
        activo: true,
        orden: 2,
      ),
        id: 'alertas_fiscales',
        nombre: 'Alertas Fiscales',
        icono: Icons.calendar_today,
        activo: true,
        orden: 3,
      ),
      WidgetConfig(
        id: 'citas_resumen',
        nombre: 'Resumen de Citas',
        descripcion: 'Próximas citas del día con hora y cliente',
        icono: Icons.event_available,
        activo: true,
        orden: 4,
      ),
      WidgetConfig(
        id: 'valoraciones_recientes',
        nombre: 'Valoraciones Recientes',
        descripcion: 'Últimas reseñas y puntuaciones de clientes',
        icono: Icons.star,
        activo: true,
        orden: 5,
      ),
      WidgetConfig(
        id: 'kpis_rapidos',
        nombre: 'KPIs Rápidos',
        descripcion: 'Reservas de hoy, ingresos de la semana y rating promedio',
        icono: Icons.trending_up,
        orden: 6,
      ),
      // ── IMPLEMENTADOS, DESACTIVADOS POR DEFECTO ───────────────────────────
      WidgetConfig(
        id: 'resumen_facturacion',
        nombre: 'Resumen Facturación',
        icono: Icons.shopping_bag_outlined,
        descripcion: 'Total facturado hoy y del mes, pendientes de cobro',
        activo: false,
        activo: false,
        orden: 7,
      ),
      WidgetConfig(
        id: 'resumen_pedidos',
        nombre: 'Resumen Pedidos',
        descripcion: 'Pedidos y ventas del día',
        icono: Icons.receipt_long,
        orden: 8,
      ),
      // ── PRÓXIMAMENTE ──────────────────────────────────────────────────────
      WidgetConfig(
        id: 'ingresos_mes',
        nombre: 'Ingresos del Mes',
        descripcion: 'Gráfico de evolución de ingresos mensuales',
        icono: Icons.euro,
        activo: false,
        orden: 9,
      ),
      WidgetConfig(
        id: 'clientes_nuevos',
        nombre: 'Clientes Nuevos',
        descripcion: 'Últimos clientes registrados en el sistema',
        icono: Icons.people,
        activo: false,
        orden: 10,
      ),
      WidgetConfig(
        id: 'alertas_negocio',
        nombre: 'Alertas del Negocio',
        icono: Icons.notifications_active,
        activo: false,
        orden: 11,
      ),
    ];
  }

  /// IDs de widgets realmente implementados (no placeholder)
  static const Set<String> implementados = {
    'briefing_matutino',
    'alertas_fiscales',
    'proximos_dias',
    'reservas_hoy',
    'citas_resumen',
    'valoraciones_recientes',
    'kpis_rapidos',
    'resumen_facturacion',
    'resumen_pedidos',
  };
}









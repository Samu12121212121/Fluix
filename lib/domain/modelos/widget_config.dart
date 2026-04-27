import 'package:flutter/material.dart';

// ── PLANES DE SUSCRIPCIÓN ─────────────────────────────────────────────────────

enum PlanModulo {
  basico,
  fiscal,
  gestion,
  tienda,
  nominas,
}

extension PlanModuloExt on PlanModulo {
  String get nombre {
    switch (this) {
      case PlanModulo.basico:  return 'Plan Base';
      case PlanModulo.fiscal:  return 'Pack Fiscal AI';
      case PlanModulo.gestion: return 'Pack Gestión';
      case PlanModulo.tienda:  return 'Pack Tienda Online';
      case PlanModulo.nominas: return 'Add-on Nóminas';
    }
  }

  String get precio {
    switch (this) {
      case PlanModulo.basico:  return '310€/año';
      case PlanModulo.fiscal:  return '430€/año';
      case PlanModulo.gestion: return '370€/año';
      case PlanModulo.tienda:  return '490€/año';
      case PlanModulo.nominas: return '310€/año';
    }
  }

  Color get color {
    switch (this) {
      case PlanModulo.basico:  return const Color(0xFF1976D2);
      case PlanModulo.fiscal:  return const Color(0xFF388E3C);
      case PlanModulo.gestion: return const Color(0xFF7B1FA2);
      case PlanModulo.tienda:  return const Color(0xFFE65100);
      case PlanModulo.nominas: return const Color(0xFF00897B);
    }
  }

  IconData get icono {
    switch (this) {
      case PlanModulo.basico:  return Icons.star_outline;
      case PlanModulo.fiscal:  return Icons.account_balance;
      case PlanModulo.gestion: return Icons.workspace_premium;
      case PlanModulo.tienda:  return Icons.storefront;
      case PlanModulo.nominas: return Icons.payments;
    }
  }
}

// ── MODELO DE MÓDULO ──────────────────────────────────────────────────────────

class ModuloConfig {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  final bool activo;
  final PlanModulo plan;
  final bool incluidoEnPlan;
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

  ModuloConfig copyWith({bool? activo}) {
    return ModuloConfig(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      icono: icono,
      activo: activo ?? this.activo,
      plan: plan,
      incluidoEnPlan: incluidoEnPlan,
      precioAdicional: precioAdicional,
    );
  }

  factory ModuloConfig.safe(ModuloConfig? base) {
    if (base == null) {
      return const ModuloConfig(
        id: 'error',
        nombre: 'Módulo inválido',
        descripcion: 'Error de configuración',
        icono: Icons.error,
        activo: false,
        plan: PlanModulo.basico,
      );
    }
    return base;
  }
}

// ── CATÁLOGO DE MÓDULOS ───────────────────────────────────────────────────────

class ModulosDisponibles {
  static List<ModuloConfig> get todos => [

    // ── OCULTO ───────────────────────────────────────────────────────────────
    const ModuloConfig(
      id: 'propietario',
      nombre: 'Panel Propietario',
      descripcion: 'Solo Fluixtech',
      icono: Icons.admin_panel_settings,
      activo: false,
      plan: PlanModulo.basico,
    ),

    // ── PLAN BASE ─────────────────────────────────────────────────────────────
    const ModuloConfig(
      id: 'dashboard',
      nombre: 'Dashboard',
      descripcion: 'Resumen general del negocio con widgets personalizables',
      icono: Icons.dashboard,
      activo: true,
      plan: PlanModulo.basico,
    ),
    const ModuloConfig(
      id: 'valoraciones',
      nombre: 'Valoraciones',
      descripcion: 'Gestión de las reseñas y valoraciones de los clientes',
      icono: Icons.star,
      activo: false,
      plan: PlanModulo.basico,
    ),
    const ModuloConfig(
      id: 'estadisticas',
      nombre: 'Estadísticas',
      descripcion: 'Métricas y KPIs del negocio en tiempo real',
      icono: Icons.analytics,
      activo: false,
      plan: PlanModulo.basico,
    ),
    const ModuloConfig(
      id: 'reservas',
      nombre: 'Reservas',
      descripcion: 'Gestión de citas y reservas de clientes',
      icono: Icons.calendar_today,
      activo: false,
      plan: PlanModulo.basico,
    ),
    const ModuloConfig(
      id: 'web',
      nombre: 'Contenido Web',
      descripcion: 'Gestión del contenido dinámico de tu página web',
      icono: Icons.web,
      activo: false,
      plan: PlanModulo.basico,
    ),
    const ModuloConfig(
      id: 'clientes',
      nombre: 'Clientes',
      descripcion: 'Gestión de clientes, historial y CRM',
      icono: Icons.people,
      activo: false,
      plan: PlanModulo.basico,
    ),
    const ModuloConfig(
      id: 'empleados',
      nombre: 'Empleados',
      descripcion: 'Gestión de equipo y roles de acceso',
      icono: Icons.badge,
      activo: false,
      plan: PlanModulo.basico,
    ),
    const ModuloConfig(
      id: 'servicios',
      nombre: 'Servicios',
      descripcion: 'Catálogo de servicios, precios y categorías',
      icono: Icons.design_services,
      activo: false,
      plan: PlanModulo.basico,
    ),

    // ── PACK FISCAL AI ────────────────────────────────────────────────────────
    const ModuloConfig(
      id: 'fiscal',
      nombre: 'Fiscal AI',
      descripcion: 'Automatización fiscal con IA: genera informes trimestrales, '
          'calcula el IVA, detecta deducciones y prepara los modelos 303 y 130 '
          'listos para presentar',
      icono: Icons.account_balance,
      activo: false,
      plan: PlanModulo.fiscal,
    ),

    // ── PACK GESTIÓN ──────────────────────────────────────────────────────────
    const ModuloConfig(
      id: 'whatsapp',
      nombre: 'WhatsApp',
      descripcion: 'Comunicación con clientes vía WhatsApp Business',
      icono: Icons.chat,
      activo: false,
      plan: PlanModulo.gestion,
    ),
    const ModuloConfig(
      id: 'facturacion',
      nombre: 'Facturación',
      descripcion: 'Facturas completas con IVA, series y exportación PDF',
      icono: Icons.receipt_long,
      activo: false,
      plan: PlanModulo.gestion,
    ),
    const ModuloConfig(
      id: 'tpv',
      nombre: 'TPV',
      descripcion: 'Terminal punto de venta para cobros presenciales',
      icono: Icons.point_of_sale,
      activo: false,
      plan: PlanModulo.gestion,
    ),
    const ModuloConfig(
      id: 'nominas',
      nombre: 'Nóminas',
      descripcion: 'Gestión completa de nóminas y cotizaciones',
      icono: Icons.payments,
      activo: false,
      plan: PlanModulo.gestion,
    ),
    const ModuloConfig(
      id: 'vacaciones',
      nombre: 'Vacaciones',
      descripcion: 'Control de vacaciones, ausencias y calendario del equipo',
      icono: Icons.beach_access,
      activo: false,
      plan: PlanModulo.gestion,
    ),

    // ── PACK TIENDA ONLINE ────────────────────────────────────────────────────
    const ModuloConfig(
      id: 'pedidos',
      nombre: 'Pedidos',
      descripcion: 'Gestión de pedidos online y presenciales con stock',
      icono: Icons.shopping_bag_outlined,
      activo: false,
      plan: PlanModulo.tienda,
    ),

    // ── ADD-ONS ───────────────────────────────────────────────────────────────
    const ModuloConfig(
      id: 'tareas',
      nombre: 'Tareas',
      descripcion: 'Tareas de productividad por usuario',
      icono: Icons.task_alt,
      activo: false,
      plan: PlanModulo.basico,
      incluidoEnPlan: false,
      precioAdicional: 'Precio por usuario/mes',
    ),

  ]
      .whereType<ModuloConfig>()
      .map(ModuloConfig.safe)
      .toList();

  static const List<String> siempreActivos = ['dashboard'];
  static List<String> get activosPorDefecto => ['dashboard'];
}

// ── WIDGET CONFIG ─────────────────────────────────────────────────────────────

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
      icono: Icons.widgets,
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
      'icono': 'widgets',
      'activo': activo,
      'orden': orden,
      'configuracion': configuracion,
    };
  }

  WidgetConfig copyWith({bool? activo, int? orden}) {
    return WidgetConfig(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      icono: icono,
      activo: activo ?? this.activo,
      orden: orden ?? this.orden,
      configuracion: configuracion,
    );
  }

  static List<WidgetConfig> obtenerWidgetsDefault() {
    return [
      WidgetConfig(id: 'briefing_matutino',    nombre: 'Briefing Matutino',     descripcion: 'Resumen inteligente del día (visible de 6h a 12h)',           icono: Icons.wb_sunny,         activo: true,  orden: 1),
      WidgetConfig(id: 'proximos_dias',         nombre: 'Próximos 3 Días',       descripcion: 'Reservas y alertas de los próximos días',                     icono: Icons.event_note,       activo: true,  orden: 2),
      WidgetConfig(id: 'alertas_fiscales',      nombre: 'Alertas Fiscales',      descripcion: 'Alertas de obligaciones fiscales próximas',                   icono: Icons.account_balance,  activo: true,  orden: 3),
      WidgetConfig(id: 'reservas_hoy',          nombre: 'Reservas de Hoy',       descripcion: 'Reservas y citas del día en curso',                           icono: Icons.calendar_today,   activo: true,  orden: 4),
      WidgetConfig(id: 'valoraciones_recientes',nombre: 'Valoraciones Recientes',descripcion: 'Últimas reseñas y puntuaciones de clientes',                  icono: Icons.star,             activo: true,  orden: 5),
      WidgetConfig(id: 'kpis_rapidos',          nombre: 'KPIs Rápidos',          descripcion: 'Reservas de hoy, ingresos de la semana y rating promedio',    icono: Icons.analytics,        activo: true,  orden: 6),
      WidgetConfig(id: 'resumen_facturacion',   nombre: 'Resumen Facturación',   descripcion: 'Total facturado hoy y del mes, pendientes de cobro',          icono: Icons.receipt_long,     activo: true,  orden: 7),
      WidgetConfig(id: 'resumen_pedidos',       nombre: 'Resumen Pedidos',       descripcion: 'Pedidos y ventas del día',                                    icono: Icons.shopping_bag,     activo: true,  orden: 8),
      WidgetConfig(id: 'ingresos_mes',          nombre: 'Ingresos del Mes',      descripcion: 'Gráfico de evolución de ingresos mensuales',                  icono: Icons.trending_up,      activo: false, orden: 10),
      WidgetConfig(id: 'clientes_nuevos',       nombre: 'Clientes Nuevos',       descripcion: 'Últimos clientes registrados en el sistema',                  icono: Icons.people,           activo: false, orden: 11),
      WidgetConfig(id: 'alertas_negocio',       nombre: 'Alertas del Negocio',   descripcion: 'Sugerencias y alertas automáticas del negocio',               icono: Icons.notifications,    activo: false, orden: 12),
      WidgetConfig(id: 'kpis',                  nombre: 'KPIs',                  descripcion: 'Métricas clave del negocio',                                  icono: Icons.bar_chart,        activo: true,  orden: 13),
    ];
  }

  // ── WIDGETS IMPLEMENTADOS ──────────────────────────────────────────────────
  //
  // ✅ LIBRES — sin restricción de pack:
  //   briefing_matutino      → Resumen matutino inteligente (visible 6h-12h)
  //   proximos_dias          → Reservas y alertas próximos 3 días
  //   reservas_hoy           → Reservas y citas del día en curso (unificado)
  //   alertas_fiscales       → Avisos AEAT / plazos tributarios
  //   valoraciones_recientes → Últimas reseñas de clientes
  //   kpis_rapidos           → Reservas hoy, ingresos semana, rating
  //
  // 🔒 REQUIEREN PACK (gestionado en configuracion_widgets_screen.dart):
  //   resumen_facturacion    → Pack Gestión
  //   resumen_pedidos        → Pack Tienda Online
  //
  // 🚧 PRÓXIMAMENTE (NO añadir aquí hasta estar implementados):
  //   ingresos_mes, clientes_nuevos, alertas_negocio
  //
  // Última actualización: Abril 2026
  static const Set<String> implementados = {
    'briefing_matutino',
    'proximos_dias',
    'alertas_fiscales',
    'reservas_hoy',
    'valoraciones_recientes',
    'kpis_rapidos',
    'resumen_facturacion',
    'resumen_pedidos',
    'kpis',
  };

// 🚧 No incluidos (próximamente): 'ingresos_mes', 'clientes_nuevos', 'alertas_negocio'
}
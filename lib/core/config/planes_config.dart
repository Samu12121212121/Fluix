// ═════════════════════════════════════════════════════════════════════════════
// DEFINICIÓN CANÓNICA DE PLANES — Fuente única de verdad (Flutter)
// ═════════════════════════════════════════════════════════════════════════════
//
// Esta clase contiene la definición autoritativa de planes, packs y add-ons.
// Debe mantenerse en sincronía con la versión de Cloud Functions
// (functions/src/planesConfigV2.ts).
//
// Los módulos activos se calculan dinámicamente:
//   modulosActivos = base + packs + addons
//
// NO se guardan como toggles individuales independientes.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Plan Base
// ─────────────────────────────────────────────────────────────────────────────

class PlanConfig {
  final String id;
  final String nombre;
  final double precioAnual;
  final List<String> modulosIncluidos;
  final String descripcion;
  final Color color;
  final IconData icono;

  const PlanConfig({
    required this.id,
    required this.nombre,
    required this.precioAnual,
    required this.modulosIncluidos,
    required this.descripcion,
    required this.color,
    required this.icono,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Pack (acumulable sobre el plan base)
// ─────────────────────────────────────────────────────────────────────────────

class PackConfig {
  final String id;
  final String nombre;
  final double precioAnual;
  final List<String> modulosAdicionales;
  final String descripcion;
  final Color color;
  final IconData icono;

  const PackConfig({
    required this.id,
    required this.nombre,
    required this.precioAnual,
    required this.modulosAdicionales,
    required this.descripcion,
    required this.color,
    required this.icono,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Add-on (independiente, se suma al precio)
// ─────────────────────────────────────────────────────────────────────────────

class AddonConfig {
  final String id;
  final String nombre;
  final double? precioAnual; // null = "precio por definir"
  final List<String> modulosAdicionales;
  final String descripcion;
  final Color color;
  final IconData icono;
  /// Si true, el precio depende de la cantidad (ej: nóminas por empleado)
  final bool precioVariable;
  /// Etiqueta de precio variable (ej: "€/empleado/mes")
  final String? etiquetaPrecioVariable;

  const AddonConfig({
    required this.id,
    required this.nombre,
    this.precioAnual,
    required this.modulosAdicionales,
    required this.descripcion,
    required this.color,
    required this.icono,
    this.precioVariable = false,
    this.etiquetaPrecioVariable,
  });

  String get precioLabel {
    if (precioAnual != null) return '+${precioAnual!.toStringAsFixed(0)}€/año';
    if (precioVariable && etiquetaPrecioVariable != null) {
      return etiquetaPrecioVariable!;
    }
    return 'Precio por definir';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Bundle (descuento por contratar packs combinados)
// ─────────────────────────────────────────────────────────────────────────────

class BundleConfig {
  final List<String> packs;
  final double descuento;
  final String nombre;

  const BundleConfig({
    required this.packs,
    required this.descuento,
    required this.nombre,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// CATÁLOGO DE PLANES, PACKS Y ADDONS
// ═════════════════════════════════════════════════════════════════════════════

class PlanesConfig {
  PlanesConfig._(); // No instanciable

  // ── PLAN BASE ──────────────────────────────────────────────────────────────

  static const planBase = PlanConfig(
    id: 'basico',
    nombre: 'Plan Base',
    precioAnual: 310,
    modulosIncluidos: [
      'dashboard',
      'reservas',
      'clientes',
      'servicios',
      'empleados',
      'valoraciones',
      'estadisticas',
      'contenido_web', // alias 'web'
    ],
    descripcion: 'Reservas, clientes, servicios y estadísticas.',
    color: Color(0xFF1976D2),
    icono: Icons.star_outline,
  );

  // ── PACKS ──────────────────────────────────────────────────────────────────

  static const packGestion = PackConfig(
    id: 'gestion',
    nombre: 'Pack Gestión',
    precioAnual: 370,
    modulosAdicionales: ['facturacion', 'vacaciones', 'tpv'],
    descripcion: 'Facturación completa, gestión de vacaciones y TPV.',
    color: Color(0xFF7B1FA2),
    icono: Icons.workspace_premium,
  );

  static const packFiscal = PackConfig(
    id: 'fiscal',
    nombre: 'Pack Fiscal AI',
    precioAnual: 430,
    modulosAdicionales: ['fiscal', 'contabilidad', 'verifactu'],
    descripcion: 'IA: escaneo de facturas, modelos AE automáticos, presentación directa en sede.',
    color: Color(0xFF0288D1),
    icono: Icons.account_balance,
  );

  static const packTienda = PackConfig(
    id: 'tienda',
    nombre: 'Pack Tienda Online',
    precioAnual: 490,
    modulosAdicionales: ['pedidos'],
    descripcion: 'Catálogo de productos y pedidos online.',
    color: Color(0xFFE65100),
    icono: Icons.storefront,
  );

  static const List<PackConfig> todosPacks = [packGestion, packFiscal, packTienda];

  // ── BUNDLES ────────────────────────────────────────────────────────────────
  // gestion(370) + fiscal(430) = 800 por separado → bundle: 700€ (ahorro 100€)

  static const List<BundleConfig> bundles = [
    BundleConfig(
      packs: ['gestion', 'fiscal'],
      descuento: 100,
      nombre: 'Bundle Gestión + Fiscal AI',
    ),
  ];

  // ── ADD-ONS ────────────────────────────────────────────────────────────────

  static const addonWhatsapp = AddonConfig(
    id: 'whatsapp',
    nombre: 'WhatsApp',
    precioAnual: 50,
    modulosAdicionales: ['whatsapp'],
    descripcion: 'Gestión de pedidos y comunicaciones por WhatsApp.',
    color: Color(0xFF25D366),
    icono: Icons.chat_bubble_outline,
  );

  static const addonTareas = AddonConfig(
    id: 'tareas',
    nombre: 'Tareas',
    precioAnual: null, // precio por definir
    modulosAdicionales: ['tareas'],
    descripcion: 'Gestión de tareas y productividad por usuario.',
    color: Color(0xFF00ACC1),
    icono: Icons.task_alt,
    precioVariable: true,
    etiquetaPrecioVariable: 'Precio por definir',
  );

  static const addonNominas = AddonConfig(
    id: 'nominas',
    nombre: 'Nóminas',
    precioAnual: 310,
    modulosAdicionales: ['nominas'],
    descripcion: 'Cálculo automático de nóminas, IRPF y SS.',
    color: Color(0xFFFF7043),
    icono: Icons.payments,
    precioVariable: false,
    etiquetaPrecioVariable: null,
  );

  static const List<AddonConfig> todosAddons = [
    addonWhatsapp,
    addonTareas,
    addonNominas,
  ];

  // ═════════════════════════════════════════════════════════════════════════════
  // LÓGICA DE CÁLCULO DE MÓDULOS ACTIVOS
  // ═════════════════════════════════════════════════════════════════════════════

  /// Calcula la lista de módulos activos basándose en packs y addons contratados.
  ///
  /// [packsActivos] — IDs de packs contratados (ej: ['gestion', 'tienda'])
  /// [addonsActivos] — IDs de addons contratados (ej: ['whatsapp'])
  ///
  /// Retorna una lista deduplicada de módulo IDs.
  static List<String> getModulosActivos({
    List<String> packsActivos = const [],
    List<String> addonsActivos = const [],
  }) {
    final modulos = <String>{};

    // 1. Siempre incluir módulos del plan base
    modulos.addAll(planBase.modulosIncluidos);

    // 2. Añadir módulos de packs contratados
    for (final packId in packsActivos) {
      final pack = _buscarPack(packId);
      if (pack != null) {
        modulos.addAll(pack.modulosAdicionales);
      }
    }

    // 3. Añadir módulos de addons contratados
    for (final addonId in addonsActivos) {
      final addon = _buscarAddon(addonId);
      if (addon != null) {
        modulos.addAll(addon.modulosAdicionales);
      }
    }

    return modulos.toList();
  }

  /// Comprueba si un módulo específico está incluido en la combinación
  /// de plan base + packs + addons.
  static bool moduloDisponible({
    required String moduloId,
    List<String> packsActivos = const [],
    List<String> addonsActivos = const [],
  }) {
    // Alias: 'web' y 'contenido_web' son el mismo módulo
    final id = _normalizarModuloId(moduloId);
    final activos = getModulosActivos(
      packsActivos: packsActivos,
      addonsActivos: addonsActivos,
    ).map(_normalizarModuloId).toSet();
    return activos.contains(id);
  }

  /// Calcula el precio total anual basado en los packs y addons seleccionados.
  ///
  /// [empleadosNomina] — número de empleados con nómina (para precio variable).
  static double calcularPrecioTotal({
    List<String> packsActivos = const [],
    List<String> addonsActivos = const [],
    int empleadosNomina = 0,
  }) {
    double total = planBase.precioAnual;

    for (final packId in packsActivos) {
      final pack = _buscarPack(packId);
      if (pack != null) total += pack.precioAnual;
    }

    for (final addonId in addonsActivos) {
      final addon = _buscarAddon(addonId);
      if (addon != null && addon.precioAnual != null) {
        total += addon.precioAnual!;
      }
    }

    // Aplicar descuentos de bundle automáticamente
    total -= calcularDescuentoBundle(packsActivos);

    return total;
  }

  /// Devuelve el descuento total aplicado por bundles activos.
  /// Útil para mostrar en UI "Ahorras Xen".
  static double calcularDescuentoBundle(List<String> packsActivos) {
    double descuento = 0;
    for (final bundle in bundles) {
      if (bundle.packs.every(packsActivos.contains)) {
        descuento += bundle.descuento;
      }
    }
    return descuento;
  }

  // ── HELPERS DE BÚSQUEDA ─────────────────────────────────────────────────────

  /// Busca qué pack incluye un módulo determinado. Retorna null si es del base.
  static PackConfig? packQueIncluyeModulo(String moduloId) {
    final id = _normalizarModuloId(moduloId);
    for (final pack in todosPacks) {
      if (pack.modulosAdicionales.map(_normalizarModuloId).contains(id)) {
        return pack;
      }
    }
    return null;
  }

  /// Busca qué addon incluye un módulo determinado. Retorna null si no es addon.
  static AddonConfig? addonQueIncluyeModulo(String moduloId) {
    final id = _normalizarModuloId(moduloId);
    for (final addon in todosAddons) {
      if (addon.modulosAdicionales.map(_normalizarModuloId).contains(id)) {
        return addon;
      }
    }
    return null;
  }

  /// Dada un módulo, retorna el nombre del pack/addon que lo incluye (para UI).
  static String? nombreProductoQueIncluye(String moduloId) {
    final pack = packQueIncluyeModulo(moduloId);
    if (pack != null) return pack.nombre;
    final addon = addonQueIncluyeModulo(moduloId);
    if (addon != null) return addon.nombre;
    return null; // Es del plan base
  }

  // ── PRIVADOS ───────────────────────────────────────────────────────────────

  static PackConfig? _buscarPack(String id) {
    try {
      return todosPacks.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static AddonConfig? _buscarAddon(String id) {
    try {
      return todosAddons.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Normaliza IDs de módulo para que 'web' y 'contenido_web' se traten igual.
  static String _normalizarModuloId(String id) {
    if (id == 'web') return 'contenido_web';
    return id;
  }
}


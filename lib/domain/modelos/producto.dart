import 'package:cloud_firestore/cloud_firestore.dart';

DateTime parseTimestamp(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

// ── VARIANTE DE PRODUCTO ──────────────────────────────────────────────────────

class VarianteProducto {
  final String id;
  final String nombre;           // ej: "Grande", "Cabello corto", "1kg"
  final String tipo;             // ej: "tamaño", "sabor", "color"
  final double? precioDiferencia; // diferencia sobre precio base (legacy/compat)
  final double? precio;          // precio propio de la variante
  final int? duracionMinutos;    // duración propia si es servicio
  final String? sku;             // SKU propio (opcional)
  final bool disponible;         // toggle activar/desactivar sin eliminar
  final int? stockExtra;

  const VarianteProducto({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.precioDiferencia,
    this.precio,
    this.duracionMinutos,
    this.sku,
    this.disponible = true,
    this.stockExtra,
  });

  /// Devuelve el precio efectivo: si tiene precio propio lo usa,
  /// si no, suma precioDiferencia al precio base.
  double precioEfectivo(double precioBase) =>
      precio ?? (precioBase + (precioDiferencia ?? 0));

  factory VarianteProducto.fromMap(Map<String, dynamic> d) => VarianteProducto(
    id: d['id'] ?? '',
    nombre: d['nombre'] ?? '',
    tipo: d['tipo'] ?? '',
    precioDiferencia: (d['precio_diferencia'] as num?)?.toDouble(),
    precio: (d['precio'] as num?)?.toDouble(),
    duracionMinutos: (d['duracion_minutos'] as num?)?.toInt(),
    sku: d['sku'] as String?,
    disponible: d['disponible'] as bool? ?? true,
    stockExtra: d['stock_extra'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo,
    'precio_diferencia': precioDiferencia,
    'precio': precio,
    'duracion_minutos': duracionMinutos,
    'sku': sku,
    'disponible': disponible,
    'stock_extra': stockExtra,
  };

  VarianteProducto copyWith({
    String? nombre,
    String? tipo,
    double? precioDiferencia,
    double? precio,
    int? duracionMinutos,
    String? sku,
    bool? disponible,
    int? stockExtra,
  }) => VarianteProducto(
    id: id,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    precioDiferencia: precioDiferencia ?? this.precioDiferencia,
    precio: precio ?? this.precio,
    duracionMinutos: duracionMinutos ?? this.duracionMinutos,
    sku: sku ?? this.sku,
    disponible: disponible ?? this.disponible,
    stockExtra: stockExtra ?? this.stockExtra,
  );
}

// ── PRODUCTO ──────────────────────────────────────────────────────────────────

class Producto {
  final String id;
  final String empresaId;
  final String nombre;
  final String? descripcion;
  final String categoria;
  final double precio;
  final String? imagenUrl;
  final String? thumbnailUrl;    // miniatura 400x400 generada por Cloud Function
  final int? stock;
  final bool activo;
  final bool destacado;
  final bool tieneVariantes;     // toggle: true → oculta precio base, muestra variantes
  final int? duracionMinutos;    // duración del servicio (null si es producto físico)
  final double ivaPorcentaje;    // % IVA (21, 10, 4, 0)
  final String? sku;
  final String? codigoBarras;
  final List<VarianteProducto> variantes;
  final List<String> etiquetas;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  const Producto({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.descripcion,
    required this.categoria,
    required this.precio,
    this.imagenUrl,
    this.thumbnailUrl,
    this.stock,
    this.activo = true,
    this.destacado = false,
    this.tieneVariantes = false,
    this.duracionMinutos,
    this.ivaPorcentaje = 21,
    this.sku,
    this.codigoBarras,
    required this.variantes,
    required this.etiquetas,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  /// Variantes que están disponibles (no desactivadas).
  List<VarianteProducto> get variantesDisponibles =>
      variantes.where((v) => v.disponible).toList();

  /// Precio mínimo entre variantes disponibles, o el precio base.
  double get precioDesde {
    if (!tieneVariantes || variantesDisponibles.isEmpty) return precio;
    return variantesDisponibles
        .map((v) => v.precioEfectivo(precio))
        .reduce((a, b) => a < b ? a : b);
  }

  /// Precio máximo entre variantes disponibles.
  double get precioHasta {
    if (!tieneVariantes || variantesDisponibles.isEmpty) return precio;
    return variantesDisponibles
        .map((v) => v.precioEfectivo(precio))
        .reduce((a, b) => a > b ? a : b);
  }

  /// Texto de precio para mostrar en el catálogo.
  String get textoRangoPrecio {
    if (!tieneVariantes || variantesDisponibles.isEmpty) {
      return '${precio.toStringAsFixed(2)} €';
    }
    final min = precioDesde;
    final max = precioHasta;
    if (min == max) return '${min.toStringAsFixed(2)} €';
    return 'desde ${min.toStringAsFixed(2)} €';
  }

  /// true si es un servicio (tiene duración configurada).
  bool get esServicio => duracionMinutos != null && duracionMinutos! > 0;

  factory Producto.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return Producto(
        id: doc.id, empresaId: '', nombre: 'Sin nombre', categoria: 'General',
        precio: 0, variantes: [], etiquetas: [], fechaCreacion: DateTime.now(),
      );
    }
    final d = raw as Map<String, dynamic>;
    return Producto(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      nombre: d['nombre'] ?? '',
      descripcion: d['descripcion'],
      categoria: d['categoria'] ?? 'General',
      precio: (d['precio'] as num?)?.toDouble() ?? 0,
      imagenUrl: d['imagen_url'],
      thumbnailUrl: d['thumbnail_url'],
      stock: d['stock'],
      activo: d['activo'] ?? true,
      destacado: d['destacado'] ?? false,
      tieneVariantes: d['tiene_variantes'] ?? false,
      duracionMinutos: (d['duracion_minutos'] as num?)?.toInt(),
      ivaPorcentaje: (d['iva_porcentaje'] as num?)?.toDouble() ?? 21,
      sku: d['sku'],
      codigoBarras: d['codigo_barras'],
      variantes: (d['variantes'] as List<dynamic>? ?? [])
          .map((v) => VarianteProducto.fromMap(v as Map<String, dynamic>))
          .toList(),
      etiquetas: List<String>.from(d['etiquetas'] ?? []),
      fechaCreacion: parseTimestamp(d['fecha_creacion']),
      fechaActualizacion: d['fecha_actualizacion'] != null
          ? parseTimestamp(d['fecha_actualizacion'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'nombre': nombre,
    'descripcion': descripcion,
    'categoria': categoria,
    'precio': precio,
    'imagen_url': imagenUrl,
    'thumbnail_url': thumbnailUrl,
    'stock': stock,
    'activo': activo,
    'destacado': destacado,
    'tiene_variantes': tieneVariantes,
    'duracion_minutos': duracionMinutos,
    'iva_porcentaje': ivaPorcentaje,
    'sku': sku,
    'codigo_barras': codigoBarras,
    'variantes': variantes.map((v) => v.toMap()).toList(),
    'etiquetas': etiquetas,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'fecha_actualizacion': fechaActualizacion != null
        ? Timestamp.fromDate(fechaActualizacion!)
        : null,
  };

  Producto copyWith({
    String? nombre,
    String? descripcion,
    String? categoria,
    double? precio,
    String? imagenUrl,
    String? thumbnailUrl,
    int? stock,
    bool? activo,
    bool? destacado,
    bool? tieneVariantes,
    int? duracionMinutos,
    double? ivaPorcentaje,
    String? sku,
    String? codigoBarras,
    List<VarianteProducto>? variantes,
    List<String>? etiquetas,
  }) => Producto(
    id: id,
    empresaId: empresaId,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    categoria: categoria ?? this.categoria,
    precio: precio ?? this.precio,
    imagenUrl: imagenUrl ?? this.imagenUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    stock: stock ?? this.stock,
    activo: activo ?? this.activo,
    destacado: destacado ?? this.destacado,
    tieneVariantes: tieneVariantes ?? this.tieneVariantes,
    duracionMinutos: duracionMinutos ?? this.duracionMinutos,
    ivaPorcentaje: ivaPorcentaje ?? this.ivaPorcentaje,
    sku: sku ?? this.sku,
    codigoBarras: codigoBarras ?? this.codigoBarras,
    variantes: variantes ?? this.variantes,
    etiquetas: etiquetas ?? this.etiquetas,
    fechaCreacion: fechaCreacion,
    fechaActualizacion: this.fechaActualizacion,
  );
}

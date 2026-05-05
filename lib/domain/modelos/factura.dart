import 'package:cloud_firestore/cloud_firestore.dart';

// ── ENUMS ─────────────────────────────────────────────────────────────────────

enum EstadoFactura { pendiente, pagada, anulada, vencida, rectificada }

enum MetodoPagoFactura { tarjeta, paypal, bizum, efectivo, transferencia }

enum TipoFactura { pedido, venta_directa, servicio, rectificativa, proforma }

enum SerieFactura { fac, rect, pro, tpv }

/// Art. 15 RD 1619/2012 — Motivos de rectificación normalizados
enum MotivoRectificacion {
  errorDatosDestinatario,   // Error en NIF, dirección, razón social
  devolucionTotal,          // Devolución completa de la operación
  devolucionParcial,        // Devolución parcial de productos/servicios
  descuentoPosterior,       // Descuento o bonificación posterior
  errorImportes,            // Error en importes o tipos impositivos
  modificacionBaseArt80,    // Art. 80 LIVA: créditos incobrables, concursal…
  otro,                     // Otros motivos justificados
}

/// Método de rectificación (Art. 15.1 RD 1619/2012)
enum MetodoRectificacion {
  sustitucion,  // Factura íntegra con los datos correctos
  diferencias,  // Solo refleja la diferencia (positiva o negativa)
}

// ── EXTENSIONES ───────────────────────────────────────────────────────────────

extension EstadoFacturaExt on EstadoFactura {
  String get etiqueta {
    switch (this) {
      case EstadoFactura.pendiente: return 'Pendiente';
      case EstadoFactura.pagada: return 'Pagada';
      case EstadoFactura.anulada: return 'Anulada';
      case EstadoFactura.vencida: return 'Vencida';
      case EstadoFactura.rectificada: return 'Rectificada';
    }
  }
}

extension MetodoPagoFacturaExt on MetodoPagoFactura {
  String get etiqueta {
    switch (this) {
      case MetodoPagoFactura.tarjeta: return 'Tarjeta';
      case MetodoPagoFactura.paypal: return 'PayPal';
      case MetodoPagoFactura.bizum: return 'Bizum';
      case MetodoPagoFactura.efectivo: return 'Efectivo';
      case MetodoPagoFactura.transferencia: return 'Transferencia';
    }
  }
}

extension TipoFacturaExt on TipoFactura {
  String get etiqueta {
    switch (this) {
      case TipoFactura.pedido: return 'Pedido';
      case TipoFactura.venta_directa: return 'Venta directa';
      case TipoFactura.servicio: return 'Servicio';
      case TipoFactura.rectificativa: return 'Rectificativa';
      case TipoFactura.proforma: return 'Proforma';
    }
  }

  SerieFactura get serie {
    switch (this) {
      case TipoFactura.rectificativa: return SerieFactura.rect;
      case TipoFactura.proforma: return SerieFactura.pro;
      default: return SerieFactura.fac;
    }
  }
}

extension SerieFacturaExt on SerieFactura {
  String get prefijo {
    switch (this) {
      case SerieFactura.fac:  return 'F';
      case SerieFactura.rect: return 'R';
      case SerieFactura.pro:  return 'P';
      case SerieFactura.tpv:  return 'TPV';
    }
  }
}

extension MotivoRectificacionExt on MotivoRectificacion {
  String get etiqueta {
    switch (this) {
      case MotivoRectificacion.errorDatosDestinatario:
        return 'Error en datos del destinatario (NIF, dirección…)';
      case MotivoRectificacion.devolucionTotal:
        return 'Devolución total';
      case MotivoRectificacion.devolucionParcial:
        return 'Devolución parcial';
      case MotivoRectificacion.descuentoPosterior:
        return 'Descuento o bonificación posterior';
      case MotivoRectificacion.errorImportes:
        return 'Error en importes o tipos impositivos';
      case MotivoRectificacion.modificacionBaseArt80:
        return 'Modificación base imponible (Art. 80 LIVA)';
      case MotivoRectificacion.otro:
        return 'Otro motivo';
    }
  }

  /// Código para Verifactu / AEAT (R1-R5)
  String get codigoAEAT {
    switch (this) {
      case MotivoRectificacion.errorDatosDestinatario: return 'R1';
      case MotivoRectificacion.devolucionTotal: return 'R2';
      case MotivoRectificacion.devolucionParcial: return 'R2';
      case MotivoRectificacion.descuentoPosterior: return 'R3';
      case MotivoRectificacion.errorImportes: return 'R4';
      case MotivoRectificacion.modificacionBaseArt80: return 'R5';
      case MotivoRectificacion.otro: return 'R1';
    }
  }
}

extension MetodoRectificacionExt on MetodoRectificacion {
  String get etiqueta {
    switch (this) {
      case MetodoRectificacion.sustitucion:
        return 'Por sustitución (datos correctos completos)';
      case MetodoRectificacion.diferencias:
        return 'Por diferencias (solo el importe a corregir)';
    }
  }

  /// Código AEAT: S = sustitución, I = diferencias
  String get codigoAEAT {
    switch (this) {
      case MetodoRectificacion.sustitucion: return 'S';
      case MetodoRectificacion.diferencias: return 'I';
    }
  }
}

// ── TIPO IVA ──────────────────────────────────────────────────────────────────
// Art. 90-91 LIVA: tipos impositivos vigentes en España
// Recargo equivalencia: Art. 154 LIVA (comerciantes minoristas en RE)

/// Tipos de IVA aplicables en España con su correspondiente
/// recargo de equivalencia (RD 1624/1992).
enum TipoIVA {
  /// 4% — Libros, pan, leche, medicamentos, prótesis
  superreducido,

  /// 10% — Hostelería, transporte, alimentos no esenciales, vivienda nueva
  reducido,

  /// 21% — Tipo general para el resto de bienes y servicios
  general,

  /// 0% — Operaciones exentas (educación, sanidad, seguros, Art. 20 LIVA)
  exento,

  /// 0% — Operaciones intracomunitarias (cliente con NIF-IVA UE)
  /// Base imponible sujeta pero exenta — mención obligatoria en factura
  intracomunitario,
}

extension TipoIVAExt on TipoIVA {
  /// Porcentaje IVA aplicable
  double get porcentaje {
    switch (this) {
      case TipoIVA.superreducido:     return 4.0;
      case TipoIVA.reducido:          return 10.0;
      case TipoIVA.general:           return 21.0;
      case TipoIVA.exento:            return 0.0;
      case TipoIVA.intracomunitario:  return 0.0;
    }
  }

  /// Recargo de equivalencia correspondiente (Art. 154 LIVA)
  double get recargoEquivalencia {
    switch (this) {
      case TipoIVA.superreducido:     return 0.5;
      case TipoIVA.reducido:          return 1.4;
      case TipoIVA.general:           return 5.2;
      case TipoIVA.exento:            return 0.0;
      case TipoIVA.intracomunitario:  return 0.0;
    }
  }

  String get etiqueta {
    switch (this) {
      case TipoIVA.superreducido:     return 'Superreducido 4%';
      case TipoIVA.reducido:          return 'Reducido 10%';
      case TipoIVA.general:           return 'General 21%';
      case TipoIVA.exento:            return 'Exento 0%';
      case TipoIVA.intracomunitario:  return 'Intracomunitario 0%';
    }
  }

  /// Descripción corta para facturas (p.ej. "IVA 21%")
  String get etiquetaCorta {
    switch (this) {
      case TipoIVA.superreducido:     return 'IVA 4%';
      case TipoIVA.reducido:          return 'IVA 10%';
      case TipoIVA.general:           return 'IVA 21%';
      case TipoIVA.exento:            return 'Exento';
      case TipoIVA.intracomunitario:  return 'Intracom. 0%';
    }
  }

  /// Categorías de ejemplo para la interfaz
  String get ejemplos {
    switch (this) {
      case TipoIVA.superreducido:
        return 'Pan, leche, huevos, libros, medicamentos, prótesis';
      case TipoIVA.reducido:
        return 'Hostelería, transporte, alimentación no básica, gimnasios';
      case TipoIVA.general:
        return 'Ropa, electrónica, servicios generales, vehículos';
      case TipoIVA.exento:
        return 'Educación, sanidad, seguros, servicios financieros';
      case TipoIVA.intracomunitario:
        return 'Ventas a empresas de la UE con NIF-IVA comunitario';
    }
  }

  /// Mención legal obligatoria en factura para IVA 0%
  String? get mencionFactura {
    switch (this) {
      case TipoIVA.exento:
        return 'Operación exenta de IVA (Art. 20 LIVA)';
      case TipoIVA.intracomunitario:
        return 'Entrega intracomunitaria exenta de IVA (Art. 25 LIVA)';
      default:
        return null;
    }
  }

  /// Obtiene el TipoIVA a partir de un porcentaje numérico
  static TipoIVA fromPorcentaje(double pct) {
    if (pct == 4.0)  return TipoIVA.superreducido;
    if (pct == 10.0) return TipoIVA.reducido;
    if (pct == 21.0) return TipoIVA.general;
    return TipoIVA.exento;
  }
}

// ── DATOS FISCALES DEL CLIENTE ────────────────────────────────────────────────

class DatosFiscales {
  final String? nif;
  final String? nifIvaComunitario;
  final bool esIntracomunitario;
  final String? razonSocial;
  final String? direccion;
  final String? codigoPostal;
  final String? ciudad;
  final String? pais;

  const DatosFiscales({
    this.nif,
    this.nifIvaComunitario,
    this.esIntracomunitario = false,
    this.razonSocial,
    this.direccion,
    this.codigoPostal,
    this.ciudad,
    this.pais,
  });

  factory DatosFiscales.fromMap(Map<String, dynamic> d) => DatosFiscales(
    nif: d['nif'],
    nifIvaComunitario: d['nif_iva_comunitario'],
    esIntracomunitario: d['es_intracomunitario'] ?? false,
    razonSocial: d['razon_social'],
    direccion: d['direccion'],
    codigoPostal: d['codigo_postal'],
    ciudad: d['ciudad'],
    pais: d['pais'] ?? 'España',
  );

  Map<String, dynamic> toMap() => {
    'nif': nif,
    'nif_iva_comunitario': nifIvaComunitario,
    'es_intracomunitario': esIntracomunitario,
    'razon_social': razonSocial,
    'direccion': direccion,
    'codigo_postal': codigoPostal,
    'ciudad': ciudad,
    'pais': pais,
  };

  bool get tieneDatos => nif != null || nifIvaComunitario != null || razonSocial != null;
}

// ── LÍNEA DE FACTURA ──────────────────────────────────────────────────────────

class LineaFactura {
  final String descripcion;
  final double precioUnitario;
  final int cantidad;
  final double porcentajeIva;
  final String? referencia;
  final double descuento;            // porcentaje de descuento por línea (0-100)
  final double recargoEquivalencia;  // porcentaje recargo (0, 1.4, 5.2)

  const LineaFactura({
    required this.descripcion,
    required this.precioUnitario,
    required this.cantidad,
    this.porcentajeIva = 21.0,
    this.referencia,
    this.descuento = 0,
    this.recargoEquivalencia = 0,
  });

  double get subtotalBruto => precioUnitario * cantidad;
  double get importeDescuento => subtotalBruto * (descuento / 100);
  double get subtotalSinIva => subtotalBruto - importeDescuento;
  double get importeIva => subtotalSinIva * (porcentajeIva / 100);
  double get importeRecargo => subtotalSinIva * (recargoEquivalencia / 100);
  double get subtotalConIva => subtotalSinIva + importeIva + importeRecargo;

  factory LineaFactura.fromMap(Map<String, dynamic> d) => LineaFactura(
    descripcion: d['descripcion'] ?? '',
    precioUnitario: (d['precio_unitario'] as num?)?.toDouble() ?? 0,
    cantidad: (d['cantidad'] as num?)?.toInt() ?? 1,
    porcentajeIva: (d['porcentaje_iva'] as num?)?.toDouble() ?? 21.0,
    referencia: d['referencia'],
    descuento: (d['descuento'] as num?)?.toDouble() ?? 0,
    recargoEquivalencia: (d['recargo_equivalencia'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'descripcion': descripcion,
    'precio_unitario': precioUnitario,
    'cantidad': cantidad,
    'porcentaje_iva': porcentajeIva,
    'referencia': referencia,
    if (descuento > 0) 'descuento': descuento,
    if (recargoEquivalencia > 0) 'recargo_equivalencia': recargoEquivalencia,
  };
}

// ── HISTORIAL DE FACTURA ──────────────────────────────────────────────────────

class EntradaHistorialFactura {
  final String usuarioId;
  final String usuarioNombre;
  final String accion;
  final String descripcion;
  final DateTime fecha;

  const EntradaHistorialFactura({
    required this.usuarioId,
    required this.usuarioNombre,
    required this.accion,
    required this.descripcion,
    required this.fecha,
  });

  factory EntradaHistorialFactura.fromMap(Map<String, dynamic> d) =>
      EntradaHistorialFactura(
        usuarioId: d['usuario_id'] ?? '',
        usuarioNombre: d['usuario_nombre'] ?? '',
        accion: d['accion'] ?? '',
        descripcion: d['descripcion'] ?? '',
        fecha: _parseTs(d['fecha']),
      );

  Map<String, dynamic> toMap() => {
    'usuario_id': usuarioId,
    'usuario_nombre': usuarioNombre,
    'accion': accion,
    'descripcion': descripcion,
    'fecha': Timestamp.fromDate(fecha),
  };
}

// ── FACTURA ───────────────────────────────────────────────────────────────────

class Factura {
  final String id;
  final String empresaId;
  final String numeroFactura;
  final SerieFactura serie;
  final TipoFactura tipo;
  final EstadoFactura estado;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteCorreo;
  final DatosFiscales? datosFiscales;
  final List<LineaFactura> lineas;
  final double subtotal;
  final double totalIva;
  final double total;
  // Campos fiscales avanzados
  final double descuentoGlobal;           // porcentaje descuento global (0-100)
  final double importeDescuentoGlobal;
  final double porcentajeIrpf;            // retención IRPF para freelancers (0/7/15/19%)
  final double retencionIrpf;             // importe IRPF calculado
  final double totalRecargoEquivalencia;  // suma de recargos de todas las líneas
  final int diasVencimiento;              // días hasta vencimiento (default 30)
  // Vínculos
  final MetodoPagoFactura? metodoPago;
  final String? pedidoId;
  final String? facturaOriginalId;        // para rectificativas y duplicados
  // ── Campos de factura rectificativa (Art. 15 RD 1619/2012) ──
  final String? facturaOriginalNumero;    // número de la factura que se rectifica
  final DateTime? facturaOriginalFecha;   // fecha de emisión de la original
  final MotivoRectificacion? motivoRectificacion;
  final MetodoRectificacion? metodoRectificacion;
  final String? motivoRectificacionTexto; // texto libre adicional
  // Notas
  final String? notasInternas;
  final String? notasCliente;
  final DateTime? fechaOperacion;
  // Verifactu (registro fiscal electrónico RD 1007/2023)
  final Map<String, dynamic>? verifactu;
  // Auditoría
  final List<EntradaHistorialFactura> historial;
  final DateTime fechaEmision;
  final DateTime? fechaVencimiento;
  final DateTime? fechaPago;
  final DateTime? fechaActualizacion;

  const Factura({
    required this.id,
    required this.empresaId,
    required this.numeroFactura,
    this.serie = SerieFactura.fac,
    required this.tipo,
    required this.estado,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteCorreo,
    this.datosFiscales,
    required this.lineas,
    required this.subtotal,
    required this.totalIva,
    required this.total,
    this.descuentoGlobal = 0,
    this.importeDescuentoGlobal = 0,
    this.porcentajeIrpf = 0,
    this.retencionIrpf = 0,
    this.totalRecargoEquivalencia = 0,
    this.diasVencimiento = 30,
    this.metodoPago,
    this.pedidoId,
    this.facturaOriginalId,
    this.facturaOriginalNumero,
    this.facturaOriginalFecha,
    this.motivoRectificacion,
    this.metodoRectificacion,
    this.motivoRectificacionTexto,
    this.notasInternas,
    this.notasCliente,
    this.fechaOperacion,
    this.verifactu,
    required this.historial,
    required this.fechaEmision,
    this.fechaVencimiento,
    this.fechaPago,
    this.fechaActualizacion,
  });

  bool get esPendiente => estado == EstadoFactura.pendiente;
  bool get esPagada => estado == EstadoFactura.pagada;
  bool get esAnulada => estado == EstadoFactura.anulada;
  bool get esRectificativa => tipo == TipoFactura.rectificativa;
  bool get esProforma => tipo == TipoFactura.proforma;
  bool get estaVencida {
    if (estado == EstadoFactura.pagada || estado == EstadoFactura.anulada) {
      return false;
    }
    return fechaVencimiento != null &&
        DateTime.now().isAfter(fechaVencimiento!);
  }

  Factura copyWith({
    String? id,
    String? empresaId,
    String? numeroFactura,
    SerieFactura? serie,
    TipoFactura? tipo,
    EstadoFactura? estado,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteCorreo,
    DatosFiscales? datosFiscales,
    List<LineaFactura>? lineas,
    double? subtotal,
    double? totalIva,
    double? total,
    double? descuentoGlobal,
    double? importeDescuentoGlobal,
    double? porcentajeIrpf,
    double? retencionIrpf,
    double? totalRecargoEquivalencia,
    int? diasVencimiento,
    MetodoPagoFactura? metodoPago,
    String? pedidoId,
    String? facturaOriginalId,
    String? facturaOriginalNumero,
    DateTime? facturaOriginalFecha,
    MotivoRectificacion? motivoRectificacion,
    MetodoRectificacion? metodoRectificacion,
    String? motivoRectificacionTexto,
    String? notasInternas,
    String? notasCliente,
    DateTime? fechaOperacion,
    List<EntradaHistorialFactura>? historial,
    DateTime? fechaEmision,
    DateTime? fechaVencimiento,
    DateTime? fechaActualizacion,
  }) => Factura(
    id: id ?? this.id,
    empresaId: empresaId ?? this.empresaId,
    numeroFactura: numeroFactura ?? this.numeroFactura,
    serie: serie ?? this.serie,
    tipo: tipo ?? this.tipo,
    estado: estado ?? this.estado,
    clienteNombre: clienteNombre ?? this.clienteNombre,
    clienteTelefono: clienteTelefono ?? this.clienteTelefono,
    clienteCorreo: clienteCorreo ?? this.clienteCorreo,
    datosFiscales: datosFiscales ?? this.datosFiscales,
    lineas: lineas ?? this.lineas,
    subtotal: subtotal ?? this.subtotal,
    totalIva: totalIva ?? this.totalIva,
    total: total ?? this.total,
    descuentoGlobal: descuentoGlobal ?? this.descuentoGlobal,
    importeDescuentoGlobal: importeDescuentoGlobal ?? this.importeDescuentoGlobal,
    porcentajeIrpf: porcentajeIrpf ?? this.porcentajeIrpf,
    retencionIrpf: retencionIrpf ?? this.retencionIrpf,
    totalRecargoEquivalencia: totalRecargoEquivalencia ?? this.totalRecargoEquivalencia,
    diasVencimiento: diasVencimiento ?? this.diasVencimiento,
    metodoPago: metodoPago ?? this.metodoPago,
    pedidoId: pedidoId ?? this.pedidoId,
    facturaOriginalId: facturaOriginalId ?? this.facturaOriginalId,
    facturaOriginalNumero: facturaOriginalNumero ?? this.facturaOriginalNumero,
    facturaOriginalFecha: facturaOriginalFecha ?? this.facturaOriginalFecha,
    motivoRectificacion: motivoRectificacion ?? this.motivoRectificacion,
    metodoRectificacion: metodoRectificacion ?? this.metodoRectificacion,
    motivoRectificacionTexto: motivoRectificacionTexto ?? this.motivoRectificacionTexto,
    notasInternas: notasInternas ?? this.notasInternas,
    notasCliente: notasCliente ?? this.notasCliente,
    fechaOperacion: fechaOperacion ?? this.fechaOperacion,
    historial: historial ?? this.historial,
    fechaEmision: fechaEmision ?? this.fechaEmision,
    fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
    fechaPago: fechaPago ?? this.fechaPago,
    fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
  );

  factory Factura.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      return Factura(
        id: doc.id,
        empresaId: '',
        numeroFactura: 'F-ERR-${doc.id.substring(0, 6).toUpperCase()}',
        tipo: TipoFactura.venta_directa,
        estado: EstadoFactura.pendiente,
        clienteNombre: '',
        lineas: [],
        subtotal: 0,
        totalIva: 0,
        total: 0,
        historial: [],
        fechaEmision: DateTime.now(),
      );
    }
    final d = raw as Map<String, dynamic>;

    return Factura(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      numeroFactura: (d['numero_factura'] as String?)?.isNotEmpty == true
          ? d['numero_factura'] as String
          : 'F-SN-${doc.id.substring(0, 6).toUpperCase()}',
      serie: SerieFactura.values.firstWhere(
        (e) => e.name == d['serie'],
        orElse: () => SerieFactura.fac,
      ),
      tipo: TipoFactura.values.firstWhere(
        (e) => e.name == d['tipo'],
        orElse: () => TipoFactura.venta_directa,
      ),
      estado: EstadoFactura.values.firstWhere(
        (e) => e.name == d['estado'],
        orElse: () => EstadoFactura.pendiente,
      ),
      clienteNombre: d['cliente_nombre'] ?? '',
      clienteTelefono: d['cliente_telefono'],
      clienteCorreo: d['cliente_correo'],
      datosFiscales: d['datos_fiscales'] != null
          ? DatosFiscales.fromMap(d['datos_fiscales'] as Map<String, dynamic>)
          : null,
      lineas: (d['lineas'] as List<dynamic>? ?? [])
          .map((l) => LineaFactura.fromMap(l as Map<String, dynamic>))
          .toList(),
      subtotal: (d['subtotal'] as num?)?.toDouble() ?? 0,
      totalIva: (d['total_iva'] as num?)?.toDouble() ?? 0,
      total: (d['total'] as num?)?.toDouble() ?? 0,
      descuentoGlobal: (d['descuento_global'] as num?)?.toDouble() ?? 0,
      importeDescuentoGlobal: (d['importe_descuento_global'] as num?)?.toDouble() ?? 0,
      porcentajeIrpf: (d['porcentaje_irpf'] as num?)?.toDouble() ?? 0,
      retencionIrpf: (d['retencion_irpf'] as num?)?.toDouble() ?? 0,
      totalRecargoEquivalencia: (d['total_recargo_equivalencia'] as num?)?.toDouble() ?? 0,
      diasVencimiento: (d['dias_vencimiento'] as num?)?.toInt() ?? 30,
      metodoPago: d['metodo_pago'] != null
          ? MetodoPagoFactura.values.firstWhere(
              (e) => e.name == d['metodo_pago'],
              orElse: () => MetodoPagoFactura.efectivo)
          : null,
      pedidoId: d['pedido_id'],
      facturaOriginalId: d['factura_original_id'],
      facturaOriginalNumero: d['factura_original_numero'],
      facturaOriginalFecha: d['factura_original_fecha'] != null
          ? _parseTs(d['factura_original_fecha'])
          : null,
      motivoRectificacion: d['motivo_rectificacion'] != null
          ? MotivoRectificacion.values.firstWhere(
              (e) => e.name == d['motivo_rectificacion'],
              orElse: () => MotivoRectificacion.otro,
            )
          : null,
      metodoRectificacion: d['metodo_rectificacion'] != null
          ? MetodoRectificacion.values.firstWhere(
              (e) => e.name == d['metodo_rectificacion'],
              orElse: () => MetodoRectificacion.sustitucion,
            )
          : null,
      motivoRectificacionTexto: d['motivo_rectificacion_texto'],
      notasInternas: d['notas_internas'],
      notasCliente: d['notas_cliente'],
      fechaOperacion: d['fecha_operacion'] != null
          ? _parseTs(d['fecha_operacion'])
          : null,
      verifactu: d['verifactu'],
      historial: (d['historial'] as List<dynamic>? ?? [])
          .map((h) => EntradaHistorialFactura.fromMap(h as Map<String, dynamic>))
          .toList(),
      fechaEmision: d['fecha_emision'] != null
          ? _parseTs(d['fecha_emision'])
          : DateTime.now(),
      fechaVencimiento: d['fecha_vencimiento'] != null
          ? _parseTs(d['fecha_vencimiento'])
          : null,
      fechaPago: d['fecha_pago'] != null ? _parseTs(d['fecha_pago']) : null,
      fechaActualizacion: d['fecha_actualizacion'] != null
          ? _parseTs(d['fecha_actualizacion'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'numero_factura': numeroFactura,
    'serie': serie.name,
    'tipo': tipo.name,
    'estado': estado.name,
    'cliente_nombre': clienteNombre,
    'cliente_telefono': clienteTelefono,
    'cliente_correo': clienteCorreo,
    'datos_fiscales': datosFiscales?.toMap(),
    'lineas': lineas.map((l) => l.toMap()).toList(),
    'subtotal': subtotal,
    'total_iva': totalIva,
    'total': total,
    'descuento_global': descuentoGlobal,
    'importe_descuento_global': importeDescuentoGlobal,
    'porcentaje_irpf': porcentajeIrpf,
    'retencion_irpf': retencionIrpf,
    'total_recargo_equivalencia': totalRecargoEquivalencia,
    'dias_vencimiento': diasVencimiento,
    'metodo_pago': metodoPago?.name,
    'pedido_id': pedidoId,
    'factura_original_id': facturaOriginalId,
    'factura_original_numero': facturaOriginalNumero,
    'factura_original_fecha': facturaOriginalFecha != null
        ? Timestamp.fromDate(facturaOriginalFecha!)
        : null,
    'motivo_rectificacion': motivoRectificacion?.name,
    'metodo_rectificacion': metodoRectificacion?.name,
    'motivo_rectificacion_texto': motivoRectificacionTexto,
    'notas_internas': notasInternas,
    'notas_cliente': notasCliente,
    'fecha_operacion': fechaOperacion != null
        ? Timestamp.fromDate(fechaOperacion!)
        : null,
    'verifactu': verifactu,
    'historial': historial.map((h) => h.toMap()).toList(),
    'fecha_emision': Timestamp.fromDate(fechaEmision),
    'fecha_vencimiento':
        fechaVencimiento != null ? Timestamp.fromDate(fechaVencimiento!) : null,
  };

  /// Calcula los totales a partir de las líneas y configuración fiscal.
  static Map<String, double> calcularTotales({
    required List<LineaFactura> lineas,
    double descuentoGlobal = 0,
    double porcentajeIrpf = 0,
  }) {
    final subtotal = lineas.fold(0.0, (s, l) => s + l.subtotalSinIva);
    final descGlobal = subtotal * (descuentoGlobal / 100);
    final baseTrasDscto = subtotal - descGlobal;
    final factor = descuentoGlobal > 0 ? (1 - descuentoGlobal / 100) : 1.0;
    final totalIva = lineas.fold(0.0, (s, l) => s + l.importeIva) * factor;
    final totalRecargo = lineas.fold(0.0, (s, l) => s + l.importeRecargo) * factor;
    final retencion = baseTrasDscto * (porcentajeIrpf / 100);
    final total = baseTrasDscto + totalIva + totalRecargo - retencion;
    return {
      'subtotal': subtotal,
      'importe_descuento_global': descGlobal,
      'total_iva': totalIva,
      'total_recargo_equivalencia': totalRecargo,
      'retencion_irpf': retencion,
      'total': total,
    };
  }
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}


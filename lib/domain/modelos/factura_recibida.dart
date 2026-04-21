import 'package:cloud_firestore/cloud_firestore.dart';

// ── ENUMS ─────────────────────────────────────────────────────────────────────

enum EstadoFacturaRecibida { pendiente, recibida, pagada, rechazada }

// ── EXTENSIONES ───────────────────────────────────────────────────────────────

extension EstadoFacturaRecibidaExt on EstadoFacturaRecibida {
  String get etiqueta {
    switch (this) {
      case EstadoFacturaRecibida.pendiente:
        return 'Pendiente';
      case EstadoFacturaRecibida.recibida:
        return 'Recibida';
      case EstadoFacturaRecibida.pagada:
        return 'Pagada';
      case EstadoFacturaRecibida.rechazada:
        return 'Rechazada';
    }
  }

  bool get esActiva =>
      this == EstadoFacturaRecibida.pendiente ||
      this == EstadoFacturaRecibida.recibida;
}

// ── FACTURA RECIBIDA ──────────────────────────────────────────────────────────

class FacturaRecibida {
  final String id;
  final String empresaId;

  // Identificación documento
  final String numeroFactura;           // "INV-2026-001"
  final String? serie;                  // "INV"
  final DateTime fechaEmision;
  final DateTime fechaRecepcion;        // Para llevar devengo fiscal

  // Datos proveedor (validados)
  final String nifProveedor;            // Validado
  final String? nifIvaComunitario;
  final bool esIntracomunitario;
  final String nombreProveedor;
  final String? direccionProveedor;
  final String? telefonoProveedor;

  // Importes e impuestos
  final double baseImponible;
  final double porcentajeIva;           // 21, 10, 0, 4
  final double importeIva;              // baseImponible × (porcentajeIva/100)
  final double importeNoSujeto;         // Importe no sujeto a IVA (BUG#6 fix)
  final bool ivaDeducible;              // true: deducible, false: no deducible
  final double descuentoGlobal;         // % descuento
  final double recargoEquivalencia;     // % recargo (mayoristas)
  final double totalConImpuestos;

  // Retenciones (IRPF, otros)
  final double? porcentajeRetencion;    // % IRPF si aplica
  final double? importeRetencion;

  // Registro contable
  final EstadoFacturaRecibida estado;
  final DateTime? fechaPago;
  final String? metodoPago;            // Tarjeta, Transferencia, Efectivo, etc.
  final String? referenciaBancaria;    // Para búsqueda/conciliación

  // Arrendamiento (Mod.115)
  final bool esArrendamiento;
  final String? nifArrendador;
  final String? conceptoArrendamiento;

  // Notas
  final String? notas;

  // Metadatos
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  // IA / trazabilidad
  final String? aiTransactionId;

  // Conversión de divisa (facturas en moneda extranjera)
  final String? currency;              // Moneda original: "USD", "GBP", etc.
  final double? eurAmount;             // Importe convertido a EUR
  final double? exchangeRate;          // Tipo de cambio usado
  final String? exchangeRateDate;      // Fecha del tipo (YYYY-MM-DD)
  final String? exchangeRateSource;    // "ECB"
  final String conversionStatus;       // "not_needed", "pending", "converted", "error"

  const FacturaRecibida({
    required this.id,
    required this.empresaId,
    required this.numeroFactura,
    this.serie,
    required this.fechaEmision,
    required this.fechaRecepcion,
    required this.nifProveedor,
    this.nifIvaComunitario,
    this.esIntracomunitario = false,
    required this.nombreProveedor,
    this.direccionProveedor,
    this.telefonoProveedor,
    required this.baseImponible,
    this.porcentajeIva = 21.0,
    required this.importeIva,
    this.importeNoSujeto = 0,
    this.ivaDeducible = true,
    this.descuentoGlobal = 0,
    this.recargoEquivalencia = 0,
    required this.totalConImpuestos,
    this.porcentajeRetencion,
    this.importeRetencion,
    this.estado = EstadoFacturaRecibida.pendiente,
    this.fechaPago,
    this.metodoPago,
    this.referenciaBancaria,
    this.esArrendamiento = false,
    this.nifArrendador,
    this.conceptoArrendamiento,
    this.notas,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.aiTransactionId,
    this.currency,
    this.eurAmount,
    this.exchangeRate,
    this.exchangeRateDate,
    this.exchangeRateSource,
    this.conversionStatus = 'not_needed',
  });

  // Getters calculados
  double get baseNetaDeducible => ivaDeducible ? baseImponible : 0;
  double get ivaDeducibleReal => ivaDeducible ? importeIva : 0;
  bool get estaPagada => estado == EstadoFacturaRecibida.pagada;
  bool get estaPendiente => estado == EstadoFacturaRecibida.pendiente;

  FacturaRecibida copyWith({
    String? numeroFactura,
    String? aiTransactionId,
    String? nifProveedor,
    String? nifIvaComunitario,
    bool? esIntracomunitario,
    String? nombreProveedor,
    String? direccionProveedor,
    String? telefonoProveedor,
    double? baseImponible,
    double? porcentajeIva,
    double? importeIva,
    double? importeNoSujeto,
    bool? ivaDeducible,
    double? descuentoGlobal,
    double? recargoEquivalencia,
    double? totalConImpuestos,
    double? porcentajeRetencion,
    double? importeRetencion,
    EstadoFacturaRecibida? estado,
    DateTime? fechaPago,
    String? metodoPago,
    String? referenciaBancaria,
    bool? esArrendamiento,
    String? nifArrendador,
    String? conceptoArrendamiento,
    String? notas,
    DateTime? fechaActualizacion,
    String? currency,
    double? eurAmount,
    double? exchangeRate,
    String? exchangeRateDate,
    String? exchangeRateSource,
    String? conversionStatus,
  }) =>
      FacturaRecibida(
        id: id,
        empresaId: empresaId,
        numeroFactura: numeroFactura ?? this.numeroFactura,
        serie: serie,
        fechaEmision: fechaEmision,
        fechaRecepcion: fechaRecepcion,
        nifProveedor: nifProveedor ?? this.nifProveedor,
        nifIvaComunitario: nifIvaComunitario ?? this.nifIvaComunitario,
        esIntracomunitario: esIntracomunitario ?? this.esIntracomunitario,
        nombreProveedor: nombreProveedor ?? this.nombreProveedor,
        direccionProveedor: direccionProveedor ?? this.direccionProveedor,
        telefonoProveedor: telefonoProveedor ?? this.telefonoProveedor,
        baseImponible: baseImponible ?? this.baseImponible,
        porcentajeIva: porcentajeIva ?? this.porcentajeIva,
        importeIva: importeIva ?? this.importeIva,
        importeNoSujeto: importeNoSujeto ?? this.importeNoSujeto,
        ivaDeducible: ivaDeducible ?? this.ivaDeducible,
        descuentoGlobal: descuentoGlobal ?? this.descuentoGlobal,
        recargoEquivalencia: recargoEquivalencia ?? this.recargoEquivalencia,
        totalConImpuestos: totalConImpuestos ?? this.totalConImpuestos,
        porcentajeRetencion: porcentajeRetencion ?? this.porcentajeRetencion,
        importeRetencion: importeRetencion ?? this.importeRetencion,
        estado: estado ?? this.estado,
        fechaPago: fechaPago ?? this.fechaPago,
        metodoPago: metodoPago ?? this.metodoPago,
        referenciaBancaria: referenciaBancaria ?? this.referenciaBancaria,
        esArrendamiento: esArrendamiento ?? this.esArrendamiento,
        nifArrendador: nifArrendador ?? this.nifArrendador,
        conceptoArrendamiento: conceptoArrendamiento ?? this.conceptoArrendamiento,
        notas: notas ?? this.notas,
        fechaCreacion: fechaCreacion,
        fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
        aiTransactionId: aiTransactionId ?? this.aiTransactionId,
        currency: currency ?? this.currency,
        eurAmount: eurAmount ?? this.eurAmount,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        exchangeRateDate: exchangeRateDate ?? this.exchangeRateDate,
        exchangeRateSource: exchangeRateSource ?? this.exchangeRateSource,
        conversionStatus: conversionStatus ?? this.conversionStatus,
      );

  factory FacturaRecibida.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FacturaRecibida(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      numeroFactura: d['numero_factura'] ?? '',
      serie: d['serie'],
      fechaEmision: _parseTs(d['fecha_emision']),
      fechaRecepcion: _parseTs(d['fecha_recepcion']),
      nifProveedor: d['nif_proveedor'] ?? '',
      nifIvaComunitario: d['nif_iva_comunitario'],
      esIntracomunitario: d['es_intracomunitario'] ?? false,
      nombreProveedor: d['nombre_proveedor'] ?? '',
      direccionProveedor: d['direccion_proveedor'],
      telefonoProveedor: d['telefono_proveedor'],
      baseImponible: (d['base_imponible'] as num?)?.toDouble() ?? 0,
      porcentajeIva: (d['porcentaje_iva'] as num?)?.toDouble() ?? 21.0,
      importeIva: (d['importe_iva'] as num?)?.toDouble() ?? 0,
      importeNoSujeto: (d['importe_no_sujeto'] as num?)?.toDouble() ?? 0,
      ivaDeducible: d['iva_deducible'] ?? true,
      descuentoGlobal: (d['descuento_global'] as num?)?.toDouble() ?? 0,
      recargoEquivalencia: (d['recargo_equivalencia'] as num?)?.toDouble() ?? 0,
      totalConImpuestos: (d['total_con_impuestos'] as num?)?.toDouble() ?? 0,
      porcentajeRetencion: (d['porcentaje_retencion'] as num?)?.toDouble(),
      importeRetencion: (d['importe_retencion'] as num?)?.toDouble(),
      estado: EstadoFacturaRecibida.values.firstWhere(
        (e) => e.name == d['estado'],
        orElse: () => EstadoFacturaRecibida.pendiente,
      ),
      fechaPago: d['fecha_pago'] != null ? _parseTs(d['fecha_pago']) : null,
      metodoPago: d['metodo_pago'],
      referenciaBancaria: d['referencia_bancaria'],
      esArrendamiento: d['es_arrendamiento'] ?? false,
      nifArrendador: d['nif_arrendador'],
      conceptoArrendamiento: d['concepto_arrendamiento'],
      notas: d['notas'],
      fechaCreacion: _parseTs(d['fecha_creacion']),
      fechaActualizacion: d['fecha_actualizacion'] != null
          ? _parseTs(d['fecha_actualizacion'])
          : null,
      aiTransactionId: d['_ai_transaction_id'] as String?,
      currency: d['currency'] as String?,
      eurAmount: (d['eur_amount'] as num?)?.toDouble(),
      exchangeRate: (d['exchange_rate'] as num?)?.toDouble(),
      exchangeRateDate: d['exchange_rate_date'] as String?,
      exchangeRateSource: d['exchange_rate_source'] as String?,
      conversionStatus: (d['conversion_status'] as String?) ?? 'not_needed',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'numero_factura': numeroFactura,
    'serie': serie,
    'fecha_emision': Timestamp.fromDate(fechaEmision),
    'fecha_recepcion': Timestamp.fromDate(fechaRecepcion),
    'nif_proveedor': nifProveedor,
    'nif_iva_comunitario': nifIvaComunitario,
    'es_intracomunitario': esIntracomunitario,
    'nombre_proveedor': nombreProveedor,
    'direccion_proveedor': direccionProveedor,
    'telefono_proveedor': telefonoProveedor,
    'base_imponible': baseImponible,
    'porcentaje_iva': porcentajeIva,
    'importe_iva': importeIva,
    'importe_no_sujeto': importeNoSujeto,
    'iva_deducible': ivaDeducible,
    'descuento_global': descuentoGlobal,
    'recargo_equivalencia': recargoEquivalencia,
    'total_con_impuestos': totalConImpuestos,
    'porcentaje_retencion': porcentajeRetencion,
    'importe_retencion': importeRetencion,
    'estado': estado.name,
    'fecha_pago': fechaPago != null ? Timestamp.fromDate(fechaPago!) : null,
    'metodo_pago': metodoPago,
    'referencia_bancaria': referenciaBancaria,
    'es_arrendamiento': esArrendamiento,
    'nif_arrendador': nifArrendador,
    'concepto_arrendamiento': conceptoArrendamiento,
    'notas': notas,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'fecha_actualizacion': Timestamp.fromDate(fechaActualizacion ?? DateTime.now()),
    '_ai_transaction_id': aiTransactionId,
    'currency': currency,
    'eur_amount': eurAmount,
    'exchange_rate': exchangeRate,
    'exchange_rate_date': exchangeRateDate,
    'exchange_rate_source': exchangeRateSource,
    'conversion_status': conversionStatus,
  };
}

// ── HELPER ────────────────────────────────────────────────────────────────────

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}





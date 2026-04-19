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

    this.telefonoProveedor,
    this.porcentajeIva = 21.0,
    required this.importeIva,
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
  });

  // Getters calculados
  double get baseNetaDeducible => ivaDeducible ? baseImponible : 0;
  double get ivaDeducibleReal => ivaDeducible ? importeIva : 0;
  bool get estaPagada => estado == EstadoFacturaRecibida.pagada;
  bool get estaPendiente => estado == EstadoFacturaRecibida.pendiente;

  FacturaRecibida copyWith({
    String? numeroFactura,
    this.aiTransactionId,
    String? nifProveedor,
    String? nifIvaComunitario,
    bool? esIntracomunitario,
    String? nombreProveedor,
    String? direccionProveedor,
    String? telefonoProveedor,
    double? baseImponible,
    double? porcentajeIva,
    double? importeIva,
    double? descuentoGlobal,
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
  }) =>
      FacturaRecibida(
        id: id,
        empresaId: empresaId,
        numeroFactura: numeroFactura ?? this.numeroFactura,
        fechaEmision: fechaEmision,
        fechaRecepcion: fechaRecepcion,
        nifProveedor: nifProveedor ?? this.nifProveedor,
        nifIvaComunitario: nifIvaComunitario ?? this.nifIvaComunitario,
        esIntracomunitario: esIntracomunitario ?? this.esIntracomunitario,
        nombreProveedor: nombreProveedor ?? this.nombreProveedor,
        baseImponible: baseImponible ?? this.baseImponible,
        serie: serie,
        direccionProveedor: direccionProveedor ?? this.direccionProveedor,
        telefonoProveedor: telefonoProveedor ?? this.telefonoProveedor,
        porcentajeIva: porcentajeIva ?? this.porcentajeIva,
        importeIva: importeIva ?? this.importeIva,
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
      );

  factory FacturaRecibida.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FacturaRecibida(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      numeroFactura: d['numero_factura'] ?? '',
      fechaEmision: _parseTs(d['fecha_emision']),
      fechaRecepcion: _parseTs(d['fecha_recepcion']),
      nifProveedor: d['nif_proveedor'] ?? '',
        aiTransactionId: aiTransactionId,
      nifIvaComunitario: d['nif_iva_comunitario'],
      esIntracomunitario: d['es_intracomunitario'] ?? false,
      nombreProveedor: d['nombre_proveedor'] ?? '',
      baseImponible: (d['base_imponible'] as num?)?.toDouble() ?? 0,
      serie: d['serie'],
      telefonoProveedor: d['telefono_proveedor'],
      importeIva: (d['importe_iva'] as num?)?.toDouble() ?? 0,
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
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'numero_factura': numeroFactura,
    'serie': serie,
    'fecha_emision': Timestamp.fromDate(fechaEmision),
    'nif_proveedor': nifProveedor,
    'nif_iva_comunitario': nifIvaComunitario,
    'es_intracomunitario': esIntracomunitario,
    'nombre_proveedor': nombreProveedor,
      aiTransactionId: d['_ai_transaction_id'] as String?,
    'direccion_proveedor': direccionProveedor,
    'telefono_proveedor': telefonoProveedor,
    'base_imponible': baseImponible,
    'porcentaje_iva': porcentajeIva,
    'importe_iva': importeIva,
    'iva_deducible': ivaDeducible,
    'descuento_global': descuentoGlobal,
    'recargo_equivalencia': recargoEquivalencia,
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
  };
}

// ── HELPER ────────────────────────────────────────────────────────────────────

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}



    '_ai_transaction_id': aiTransactionId,


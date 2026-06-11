import 'package:flutter/material.dart';

// ── MODO DE FACTURACIÓN TPV ───────────────────────────────────────────────────

enum ModoFacturacionTpv {
  porVenta,      // Una factura por cada pedido
  resumenDiario, // Una factura al día con todos los pedidos
  manual,        // El usuario decide manualmente
}

extension ModoFacturacionTpvExt on ModoFacturacionTpv {
  String get nombre {
    switch (this) {
      case ModoFacturacionTpv.porVenta:      return 'Por cada venta';
      case ModoFacturacionTpv.resumenDiario: return 'Resumen diario';
      case ModoFacturacionTpv.manual:        return 'Manual';
    }
  }

  String get descripcion {
    switch (this) {
      case ModoFacturacionTpv.porVenta:
        return 'Genera una factura por cada pedido del TPV. Ideal para B2B.';
      case ModoFacturacionTpv.resumenDiario:
        return 'Agrupa todas las ventas del día en una sola factura. Ideal para hostelería y comercio minorista.';
      case ModoFacturacionTpv.manual:
        return 'Tú decides cuándo facturar los pedidos del TPV.';
    }
  }
}

// ── TIPO DE DOCUMENTO QUE GENERA EL TPV ──────────────────────────────────────

enum TipoDocumentoTpv {
  ticket,
  facturaSimplificada,
  facturaCompleta,
}

extension TipoDocumentoTpvExt on TipoDocumentoTpv {
  String get nombre {
    switch (this) {
      case TipoDocumentoTpv.ticket:              return 'Ticket';
      case TipoDocumentoTpv.facturaSimplificada: return 'Factura simplificada';
      case TipoDocumentoTpv.facturaCompleta:     return 'Factura completa';
    }
  }
  String get descripcion {
    switch (this) {
      case TipoDocumentoTpv.ticket:
        return 'Sin datos de cliente ni desglose fiscal.';
      case TipoDocumentoTpv.facturaSimplificada:
        return 'IVA incluido. Válida hasta 3.000 € sin NIF del cliente. Recomendada para comercio y hostelería.';
      case TipoDocumentoTpv.facturaCompleta:
        return 'Requiere NIF y datos del cliente. El cliente puede deducirse el IVA.';
    }
  }
  String get icono {
    switch (this) {
      case TipoDocumentoTpv.ticket:              return '🧾';
      case TipoDocumentoTpv.facturaSimplificada: return '📄';
      case TipoDocumentoTpv.facturaCompleta:     return '📋';
    }
  }
}

// ── FORMATO DE IMPRESIÓN / SALIDA ─────────────────────────────────────────────

enum FormatoImpresionTpv {
  ticket80mm,
  ticket58mm,
  a4,
}

extension FormatoImpresionTpvExt on FormatoImpresionTpv {
  String get nombre {
    switch (this) {
      case FormatoImpresionTpv.ticket80mm: return 'Ticket 80mm';
      case FormatoImpresionTpv.ticket58mm: return 'Ticket 58mm';
      case FormatoImpresionTpv.a4:         return 'PDF A4';
    }
  }
  String get icono {
    switch (this) {
      case FormatoImpresionTpv.ticket80mm: return '🖨️';
      case FormatoImpresionTpv.ticket58mm: return '📃';
      case FormatoImpresionTpv.a4:         return '📑';
    }
  }
}

// ── CONFIGURACIÓN DE FACTURACIÓN TPV ─────────────────────────────────────────

class ConfiguracionFacturacionTpv {
  final ModoFacturacionTpv modo;
  // 🆕 Tipo de documento que genera el TPV al cobrar
  final TipoDocumentoTpv tipoDocumento;
  // 🆕 IDs de plantillas PDF vinculadas (null = usa la marcada como "Por defecto")
  final String? plantillaIdFactura;
  final String? plantillaIdSimplificada;
  final String? plantillaIdTicket;
  // 🆕 Flujo al cobrar
  final bool pedirDatosClienteAlCobrar;
  final bool enviarPorEmailAuto;
  final bool imprimirAuto;
  // 🆕 Formato de salida
  final FormatoImpresionTpv formatoImpresion;

  final TimeOfDay horaGeneracion;
  final bool generarAutomaticamente;
  final bool soloSiClienteIdentificado;
  final bool incluirPedidosEfectivo;
  final bool incluirPedidosTarjeta;
  final bool incluirPedidosMixto;
  final String serieFactura;
  final bool aplicarVeriFactu;
  final int diasVencimiento;
  final bool facturacionAutomatica;
  // ── IVA ────────────────────────────────────────────────────────────────────
  /// Si true, los precios ya incluyen IVA (PVP). La base imponible se calcula
  /// dividiendo entre (1 + iva/100). Si false (defecto), el precio es base y
  /// se añade el IVA encima.
  final bool preciosIncluyenIva;

  // ── Cajón registradora ────────────────────────────────────────────────────
  /// Abrir cajón automáticamente al cobrar
  final bool abrirCajonAlCobrar;
  /// Solo abrir en pagos en efectivo (false = abrir siempre)
  final bool abrirCajonSoloEfectivo;
  /// Pin del cajón: 0 = Pin 2 (estándar), 1 = Pin 5
  final int drawerPin;

  // ── Datos de empresa para facturas (sobreescriben los del documento raíz) ─
  final String nombreEmpresa;
  final String cifEmpresa;
  final String direccionEmpresa;

  // ── Personalización del ticket ────────────────────────────────────────────
  final String mensajePiTicket;
  final int numeroCopias;

  // ── Acceso y seguridad ────────────────────────────────────────────────────
  /// PIN de 4 dígitos para abrir el TPV. Vacío = sin PIN.
  final String pinAcceso;

  // ── Propina ───────────────────────────────────────────────────────────────
  /// Muestra el campo de propina en la pantalla de cobro
  final bool mostrarPropina;
  /// Porcentajes sugeridos separados por coma (ej: "5,10,15")
  final String porcentajesPropina;

  // ── Descuentos ────────────────────────────────────────────────────────────
  /// Porcentaje máximo de descuento por línea (0 = sin límite → usa 100)
  final int descuentoMaximoPct;

  // ── Stock ─────────────────────────────────────────────────────────────────
  /// Bloquea la venta si el producto tiene stock = 0
  final bool bloquearVentaSinStock;

  // ── Cancelaciones ─────────────────────────────────────────────────────────
  /// Pide justificación obligatoria al anular un ticket
  final bool pedirMotivoCancelacion;

  const ConfiguracionFacturacionTpv({
    this.modo = ModoFacturacionTpv.resumenDiario,
    this.tipoDocumento = TipoDocumentoTpv.facturaSimplificada,
    this.plantillaIdFactura,
    this.plantillaIdSimplificada,
    this.plantillaIdTicket,
    this.pedirDatosClienteAlCobrar = false,
    this.enviarPorEmailAuto = false,
    this.imprimirAuto = false,
    this.formatoImpresion = FormatoImpresionTpv.ticket80mm,
    this.horaGeneracion = const TimeOfDay(hour: 23, minute: 30),
    this.generarAutomaticamente = false,
    this.soloSiClienteIdentificado = false,
    this.incluirPedidosEfectivo = true,
    this.incluirPedidosTarjeta = true,
    this.incluirPedidosMixto = true,
    this.serieFactura = 'TPV-',
    this.aplicarVeriFactu = true,
    this.diasVencimiento = 0,
    this.facturacionAutomatica = false,
    this.preciosIncluyenIva = false,
    this.abrirCajonAlCobrar = false,
    this.abrirCajonSoloEfectivo = true,
    this.drawerPin = 0,
    this.nombreEmpresa = '',
    this.cifEmpresa = '',
    this.direccionEmpresa = '',
    this.mensajePiTicket = '',
    this.numeroCopias = 1,
    this.pinAcceso = '',
    this.mostrarPropina = true,
    this.porcentajesPropina = '5,10,15',
    this.descuentoMaximoPct = 100,
    this.bloquearVentaSinStock = false,
    this.pedirMotivoCancelacion = false,
  });

  factory ConfiguracionFacturacionTpv.fromMap(Map<String, dynamic> d) {
    final horaStr = d['hora_generacion'] as String? ?? '23:30';
    final partes = horaStr.split(':');
    return ConfiguracionFacturacionTpv(
      modo: ModoFacturacionTpv.values.firstWhere(
        (m) => m.name == d['modo'], orElse: () => ModoFacturacionTpv.resumenDiario),
      tipoDocumento: TipoDocumentoTpv.values.firstWhere(
        (t) => t.name == d['tipo_documento'], orElse: () => TipoDocumentoTpv.facturaSimplificada),
      plantillaIdFactura:      d['plantilla_id_factura'] as String?,
      plantillaIdSimplificada: d['plantilla_id_simplificada'] as String?,
      plantillaIdTicket:       d['plantilla_id_ticket'] as String?,
      pedirDatosClienteAlCobrar: d['pedir_datos_cliente_al_cobrar'] as bool? ?? false,
      enviarPorEmailAuto: d['enviar_por_email_auto'] as bool? ?? false,
      imprimirAuto:       d['imprimir_auto'] as bool? ?? false,
      formatoImpresion: FormatoImpresionTpv.values.firstWhere(
        (f) => f.name == d['formato_impresion'], orElse: () => FormatoImpresionTpv.ticket80mm),
      horaGeneracion: TimeOfDay(
        hour: int.tryParse(partes[0]) ?? 23,
        minute: int.tryParse(partes.length > 1 ? partes[1] : '30') ?? 30),
      generarAutomaticamente:    d['generar_automaticamente'] as bool? ?? false,
      soloSiClienteIdentificado: d['solo_si_cliente_identificado'] as bool? ?? false,
      incluirPedidosEfectivo: d['incluir_pedidos_efectivo'] as bool? ?? true,
      incluirPedidosTarjeta:  d['incluir_pedidos_tarjeta'] as bool? ?? true,
      incluirPedidosMixto:    d['incluir_pedidos_mixto'] as bool? ?? true,
      serieFactura:    d['serie_factura'] as String? ?? 'TPV-',
      aplicarVeriFactu: d['aplicar_verifactu'] as bool? ?? true,
      diasVencimiento: (d['dias_vencimiento'] as num?)?.toInt() ?? 0,
      facturacionAutomatica: d['facturacion_automatica'] as bool? ?? false,
      preciosIncluyenIva: d['precios_incluyen_iva'] as bool? ?? false,
      abrirCajonAlCobrar:       d['abrir_cajon_al_cobrar'] as bool? ?? false,
      abrirCajonSoloEfectivo:   d['abrir_cajon_solo_efectivo'] as bool? ?? true,
      drawerPin:                (d['drawer_pin'] as num?)?.toInt() ?? 0,
      nombreEmpresa:   d['nombre_empresa'] as String? ?? '',
      cifEmpresa:      d['cif_empresa'] as String? ?? '',
      direccionEmpresa: d['direccion_empresa'] as String? ?? '',
      mensajePiTicket: d['mensaje_pi_ticket'] as String? ?? '',
      numeroCopias: (d['numero_copias'] as num?)?.toInt() ?? 1,
      pinAcceso:    d['pin_acceso'] as String? ?? '',
      mostrarPropina: d['mostrar_propina'] as bool? ?? true,
      porcentajesPropina: d['porcentajes_propina'] as String? ?? '5,10,15',
      descuentoMaximoPct: (d['descuento_maximo_pct'] as num?)?.toInt() ?? 100,
      bloquearVentaSinStock: d['bloquear_venta_sin_stock'] as bool? ?? false,
      pedirMotivoCancelacion: d['pedir_motivo_cancelacion'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'modo': modo.name,
    'tipo_documento': tipoDocumento.name,
    'plantilla_id_factura':      plantillaIdFactura,
    'plantilla_id_simplificada': plantillaIdSimplificada,
    'plantilla_id_ticket':       plantillaIdTicket,
    'pedir_datos_cliente_al_cobrar': pedirDatosClienteAlCobrar,
    'enviar_por_email_auto': enviarPorEmailAuto,
    'imprimir_auto':         imprimirAuto,
    'formato_impresion':     formatoImpresion.name,
    'hora_generacion': '${horaGeneracion.hour.toString().padLeft(2, '0')}:${horaGeneracion.minute.toString().padLeft(2, '0')}',
    'generar_automaticamente':    generarAutomaticamente,
    'solo_si_cliente_identificado': soloSiClienteIdentificado,
    'incluir_pedidos_efectivo': incluirPedidosEfectivo,
    'incluir_pedidos_tarjeta':  incluirPedidosTarjeta,
    'incluir_pedidos_mixto':    incluirPedidosMixto,
    'serie_factura':     serieFactura,
    'aplicar_verifactu': aplicarVeriFactu,
    'dias_vencimiento':  diasVencimiento,
    'facturacion_automatica': facturacionAutomatica,
    'precios_incluyen_iva': preciosIncluyenIva,
    'abrir_cajon_al_cobrar':     abrirCajonAlCobrar,
    'abrir_cajon_solo_efectivo': abrirCajonSoloEfectivo,
    'drawer_pin':                drawerPin,
    'nombre_empresa':    nombreEmpresa,
    'cif_empresa':       cifEmpresa,
    'direccion_empresa': direccionEmpresa,
    'mensaje_pi_ticket': mensajePiTicket,
    'numero_copias':     numeroCopias,
    'pin_acceso':        pinAcceso,
    'mostrar_propina':          mostrarPropina,
    'porcentajes_propina':      porcentajesPropina,
    'descuento_maximo_pct':     descuentoMaximoPct,
    'bloquear_venta_sin_stock': bloquearVentaSinStock,
    'pedir_motivo_cancelacion': pedirMotivoCancelacion,
  };

  ConfiguracionFacturacionTpv copyWith({
    ModoFacturacionTpv? modo,
    TipoDocumentoTpv? tipoDocumento,
    String? plantillaIdFactura,
    String? plantillaIdSimplificada,
    String? plantillaIdTicket,
    bool? pedirDatosClienteAlCobrar,
    bool? enviarPorEmailAuto,
    bool? imprimirAuto,
    FormatoImpresionTpv? formatoImpresion,
    TimeOfDay? horaGeneracion,
    bool? generarAutomaticamente,
    bool? soloSiClienteIdentificado,
    bool? incluirPedidosEfectivo,
    bool? incluirPedidosTarjeta,
    bool? incluirPedidosMixto,
    String? serieFactura,
    bool? aplicarVeriFactu,
    int? diasVencimiento,
    bool? facturacionAutomatica,
    bool? preciosIncluyenIva,
    bool? abrirCajonAlCobrar,
    bool? abrirCajonSoloEfectivo,
    int? drawerPin,
    String? nombreEmpresa,
    String? cifEmpresa,
    String? direccionEmpresa,
    String? mensajePiTicket,
    int?    numeroCopias,
    String? pinAcceso,
    bool?   mostrarPropina,
    String? porcentajesPropina,
    int?    descuentoMaximoPct,
    bool?   bloquearVentaSinStock,
    bool?   pedirMotivoCancelacion,
  }) => ConfiguracionFacturacionTpv(
    modo: modo ?? this.modo,
    tipoDocumento: tipoDocumento ?? this.tipoDocumento,
    plantillaIdFactura:      plantillaIdFactura ?? this.plantillaIdFactura,
    plantillaIdSimplificada: plantillaIdSimplificada ?? this.plantillaIdSimplificada,
    plantillaIdTicket:       plantillaIdTicket ?? this.plantillaIdTicket,
    pedirDatosClienteAlCobrar: pedirDatosClienteAlCobrar ?? this.pedirDatosClienteAlCobrar,
    enviarPorEmailAuto: enviarPorEmailAuto ?? this.enviarPorEmailAuto,
    imprimirAuto:       imprimirAuto ?? this.imprimirAuto,
    formatoImpresion:   formatoImpresion ?? this.formatoImpresion,
    horaGeneracion:            horaGeneracion ?? this.horaGeneracion,
    generarAutomaticamente:    generarAutomaticamente ?? this.generarAutomaticamente,
    soloSiClienteIdentificado: soloSiClienteIdentificado ?? this.soloSiClienteIdentificado,
    incluirPedidosEfectivo: incluirPedidosEfectivo ?? this.incluirPedidosEfectivo,
    incluirPedidosTarjeta:  incluirPedidosTarjeta ?? this.incluirPedidosTarjeta,
    incluirPedidosMixto:    incluirPedidosMixto ?? this.incluirPedidosMixto,
    serieFactura:    serieFactura ?? this.serieFactura,
    aplicarVeriFactu: aplicarVeriFactu ?? this.aplicarVeriFactu,
    diasVencimiento: diasVencimiento ?? this.diasVencimiento,
    facturacionAutomatica: facturacionAutomatica ?? this.facturacionAutomatica,
    preciosIncluyenIva: preciosIncluyenIva ?? this.preciosIncluyenIva,
    abrirCajonAlCobrar:     abrirCajonAlCobrar ?? this.abrirCajonAlCobrar,
    abrirCajonSoloEfectivo: abrirCajonSoloEfectivo ?? this.abrirCajonSoloEfectivo,
    drawerPin:              drawerPin ?? this.drawerPin,
    nombreEmpresa:   nombreEmpresa ?? this.nombreEmpresa,
    cifEmpresa:      cifEmpresa ?? this.cifEmpresa,
    direccionEmpresa: direccionEmpresa ?? this.direccionEmpresa,
    mensajePiTicket: mensajePiTicket ?? this.mensajePiTicket,
    numeroCopias:    numeroCopias ?? this.numeroCopias,
    pinAcceso:       pinAcceso ?? this.pinAcceso,
    mostrarPropina:         mostrarPropina ?? this.mostrarPropina,
    porcentajesPropina:     porcentajesPropina ?? this.porcentajesPropina,
    descuentoMaximoPct:     descuentoMaximoPct ?? this.descuentoMaximoPct,
    bloquearVentaSinStock:  bloquearVentaSinStock ?? this.bloquearVentaSinStock,
    pedirMotivoCancelacion: pedirMotivoCancelacion ?? this.pedirMotivoCancelacion,
  );
}

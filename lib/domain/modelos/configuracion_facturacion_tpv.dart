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

// ── CONFIGURACIÓN DE FACTURACIÓN TPV ─────────────────────────────────────────

class ConfiguracionFacturacionTpv {
  final ModoFacturacionTpv modo;
  final TimeOfDay horaGeneracion;
  final bool generarAutomaticamente;
  final bool soloSiClienteIdentificado;
  final bool incluirPedidosEfectivo;
  final bool incluirPedidosTarjeta;
  final bool incluirPedidosMixto;
  final String serieFactura;
  final bool aplicarVeriFactu;
  final int diasVencimiento;

  const ConfiguracionFacturacionTpv({
    this.modo = ModoFacturacionTpv.resumenDiario,
    this.horaGeneracion = const TimeOfDay(hour: 23, minute: 30),
    this.generarAutomaticamente = false,
    this.soloSiClienteIdentificado = false,
    this.incluirPedidosEfectivo = true,
    this.incluirPedidosTarjeta = true,
    this.incluirPedidosMixto = true,
    this.serieFactura = 'TPV-',
    this.aplicarVeriFactu = true,
    this.diasVencimiento = 0,
  });

  factory ConfiguracionFacturacionTpv.fromMap(Map<String, dynamic> d) {
    final horaStr = d['hora_generacion'] as String? ?? '23:30';
    final partes = horaStr.split(':');
    return ConfiguracionFacturacionTpv(
      modo: ModoFacturacionTpv.values.firstWhere(
        (m) => m.name == d['modo'],
        orElse: () => ModoFacturacionTpv.resumenDiario,
      ),
      horaGeneracion: TimeOfDay(
        hour: int.tryParse(partes[0]) ?? 23,
        minute: int.tryParse(partes.length > 1 ? partes[1] : '30') ?? 30,
      ),
      generarAutomaticamente: d['generar_automaticamente'] as bool? ?? false,
      soloSiClienteIdentificado: d['solo_si_cliente_identificado'] as bool? ?? false,
      incluirPedidosEfectivo: d['incluir_pedidos_efectivo'] as bool? ?? true,
      incluirPedidosTarjeta: d['incluir_pedidos_tarjeta'] as bool? ?? true,
      incluirPedidosMixto: d['incluir_pedidos_mixto'] as bool? ?? true,
      serieFactura: d['serie_factura'] as String? ?? 'TPV-',
      aplicarVeriFactu: d['aplicar_verifactu'] as bool? ?? true,
      diasVencimiento: (d['dias_vencimiento'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'modo': modo.name,
    'hora_generacion': '${horaGeneracion.hour.toString().padLeft(2, '0')}:${horaGeneracion.minute.toString().padLeft(2, '0')}',
    'generar_automaticamente': generarAutomaticamente,
    'solo_si_cliente_identificado': soloSiClienteIdentificado,
    'incluir_pedidos_efectivo': incluirPedidosEfectivo,
    'incluir_pedidos_tarjeta': incluirPedidosTarjeta,
    'incluir_pedidos_mixto': incluirPedidosMixto,
    'serie_factura': serieFactura,
    'aplicar_verifactu': aplicarVeriFactu,
    'dias_vencimiento': diasVencimiento,
  };

  ConfiguracionFacturacionTpv copyWith({
    ModoFacturacionTpv? modo,
    TimeOfDay? horaGeneracion,
    bool? generarAutomaticamente,
    bool? soloSiClienteIdentificado,
    bool? incluirPedidosEfectivo,
    bool? incluirPedidosTarjeta,
    bool? incluirPedidosMixto,
    String? serieFactura,
    bool? aplicarVeriFactu,
    int? diasVencimiento,
  }) => ConfiguracionFacturacionTpv(
    modo: modo ?? this.modo,
    horaGeneracion: horaGeneracion ?? this.horaGeneracion,
    generarAutomaticamente: generarAutomaticamente ?? this.generarAutomaticamente,
    soloSiClienteIdentificado: soloSiClienteIdentificado ?? this.soloSiClienteIdentificado,
    incluirPedidosEfectivo: incluirPedidosEfectivo ?? this.incluirPedidosEfectivo,
    incluirPedidosTarjeta: incluirPedidosTarjeta ?? this.incluirPedidosTarjeta,
    incluirPedidosMixto: incluirPedidosMixto ?? this.incluirPedidosMixto,
    serieFactura: serieFactura ?? this.serieFactura,
    aplicarVeriFactu: aplicarVeriFactu ?? this.aplicarVeriFactu,
    diasVencimiento: diasVencimiento ?? this.diasVencimiento,
  );
}



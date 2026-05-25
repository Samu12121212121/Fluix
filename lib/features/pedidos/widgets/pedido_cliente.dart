// lib/features/pedidos/domain/modelos/pedido_cliente.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_carrito.dart';

enum ModalidadPedido { recogerEnTienda, entregaDomicilio, pedidoPrevio }
enum EstadoPedido    { pendiente, confirmado, preparando, listo, entregado, cancelado }
enum EstadoPago      { pendienteEnNegocio, pagadoOnline, pagadoEnTienda }

class PedidoCliente {
  final String id;
  final String negocioId;
  final String empresaId;
  final String? usuarioUid;
  final String nombreCliente;
  final String? telefonoCliente;
  final String? emailCliente;
  final List<ItemCarrito> lineas;
  final ModalidadPedido modalidad;
  final String? direccionEntrega;
  final String metodoPago;
  final EstadoPedido estado;
  final EstadoPago estadoPago;
  final String? notas;
  final double subtotal;
  final double costeEnvio;
  final double total;
  final DateTime? fechaCreacion;
  final String? facturaId;
  final String? numeroFactura;
  final bool generarFactura;
  final String serieFactura;

  PedidoCliente({
    required this.id,
    required this.negocioId,
    required this.empresaId,
    this.usuarioUid,
    required this.nombreCliente,
    this.telefonoCliente,
    this.emailCliente,
    required this.lineas,
    required this.modalidad,
    this.direccionEntrega,
    required this.metodoPago,
    this.estado     = EstadoPedido.pendiente,
    this.estadoPago = EstadoPago.pendienteEnNegocio,
    this.notas,
    required this.subtotal,
    this.costeEnvio = 0,
    required this.total,
    this.fechaCreacion,
    this.facturaId,
    this.numeroFactura,
    this.generarFactura = false,
    this.serieFactura   = 'B',
  });

  Map<String, dynamic> toJson() => {
    'negocio_id':      negocioId,
    'empresa_id':      empresaId,
    if (usuarioUid != null) 'usuario_uid': usuarioUid,
    'nombre_cliente':  nombreCliente,
    if (telefonoCliente != null) 'telefono_cliente': telefonoCliente,
    if (emailCliente   != null) 'email_cliente':    emailCliente,
    'lineas':          lineas.map((l) => l.toJson()).toList(),
    'modalidad':       modalidad.name,
    if (direccionEntrega != null) 'direccion_entrega': direccionEntrega,
    'metodo_pago':     metodoPago,
    'estado':          estado.name,
    'estado_pago':     estadoPago.name,
    if (notas != null) 'notas': notas,
    'subtotal':        subtotal,
    'coste_envio':     costeEnvio,
    'total':           total,
    'fecha_creacion':  FieldValue.serverTimestamp(),
    'origen':          'planeag_b2c',
    'generar_factura': generarFactura,
    'serie_factura':   serieFactura,
    // Compatibilidad con Cloud Function onPedidoCompletado (facturación)
    'estado_pago_tpv': 'pendiente',
  };

  factory PedidoCliente.fromJson(String id, Map<String, dynamic> j) => PedidoCliente(
    id:          id,
    negocioId:   j['negocio_id']    as String? ?? '',
    empresaId:   j['empresa_id']    as String? ?? '',
    usuarioUid:  j['usuario_uid']   as String?,
    nombreCliente:   j['nombre_cliente']   as String? ?? '',
    telefonoCliente: j['telefono_cliente'] as String?,
    emailCliente:    j['email_cliente']    as String?,
    lineas: (j['lineas'] as List? ?? [])
        .map((l) => ItemCarrito.fromJson(l as Map<String, dynamic>))
        .toList(),
    modalidad: ModalidadPedido.values.firstWhere(
          (e) => e.name == j['modalidad'],
      orElse: () => ModalidadPedido.recogerEnTienda,
    ),
    direccionEntrega: j['direccion_entrega'] as String?,
    metodoPago:  j['metodo_pago']   as String? ?? '',
    estado: EstadoPedido.values.firstWhere(
          (e) => e.name == j['estado'],
      orElse: () => EstadoPedido.pendiente,
    ),
    estadoPago: EstadoPago.values.firstWhere(
          (e) => e.name == j['estado_pago'],
      orElse: () => EstadoPago.pendienteEnNegocio,
    ),
    notas:       j['notas']         as String?,
    subtotal:    (j['subtotal']     as num?)?.toDouble() ?? 0,
    costeEnvio:  (j['coste_envio']  as num?)?.toDouble() ?? 0,
    total:       (j['total']        as num?)?.toDouble() ?? 0,
    fechaCreacion: (j['fecha_creacion'] as Timestamp?)?.toDate(),
    facturaId:    j['factura_id']    as String?,
    numeroFactura: j['numero_factura'] as String?,
    generarFactura: j['generar_factura'] as bool? ?? false,
    serieFactura:   j['serie_factura']   as String? ?? 'B',
  );
}
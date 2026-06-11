import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../domain/modelos/pedido.dart';
import '../../domain/modelos/configuracion_facturacion_tpv.dart';
import '../tpv_facturacion_service.dart';
import 'tpv_document_renderer.dart';
import 'impresora_service.dart';

/// Servicio que gestiona la facturación automática del TPV
/// según la configuración (por venta o resumen diario)
class FacturacionAutomaticaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TpvFacturacionService _configSvc = TpvFacturacionService();
  final TpvDocumentRenderer _renderer = TpvDocumentRenderer();
  final ImpresoraService _impresora = ImpresoraService();

  /// Procesar cobro y generar factura si corresponde
  /// Retorna el PDF generado (si aplica)
  /// NO lanza excepciones - retorna null si falla
  Future<Uint8List?> procesarCobro({
    required String empresaId,
    required Pedido pedido,
    String? clienteNif,
    String? clienteEmail,
    String? clienteDireccion,
  }) async {
    try {
      // 1. Cargar configuración
      final config = await _configSvc.obtenerConfig(empresaId);

      // 2. Verificar si debe generar documento
      if (!_debeGenerarDocumento(config, pedido)) {
        return null;
      }

      // 3. Generar PDF del documento
      final pdfBytes = await _renderer.renderizarDocumento(
        empresaId: empresaId,
        pedido: pedido,
        config: config,
        clienteNif: clienteNif,
        clienteEmail: clienteEmail,
        clienteDireccion: clienteDireccion,
      );

      // 4. Guardar en Firestore (con manejo de errores NO bloqueante)
      try {
        await _guardarDocumento(
          empresaId: empresaId,
          pedidoId: pedido.id,
          pdfBytes: pdfBytes,
          config: config,
          clienteNif: clienteNif,
          clienteEmail: clienteEmail,
        );
      } catch (e) {
        debugPrint('⚠️ Error guardar documento (no bloqueante): $e');
      }

      // 4b. Crear registro oficial de Factura en modo por-venta (no bloqueante)
      if (config.modo == ModoFacturacionTpv.porVenta && pedido.facturaId == null) {
        try {
          await _configSvc.generarFacturaPorPedido(
            empresaId: empresaId,
            pedido: pedido,
            config: config,
            usuarioNombre: 'TPV Auto',
          );
        } catch (e) {
          debugPrint('⚠️ Error al crear registro de factura (no bloqueante): $e');
        }
      }

      // 5. Imprimir automáticamente si está configurado (no bloqueante)
      if (config.imprimirAuto) {
        try {
          await _impresora.imprimirAutomatico(
            pdfBytes,
            nombreArchivo: 'documento_${pedido.id}.pdf',
          );
        } catch (e) {
          debugPrint('⚠️ Error al imprimir automáticamente: $e');
        }
      }

      return pdfBytes;
    } catch (e, stackTrace) {
      debugPrint('❌ Error en facturación automática: $e\n$stackTrace');
      // NO relanzar la excepción - retornar null para que el cobro continúe
      return null;
    }
  }

  /// Verificar si debe generar documento según configuración
  bool _debeGenerarDocumento(ConfiguracionFacturacionTpv config, Pedido pedido) {
    // Si está en modo por venta y genera automáticamente
    if (config.modo == ModoFacturacionTpv.porVenta && config.generarAutomaticamente) {
      return true;
    }

    // Si está en modo resumen diario, NO generar aquí
    // (se generará al final del día)
    if (config.modo == ModoFacturacionTpv.resumenDiario) {
      return false;
    }

    // Por defecto, no generar
    return false;
  }

  /// Guardar documento en Firestore y Storage
  Future<void> _guardarDocumento({
    required String empresaId,
    required String pedidoId,
    required Uint8List pdfBytes,
    required ConfiguracionFacturacionTpv config,
    String? clienteNif,
    String? clienteEmail,
  }) async {
    try {
      // 1. Subir PDF a Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('empresas/$empresaId/documentos_tpv/${DateTime.now().millisecondsSinceEpoch}_$pedidoId.pdf');

      await ref.putData(pdfBytes);
      final url = await ref.getDownloadURL();

      // 2. Guardar metadatos en Firestore
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('documentos_tpv')
          .add({
        'pedido_id': pedidoId,
        'tipo_documento': config.tipoDocumento.name,
        'formato': config.formatoImpresion.name,
        'url': url,
        'fecha_generacion': FieldValue.serverTimestamp(),
        'cliente_nif': clienteNif,
        'cliente_email': clienteEmail,
        'serie': config.serieFactura,
        'modo_facturacion': config.modo.name,
      });

      // 3. Actualizar pedido con referencia al documento
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos')
          .doc(pedidoId)
          .update({
        'documento_tpv_generado': true,
        'documento_tpv_tipo': config.tipoDocumento.name,
        'documento_tpv_url': url,
      });
    } catch (e) {
      debugPrint('Error al guardar documento: $e');
    }
  }

  /// Generar resumen diario de ventas
  Future<Uint8List?> generarResumenDiario({
    required String empresaId,
    required DateTime fecha,
  }) async {
    try {
      final config = await _configSvc.obtenerConfig(empresaId);

      // Obtener todos los pedidos del día que no tienen documento
      final inicio = DateTime(fecha.year, fecha.month, fecha.day);
      final fin = inicio.add(const Duration(days: 1));

      final snapshot = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos')
          .where('fecha_creacion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha_creacion', isLessThan: Timestamp.fromDate(fin))
          .where('estado_pago', isEqualTo: 'pagado')
          .get();

      final pedidos = snapshot.docs
          .map((doc) {
            try {
              final pedido = Pedido.fromFirestore(doc);
              // Verificar si ya tiene documento generado
              if (doc.data()['documento_tpv_generado'] == true) {
                return null;
              }
              return pedido;
            } catch (e) {
              return null;
            }
          })
          .where((p) => p != null)
          .cast<Pedido>()
          .toList();

      if (pedidos.isEmpty) {
        return null;
      }

      // Crear pedido resumen
      final pedidoResumen = _crearPedidoResumen(pedidos);

      // Generar PDF
      final pdfBytes = await _renderer.renderizarDocumento(
        empresaId: empresaId,
        pedido: pedidoResumen,
        config: config,
      );

      // Guardar resumen
      await _guardarResumenDiario(
        empresaId: empresaId,
        pedidos: pedidos,
        pdfBytes: pdfBytes,
        config: config,
        fecha: fecha,
      );

      // Crear factura contable del resumen diario (no bloqueante)
      try {
        await _configSvc.generarFacturaResumenDiario(
          empresaId: empresaId,
          fecha: fecha,
          config: config,
          usuarioNombre: 'TPV Auto',
        );
      } catch (e) {
        debugPrint('⚠️ Error al crear factura resumen diario (no bloqueante): $e');
      }

      return pdfBytes;
    } catch (e) {
      debugPrint('Error al generar resumen diario: $e');
      rethrow;
    }
  }

  /// Crear pedido resumen que agrupa múltiples pedidos
  Pedido _crearPedidoResumen(List<Pedido> pedidos) {
    final Map<String, LineaPedido> lineasAgrupadas = {};

    for (final pedido in pedidos) {
      for (final linea in pedido.lineas) {
        final key = '${linea.productoId}_${linea.precioUnitario}';
        if (lineasAgrupadas.containsKey(key)) {
          lineasAgrupadas[key] = LineaPedido(
            productoId: linea.productoId,
            productoNombre: linea.productoNombre,
            precioUnitario: linea.precioUnitario,
            cantidad: lineasAgrupadas[key]!.cantidad + linea.cantidad,
            ivaPorcentaje: linea.ivaPorcentaje,
            variante: linea.variante,
          );
        } else {
          lineasAgrupadas[key] = linea;
        }
      }
    }

    return Pedido(
      numeroTicket: 0,
      id: 'resumen_${DateTime.now().millisecondsSinceEpoch}',
      empresaId: pedidos.first.empresaId,
      clienteNombre: 'Resumen diario',
      clienteTelefono: null,
      lineas: lineasAgrupadas.values.toList(),
      total: pedidos.fold<double>(0.0, (sum, p) => sum + p.total),
      estado: EstadoPedido.entregado,
      origen: OrigenPedido.presencial,
      fechaCreacion: DateTime.now(),
      metodoPago: MetodoPago.mixto,
      estadoPago: EstadoPago.pagado,
      historial: [],
    );
  }

  /// Guardar resumen diario
  Future<void> _guardarResumenDiario({
    required String empresaId,
    required List<Pedido> pedidos,
    required Uint8List pdfBytes,
    required ConfiguracionFacturacionTpv config,
    required DateTime fecha,
  }) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('empresas/$empresaId/documentos_tpv/resumen_${fecha.toIso8601String()}.pdf');

    await ref.putData(pdfBytes);
    final url = await ref.getDownloadURL();

    final docRef = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('resumenes_diarios_tpv')
        .add({
      'fecha': Timestamp.fromDate(fecha),
      'num_pedidos': pedidos.length,
      'total': pedidos.fold<double>(0.0, (sum, p) => sum + p.total),
      'pedidos_ids': pedidos.map((p) => p.id).toList(),
      'url': url,
      'tipo_documento': config.tipoDocumento.name,
      'fecha_generacion': FieldValue.serverTimestamp(),
    });

    // Marcar pedidos como facturados
    final batch = _db.batch();
    for (final pedido in pedidos) {
      final pedidoRef = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos')
          .doc(pedido.id);

      batch.update(pedidoRef, {
        'documento_tpv_generado': true,
        'documento_tpv_tipo': 'resumen_diario',
        'resumen_diario_id': docRef.id,
        'documento_tpv_url': url,
      });
    }
    await batch.commit();
  }
}






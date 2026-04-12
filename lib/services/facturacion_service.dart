import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../../domain/modelos/factura.dart';
import '../../domain/modelos/factura_recibida.dart';
import '../../domain/modelos/empresa.dart';
import 'empresa_config_service.dart';
import 'verifactu_service.dart';
import 'validador_fiscal_integral.dart';

final _log = Logger();

// ── RESULTADO CREAR FACTURA ────────────────────────────────────────────────

/// Envuelve la Factura creada junto con el estado del registro VeriFactu.
class ResultadoCrearFactura {
  final Factura factura;
  final bool verifactuOk;
  final bool verifactuError;
  final String mensajeVerifactu;

  const ResultadoCrearFactura({
    required this.factura,
    this.verifactuOk = false,
    this.verifactuError = false,
    this.mensajeVerifactu = '',
  });
}

class FacturacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── COLECCIONES ────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _facturas(String empresaId) =>
      _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('facturas');

  CollectionReference<Map<String, dynamic>> _contadorFacturas(
          String empresaId) =>
      _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion');

  // ── GENERAR NÚMERO DE FACTURA POR SERIE ────────────────────────────────────

  Future<String> _generarNumeroFacturaSerie(
    String empresaId,
    SerieFactura serie,
  ) async {
    // Leer prefijo personalizado de la empresa (si existe)
    String prefijo = serie.prefijo; // valor por defecto (F / R / P)
    try {
      final empresaSnap =
          await _firestore.collection('empresas').doc(empresaId).get();
      final eData = empresaSnap.data() ?? {};
      final String? custom = switch (serie) {
        SerieFactura.fac  => eData['serie_factura'] as String?,
        SerieFactura.rect => eData['serie_rectificativa'] as String?,
        SerieFactura.pro  => eData['serie_proforma'] as String?,
      };
      if (custom != null &&
          custom.trim().isNotEmpty &&
          custom.trim().length <= 5) {
        prefijo = custom.trim().toUpperCase();
      }
    } catch (_) {} // si falla la lectura, usar prefijo por defecto

    final ref = _contadorFacturas(empresaId).doc('facturacion');
    String numero = '';
    final campoContador = 'ultimo_numero_${serie.name}';
    final campoAnio = 'anio_ultimo_${serie.name}';

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final anioActual = DateTime.now().year;
      int contador = 1;

      if (snap.exists) {
        final data = snap.data() ?? {};
        final anioGuardado = data[campoAnio] as int? ?? 0;

        if (anioGuardado == anioActual) {
          contador = ((data[campoContador] as int?) ??
                  (data['ultimo_numero_factura'] as int?) ??
                  0) +
              1;
        }
      }

      tx.set(ref, {
        campoContador: contador,
        campoAnio: anioActual,
      }, SetOptions(merge: true));

      numero = '$prefijo-$anioActual-${contador.toString().padLeft(4, '0')}';
    });

    return numero;
  }

  // ── CREAR FACTURA (COMPLETA) ──────────────────────────────────────────────

  Future<ResultadoCrearFactura> crearFactura({
    required String empresaId,
    required String clienteNombre,
    String? clienteTelefono,
    String? clienteCorreo,
    DatosFiscales? datosFiscales,
    required List<LineaFactura> lineas,
    MetodoPagoFactura? metodoPago,
    String? pedidoId,
    TipoFactura tipo = TipoFactura.venta_directa,
    String? notasInternas,
    String? notasCliente,
    DateTime? fechaOperacion,
    String usuarioId = '',
    String usuarioNombre = '',
    int diasVencimiento = 30,
    double descuentoGlobal = 0,
    double porcentajeIrpf = 0,
  }) async {
    final serie = tipo.serie;
    final numero = await _generarNumeroFacturaSerie(empresaId, serie);

    // Calcular totales con descuentos, IRPF y recargo
    final totales = Factura.calcularTotales(
      lineas: lineas,
      descuentoGlobal: descuentoGlobal,
      porcentajeIrpf: porcentajeIrpf,
    );

    final entrada = EntradaHistorialFactura(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'creada',
      descripcion: tipo == TipoFactura.proforma
          ? 'Proforma creada'
          : tipo == TipoFactura.rectificativa
              ? 'Factura rectificativa creada'
              : 'Factura creada',
      fecha: DateTime.now(),
    );

    final docRef = _facturas(empresaId).doc();
    final factura = Factura(
      id: docRef.id,
      empresaId: empresaId,
      numeroFactura: numero,
      serie: serie,
      tipo: tipo,
      estado: EstadoFactura.pendiente,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteCorreo: clienteCorreo,
      datosFiscales: datosFiscales,
      lineas: lineas,
      subtotal: totales['subtotal']!,
      totalIva: totales['total_iva']!,
      total: totales['total']!,
      descuentoGlobal: descuentoGlobal,
      importeDescuentoGlobal: totales['importe_descuento_global']!,
      porcentajeIrpf: porcentajeIrpf,
      retencionIrpf: totales['retencion_irpf']!,
      totalRecargoEquivalencia: totales['total_recargo_equivalencia']!,
      diasVencimiento: diasVencimiento,
      metodoPago: metodoPago,
      pedidoId: pedidoId,
      notasInternas: notasInternas,
      notasCliente: notasCliente,
      fechaOperacion: fechaOperacion,
      historial: [entrada],
      fechaEmision: DateTime.now(),
      fechaVencimiento: DateTime.now().add(Duration(days: diasVencimiento)),
    );

    // VALIDACIÓN FISCAL INTEGRAL (R1-R9)
    // Obtener config real de la empresa desde Firestore
    final empresaConfig = await EmpresaConfigService().obtenerConfig(empresaId);

    // Obtener facturas del trimestre actual para validación de correlatividad
    final ahora = DateTime.now();
    final inicioTrimestre = DateTime(ahora.year, ((ahora.month - 1) ~/ 3) * 3 + 1, 1);
    final facturasTrimestreSnap = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioTrimestre))
        .orderBy('fecha_emision')
        .get();
    final facturasDelPeriodo =
        facturasTrimestreSnap.docs.map(Factura.fromFirestore).toList();

    final resultadoValidacion = ValidadorFiscalIntegral.validarFacturaCompleta(
      factura,
      empresaConfig,
      facturasDelPeriodo,
    );

    // Si hay errores bloqueantes, lanzar excepción
    if (resultadoValidacion.errores.isNotEmpty) {
      _log.e('Validación fiscal falló: ${resultadoValidacion.errores}');
      throw Exception(
        'Error de validación fiscal: ${resultadoValidacion.errores.first}',
      );
    }

    // Registrar advertencias (pero permitir continuar)
    if (resultadoValidacion.advertencias.isNotEmpty) {
      _log.w('Advertencias fiscales: ${resultadoValidacion.advertencias}');
    }

    await docRef.set(factura.toFirestore());

    // Registrar en Verifactu automáticamente (si está habilitado)
    // No interrumpe el flujo si falla — la factura se guarda siempre
    bool verifactuOk = false;
    bool verifactuError = false;
    String mensajeVerifactu = '';
    try {
      await VerifactuService.registrarFactura(
        empresaId: empresaId,
        factura: factura,
      );
      verifactuOk = true;
      mensajeVerifactu = '✅ Factura registrada en VeriFactu correctamente';
    } catch (e) {
      _log.d('Verifactu no configurado o deshabilitado: $e');
    }

    return ResultadoCrearFactura(
      factura: factura,
      verifactuOk: verifactuOk,
      verifactuError: verifactuError,
      mensajeVerifactu: mensajeVerifactu,
    );
  }

  // ── EDITAR FACTURA PENDIENTE ──────────────────────────────────────────────

  Future<Factura> editarFactura({
    required String empresaId,
    required String facturaId,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteCorreo,
    DatosFiscales? datosFiscales,
    List<LineaFactura>? lineas,
    MetodoPagoFactura? metodoPago,
    String? notasInternas,
    String? notasCliente,
    DateTime? fechaOperacion,
    int? diasVencimiento,
    double? descuentoGlobal,
    double? porcentajeIrpf,
    String usuarioId = '',
    String usuarioNombre = '',
  }) async {
    final doc = await _facturas(empresaId).doc(facturaId).get();
    if (!doc.exists) throw Exception('Factura no encontrada');
    final factura = Factura.fromFirestore(doc);

    if (factura.estado != EstadoFactura.pendiente) {
      throw Exception('Solo se pueden editar facturas pendientes');
    }

    final nuevasLineas = lineas ?? factura.lineas;
    final nuevoDescGlobal = descuentoGlobal ?? factura.descuentoGlobal;
    final nuevoIrpf = porcentajeIrpf ?? factura.porcentajeIrpf;
    final nuevoDias = diasVencimiento ?? factura.diasVencimiento;

    final totales = Factura.calcularTotales(
      lineas: nuevasLineas,
      descuentoGlobal: nuevoDescGlobal,
      porcentajeIrpf: nuevoIrpf,
    );

    final entrada = EntradaHistorialFactura(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'editada',
      descripcion: 'Factura editada',
      fecha: DateTime.now(),
    );

    final updated = factura.copyWith(
      clienteNombre: clienteNombre ?? factura.clienteNombre,
      clienteTelefono: clienteTelefono ?? factura.clienteTelefono,
      clienteCorreo: clienteCorreo ?? factura.clienteCorreo,
      datosFiscales: datosFiscales ?? factura.datosFiscales,
      lineas: nuevasLineas,
      subtotal: totales['subtotal']!,
      totalIva: totales['total_iva']!,
      total: totales['total']!,
      descuentoGlobal: nuevoDescGlobal,
      importeDescuentoGlobal: totales['importe_descuento_global']!,
      porcentajeIrpf: nuevoIrpf,
      retencionIrpf: totales['retencion_irpf']!,
      totalRecargoEquivalencia: totales['total_recargo_equivalencia']!,
      diasVencimiento: nuevoDias,
      metodoPago: metodoPago ?? factura.metodoPago,
      notasInternas: notasInternas ?? factura.notasInternas,
      notasCliente: notasCliente ?? factura.notasCliente,
      fechaOperacion: fechaOperacion ?? factura.fechaOperacion,
      historial: [...factura.historial, entrada],
      fechaVencimiento: factura.fechaEmision.add(Duration(days: nuevoDias)),
      fechaActualizacion: DateTime.now(),
    );

    await _facturas(empresaId).doc(facturaId).set(updated.toFirestore());
    return updated;
  }

  // ── CREAR FACTURA RECTIFICATIVA (Art. 15 RD 1619/2012) ────────────────

  /// Crea una factura rectificativa completa según normativa fiscal española.
  ///
  /// [metodo]: sustitucion → incluye importes correctos completos;
  ///           diferencias → solo la diferencia respecto a la original.
  /// [lineasCorregidas]: líneas con los importes finales correctos (sustitución)
  ///                     o con las diferencias (positivas/negativas).
  ///                     Si es null en modo sustitución, se copian invertidas.
  Future<Factura> crearFacturaRectificativa({
    required String empresaId,
    required String facturaOriginalId,
    required MotivoRectificacion motivo,
    required MetodoRectificacion metodo,
    String motivoTexto = '',
    List<LineaFactura>? lineasCorregidas,
    DatosFiscales? datosFiscalesCorregidos,
    String usuarioId = '',
    String usuarioNombre = '',
  }) async {
    final doc = await _facturas(empresaId).doc(facturaOriginalId).get();
    if (!doc.exists) throw Exception('Factura original no encontrada');
    final original = Factura.fromFirestore(doc);

    if (original.esAnulada) {
      throw Exception('No se puede rectificar una factura anulada');
    }

    // Determinar las líneas de la rectificativa
    List<LineaFactura> lineasRect;
    if (lineasCorregidas != null && lineasCorregidas.isNotEmpty) {
      lineasRect = lineasCorregidas;
    } else {
      // Por defecto: invertir importes de la original (devolución total)
      lineasRect = original.lineas
          .map((l) => LineaFactura(
                descripcion: '[RECT] ${l.descripcion}',
                precioUnitario: -l.precioUnitario,
                cantidad: l.cantidad,
                porcentajeIva: l.porcentajeIva,
                referencia: l.referencia,
                descuento: l.descuento,
                recargoEquivalencia: l.recargoEquivalencia,
              ))
          .toList();
    }

    // Generar número con serie RECT
    final serie = SerieFactura.rect;
    final numero = await _generarNumeroFacturaSerie(empresaId, serie);

    // Calcular totales
    final totales = Factura.calcularTotales(
      lineas: lineasRect,
      descuentoGlobal: original.descuentoGlobal,
      porcentajeIrpf: original.porcentajeIrpf,
    );

    final entrada = EntradaHistorialFactura(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'creada',
      descripcion: 'Factura rectificativa creada. '
          'Rectifica a ${original.numeroFactura}. '
          'Motivo: ${motivo.etiqueta}${motivoTexto.isNotEmpty ? " – $motivoTexto" : ""}',
      fecha: DateTime.now(),
    );

    final docRef = _facturas(empresaId).doc();
    final factura = Factura(
      id: docRef.id,
      empresaId: empresaId,
      numeroFactura: numero,
      serie: serie,
      tipo: TipoFactura.rectificativa,
      estado: EstadoFactura.pendiente,
      clienteNombre: original.clienteNombre,
      clienteTelefono: original.clienteTelefono,
      clienteCorreo: original.clienteCorreo,
      datosFiscales: datosFiscalesCorregidos ?? original.datosFiscales,
      lineas: lineasRect,
      subtotal: totales['subtotal']!,
      totalIva: totales['total_iva']!,
      total: totales['total']!,
      descuentoGlobal: original.descuentoGlobal,
      importeDescuentoGlobal: totales['importe_descuento_global']!,
      porcentajeIrpf: original.porcentajeIrpf,
      retencionIrpf: totales['retencion_irpf']!,
      totalRecargoEquivalencia: totales['total_recargo_equivalencia']!,
      diasVencimiento: original.diasVencimiento,
      metodoPago: original.metodoPago,
      facturaOriginalId: original.id,
      facturaOriginalNumero: original.numeroFactura,
      facturaOriginalFecha: original.fechaEmision,
      motivoRectificacion: motivo,
      metodoRectificacion: metodo,
      motivoRectificacionTexto: motivoTexto,
      notasInternas: 'Rectificativa de ${original.numeroFactura}. '
          'Método: ${metodo.etiqueta}. Motivo: ${motivo.etiqueta}'
          '${motivoTexto.isNotEmpty ? " – $motivoTexto" : ""}',
      notasCliente: original.notasCliente,
      historial: [entrada],
      fechaEmision: DateTime.now(),
      fechaVencimiento: DateTime.now().add(Duration(days: original.diasVencimiento)),
    );

    await docRef.set(factura.toFirestore());

    // Marcar la factura original como rectificada (no se anula, Art. 15)
    final entradaOriginal = EntradaHistorialFactura(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'rectificada',
      descripcion: 'Rectificada por factura $numero',
      fecha: DateTime.now(),
    );
    await _facturas(empresaId).doc(facturaOriginalId).update({
      'estado': EstadoFactura.rectificada.name,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entradaOriginal.toMap()]),
    });

    // Registrar en Verifactu
    try {
      await VerifactuService.registrarFactura(
        empresaId: empresaId,
        factura: factura,
      );
    } catch (_) {}

    return factura;
  }

  // ── CREAR PROFORMA ──────────────────────────────────────────────────────

  Future<ResultadoCrearFactura> crearProforma({
    required String empresaId,
    required String clienteNombre,
    String? clienteTelefono,
    String? clienteCorreo,
    DatosFiscales? datosFiscales,
    required List<LineaFactura> lineas,
    String? notasCliente,
    int diasVencimiento = 30,
    double descuentoGlobal = 0,
    double porcentajeIrpf = 0,
    String usuarioId = '',
    String usuarioNombre = '',
  }) async {
    return crearFactura(
      empresaId: empresaId,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteCorreo: clienteCorreo,
      datosFiscales: datosFiscales,
      lineas: lineas,
      tipo: TipoFactura.proforma,
      notasCliente: notasCliente,
      diasVencimiento: diasVencimiento,
      descuentoGlobal: descuentoGlobal,
      porcentajeIrpf: porcentajeIrpf,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
    );
  }

  // ── DUPLICAR FACTURA ────────────────────────────────────────────────────

  Future<ResultadoCrearFactura> duplicarFactura({
    required String empresaId,
    required String facturaId,
    String usuarioId = '',
    String usuarioNombre = '',
  }) async {
    final doc = await _facturas(empresaId).doc(facturaId).get();
    if (!doc.exists) throw Exception('Factura no encontrada');
    final original = Factura.fromFirestore(doc);

    return crearFactura(
      empresaId: empresaId,
      clienteNombre: original.clienteNombre,
      clienteTelefono: original.clienteTelefono,
      clienteCorreo: original.clienteCorreo,
      datosFiscales: original.datosFiscales,
      lineas: original.lineas,
      metodoPago: original.metodoPago,
      tipo: original.tipo == TipoFactura.rectificativa
          ? TipoFactura.venta_directa
          : original.tipo,
      notasInternas: 'Duplicada de ${original.numeroFactura}',
      notasCliente: original.notasCliente,
      diasVencimiento: original.diasVencimiento,
      descuentoGlobal: original.descuentoGlobal,
      porcentajeIrpf: original.porcentajeIrpf,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
    );
  }

  // ── CONVERTIR PROFORMA A FACTURA ──────────────────────────────────────────

  Future<ResultadoCrearFactura> convertirProformaAFactura({
    required String empresaId,
    required String proformaId,
    String usuarioId = '',
    String usuarioNombre = '',
  }) async {
    final doc = await _facturas(empresaId).doc(proformaId).get();
    if (!doc.exists) throw Exception('Proforma no encontrada');
    final proforma = Factura.fromFirestore(doc);

    if (proforma.tipo != TipoFactura.proforma) {
      throw Exception('Solo se pueden convertir proformas');
    }

    // Anular la proforma
    await anularFactura(
      empresaId: empresaId,
      facturaId: proformaId,
      motivo: 'Convertida a factura definitiva',
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
    );

    // Crear factura definitiva
    return crearFactura(
      empresaId: empresaId,
      clienteNombre: proforma.clienteNombre,
      clienteTelefono: proforma.clienteTelefono,
      clienteCorreo: proforma.clienteCorreo,
      datosFiscales: proforma.datosFiscales,
      lineas: proforma.lineas,
      metodoPago: proforma.metodoPago,
      tipo: TipoFactura.venta_directa,
      notasInternas: 'Generada desde proforma ${proforma.numeroFactura}',
      notasCliente: proforma.notasCliente,
      diasVencimiento: proforma.diasVencimiento,
      descuentoGlobal: proforma.descuentoGlobal,
      porcentajeIrpf: proforma.porcentajeIrpf,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
    );
  }

  // ── DETECTAR FACTURAS VENCIDAS ────────────────────────────────────────────

  Future<int> detectarYMarcarVencidas(String empresaId) async {
    final ahora = DateTime.now();
    final snap = await _facturas(empresaId)
        .where('estado', isEqualTo: EstadoFactura.pendiente.name)
        .get();

    int marcadas = 0;
    final batch = _firestore.batch();

    for (final doc in snap.docs) {
      final factura = Factura.fromFirestore(doc);
      if (factura.fechaVencimiento != null &&
          ahora.isAfter(factura.fechaVencimiento!)) {
        batch.update(doc.reference, {
          'estado': EstadoFactura.vencida.name,
          'fecha_actualizacion': Timestamp.fromDate(ahora),
          'historial': FieldValue.arrayUnion([
            EntradaHistorialFactura(
              usuarioId: 'sistema',
              usuarioNombre: 'Sistema',
              accion: 'vencida',
              descripcion: 'Factura marcada como vencida automáticamente',
              fecha: ahora,
            ).toMap(),
          ]),
        });
        marcadas++;
      }
    }

    if (marcadas > 0) await batch.commit();
    return marcadas;
  }

  // ── ACTUALIZAR ESTADO ──────────────────────────────────────────────────────

  Future<void> actualizarEstado({
    required String empresaId,
    required String facturaId,
    required EstadoFactura nuevoEstado,
    MetodoPagoFactura? metodoPago,
    String usuarioId = '',
    String usuarioNombre = '',
  }) async {
    final entrada = EntradaHistorialFactura(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'estado_actualizado',
      descripcion: 'Estado cambiado a ${nuevoEstado.etiqueta}',
      fecha: DateTime.now(),
    );

    final data = <String, dynamic>{
      'estado': nuevoEstado.name,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entrada.toMap()]),
    };

    if (nuevoEstado == EstadoFactura.pagada) {
      data['fecha_pago'] = Timestamp.fromDate(DateTime.now());
      if (metodoPago != null) data['metodo_pago'] = metodoPago.name;
    }

    await _facturas(empresaId).doc(facturaId).update(data);
  }

  // ── ANULAR FACTURA ─────────────────────────────────────────────────────────

  Future<void> anularFactura({
    required String empresaId,
    required String facturaId,
    required String motivo,
    String usuarioId = '',
    String usuarioNombre = '',
  }) async {
    final entrada = EntradaHistorialFactura(
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      accion: 'anulada',
      descripcion: 'Factura anulada. Motivo: $motivo',
      fecha: DateTime.now(),
    );

    await _facturas(empresaId).doc(facturaId).update({
      'estado': EstadoFactura.anulada.name,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      'historial': FieldValue.arrayUnion([entrada.toMap()]),
    });
  }

  // ── ACTUALIZAR NOTAS ───────────────────────────────────────────────────────

  Future<void> actualizarNotas({
    required String empresaId,
    required String facturaId,
    String? notasInternas,
    String? notasCliente,
  }) async {
    await _facturas(empresaId).doc(facturaId).update({
      'notas_internas': notasInternas,
      'notas_cliente': notasCliente,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── STREAMS ────────────────────────────────────────────────────────────────

  Stream<List<Factura>> obtenerFacturas(String empresaId) {
    return _facturas(empresaId)
        .orderBy('fecha_emision', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Factura.fromFirestore).toList());
  }

  Stream<List<Factura>> obtenerFacturasPorEstado(
      String empresaId, EstadoFactura estado) {
    return _facturas(empresaId)
        .where('estado', isEqualTo: estado.name)
        .orderBy('fecha_emision', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Factura.fromFirestore).toList());
  }

  Stream<List<Factura>> obtenerFacturasVencidas(String empresaId) {
    return _facturas(empresaId)
        .orderBy('fecha_emision', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(Factura.fromFirestore)
            .where((f) => f.estado == EstadoFactura.vencida || f.estaVencida)
            .toList());
  }

  Stream<List<Factura>> obtenerFacturasDeHoy(String empresaId) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));

    return _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .snapshots()
        .map((snap) {
          final lista = snap.docs.map(Factura.fromFirestore).toList()
            ..sort((a, b) => b.fechaEmision.compareTo(a.fechaEmision));
          return lista;
        });
  }

  Stream<List<Factura>> obtenerFacturasDelMes(String empresaId) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, 1);
    final fin = DateTime(hoy.year, hoy.month + 1, 1);

    return _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .snapshots()
        .map((snap) {
          final lista = snap.docs.map(Factura.fromFirestore).toList()
            ..sort((a, b) => b.fechaEmision.compareTo(a.fechaEmision));
          return lista;
        });
  }

  // ── ESTADÍSTICAS ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> calcularEstadisticas(String empresaId) async {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final inicioMes = DateTime(hoy.year, hoy.month, 1);
    final inicioAnio = DateTime(hoy.year, 1, 1);

    final snapMes = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
        .get();

    final snapAnio = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioAnio))
        .get();

    final snapHoy = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .get();

    final facturasMes = snapMes.docs.map(Factura.fromFirestore).toList();
    final facturasAnio = snapAnio.docs.map(Factura.fromFirestore).toList();
    final facturasHoy = snapHoy.docs.map(Factura.fromFirestore).toList();

    final pagadasMes = facturasMes.where((f) => f.esPagada).toList();
    final pagadasAnio = facturasAnio.where((f) => f.esPagada).toList();
    final pagadasHoy = facturasHoy.where((f) => f.esPagada).toList();
    final pendientesMes = facturasMes.where((f) => f.esPendiente).toList();
    final vencidasMes = facturasMes.where((f) => f.estado == EstadoFactura.vencida || f.estaVencida).toList();

    return {
      'total_hoy': pagadasHoy.fold(0.0, (s, f) => s + f.total),
      'total_mes': pagadasMes.fold(0.0, (s, f) => s + f.total),
      'total_anio': pagadasAnio.fold(0.0, (s, f) => s + f.total),
      'iva_mes': pagadasMes.fold(0.0, (s, f) => s + f.totalIva),
      'iva_anio': pagadasAnio.fold(0.0, (s, f) => s + f.totalIva),
      'irpf_retenido_mes': pagadasMes.fold(0.0, (s, f) => s + f.retencionIrpf),
      'irpf_retenido_anio': pagadasAnio.fold(0.0, (s, f) => s + f.retencionIrpf),
      'recargo_equiv_mes': pagadasMes.fold(0.0, (s, f) => s + f.totalRecargoEquivalencia),
      'num_facturas_hoy': facturasHoy.length,
      'num_facturas_mes': facturasMes.length,
      'num_facturas_anio': facturasAnio.length,
      'num_pendientes': pendientesMes.length,
      'num_pagadas_mes': pagadasMes.length,
      'num_vencidas': vencidasMes.length,
      'num_rectificativas_mes': facturasMes.where((f) => f.esRectificativa).length,
    };
  }

  // ── RESUMEN MENSUAL PARA IMPUESTOS ─────────────────────────────────────────

  Future<Map<String, dynamic>> generarResumenMensual(
      String empresaId, int mes, int anio) async {
    final inicio = DateTime(anio, mes, 1);
    final fin = DateTime(anio, mes + 1, 1);
    final criterio = await obtenerCriterioIVA(empresaId);

    final snap = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.subtract(const Duration(days: 90))))
        .get();

    final facturas = snap.docs.map(Factura.fromFirestore).toList();
    final consideradas = facturas
        .where((f) => _incluyeFacturaPorCriterio(f, criterio, inicio, fin))
        .where((f) => !_esFacturaIntracomunitaria(f))
        .toList();
    final rectificativas = consideradas.where((f) => f.esRectificativa).toList();

    return {
      'mes': mes,
      'anio': anio,
      'criterio_iva': criterio.name,
      'total_facturas': consideradas.length,
      'total_pagadas': consideradas.where((f) => f.esPagada).length,
      'total_pendientes': consideradas.where((f) => f.esPendiente).length,
      'total_anuladas': consideradas.where((f) => f.estado == EstadoFactura.anulada).length,
      'total_vencidas': consideradas.where((f) => f.estado == EstadoFactura.vencida).length,
      'total_rectificativas': rectificativas.length,
      'base_imponible': consideradas.fold(0.0, (s, f) => s + f.subtotal),
      'total_iva': consideradas.fold(0.0, (s, f) => s + f.totalIva),
      'total_irpf_retenido': consideradas.fold(0.0, (s, f) => s + f.retencionIrpf),
      'total_recargo_equivalencia': consideradas.fold(0.0, (s, f) => s + f.totalRecargoEquivalencia),
      'total_facturado': consideradas.fold(0.0, (s, f) => s + f.total),
      'por_metodo_pago': _agruparPorMetodoPago(consideradas),
    };
  }

  Future<Map<String, dynamic>> generarResumenTrimestral(
    String empresaId,
    int trimestre,
    int anio,
  ) async {
    final mesInicio = (trimestre - 1) * 3 + 1;
    final inicio = DateTime(anio, mesInicio, 1);
    final fin = DateTime(anio, mesInicio + 3, 1);
    final criterio = await obtenerCriterioIVA(empresaId);

    final snap = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.subtract(const Duration(days: 120))))
        .get();

    final facturas = snap.docs.map(Factura.fromFirestore).toList();
    final consideradas = facturas
        .where((f) => _incluyeFacturaPorCriterio(f, criterio, inicio, fin))
        .toList();

    return {
      'trimestre': trimestre,
      'anio': anio,
      'criterio_iva': criterio.name,
      'total_facturas': consideradas.length,
      'base_imponible': consideradas.fold(0.0, (s, f) => s + f.subtotal),
      'total_iva': consideradas.fold(0.0, (s, f) => s + f.totalIva),
      'total_irpf_retenido': consideradas.fold(0.0, (s, f) => s + f.retencionIrpf),
      'total_facturado': consideradas.fold(0.0, (s, f) => s + f.total),
    };
  }

  Future<Map<String, dynamic>> calcularMod303(
    String empresaId,
    int trimestre,
    int anio,
  ) async {
    final mesInicio = (trimestre - 1) * 3 + 1;
    final inicio = DateTime(anio, mesInicio, 1);
    final fin = DateTime(anio, mesInicio + 3, 1);
    final criterio = await obtenerCriterioIVA(empresaId);

    final emitidasSnap = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.subtract(const Duration(days: 120))))
        .get();
    final recibidasSnap = await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas_recibidas')
        .where('fecha_recepcion',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.subtract(const Duration(days: 120))))
        .get();

    final emitidas = emitidasSnap.docs
        .map(Factura.fromFirestore)
        .where((f) => _incluyeFacturaPorCriterio(f, criterio, inicio, fin))
        .where((f) => !_esFacturaIntracomunitaria(f))
        .toList();
    final recibidas = recibidasSnap.docs
        .map((d) => FacturaRecibida.fromFirestore(d))
        .where((f) => _incluyeFacturaRecibidaPorCriterio(f, criterio, inicio, fin))
        .where((f) => !_esFacturaRecibidaIntracomunitaria(f))
        .toList();

    final ivaRepercutido = emitidas.fold(0.0, (s, f) => s + f.totalIva);
    final ivaSoportado = recibidas
        .where((f) => f.ivaDeducible)
        .fold(0.0, (s, f) => s + f.importeIva);

    return {
      'trimestre': trimestre,
      'anio': anio,
      'criterio_iva': criterio.name,
      'iva_repercutido': ivaRepercutido,
      'iva_soportado': ivaSoportado,
      'resultado_303': ivaRepercutido - ivaSoportado,
      'num_emitidas': emitidas.length,
      'num_recibidas': recibidas.length,
    };
  }

  Future<Map<String, dynamic>> calcularMod111(
    String empresaId,
    int trimestre,
    int anio,
  ) async {
    final mesInicio = (trimestre - 1) * 3 + 1;
    final inicio = DateTime(anio, mesInicio, 1);
    final fin = DateTime(anio, mesInicio + 3, 1);
    final criterio = await obtenerCriterioIVA(empresaId);

    final snap = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.subtract(const Duration(days: 120))))
        .get();

    final facturas = snap.docs
        .map(Factura.fromFirestore)
        .where((f) => _incluyeFacturaPorCriterio(f, criterio, inicio, fin))
        .toList();

    final conRetencion = facturas.where((f) => f.retencionIrpf > 0).toList();
    final baseRetenciones = conRetencion.fold(0.0, (s, f) => s + f.subtotal);
    final totalRetenido = conRetencion.fold(0.0, (s, f) => s + f.retencionIrpf);

    return {
      'trimestre': trimestre,
      'anio': anio,
      'criterio_iva': criterio.name,
      'num_perceptores': conRetencion.length,
      'base_retenciones': baseRetenciones,
      'total_retenido': totalRetenido,
    };
  }

  Map<String, double> _agruparPorMetodoPago(List<Factura> facturas) {
    final mapa = <String, double>{};
    for (final f in facturas) {
      if (f.metodoPago != null) {
        final key = f.metodoPago!.etiqueta;
        mapa[key] = (mapa[key] ?? 0) + f.total;
      }
    }
    return mapa;
  }

  // ── CRITERIO IVA ───────────────────────────────────────────────────────────

  Future<CriterioIVA> obtenerCriterioIVA(String empresaId) async {
    final fiscalDoc = await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('fiscal')
        .get();

    final valor = (fiscalDoc.data()?['criterio_iva'] as String?) ?? 'devengo';
    return CriterioIVA.values.firstWhere(
      (e) => e.name == valor,
      orElse: () => CriterioIVA.devengo,
    );
  }

  Future<void> guardarCriterioIVA(String empresaId, CriterioIVA criterio) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('fiscal')
        .set({'criterio_iva': criterio.name}, SetOptions(merge: true));
  }

  bool _incluyeFacturaPorCriterio(
    Factura f,
    CriterioIVA criterio,
    DateTime inicio,
    DateTime fin,
  ) {
    if (f.estado == EstadoFactura.anulada) return false;
    final fecha = criterio == CriterioIVA.caja ? f.fechaPago : f.fechaEmision;
    if (fecha == null) return false;
    return !fecha.isBefore(inicio) && fecha.isBefore(fin);
  }

  bool _incluyeFacturaRecibidaPorCriterio(
    FacturaRecibida f,
    CriterioIVA criterio,
    DateTime inicio,
    DateTime fin,
  ) {
    if (f.estado == EstadoFacturaRecibida.rechazada) return false;
    final fecha = criterio == CriterioIVA.caja ? f.fechaPago : f.fechaRecepcion;
    if (fecha == null) return false;
    return !fecha.isBefore(inicio) && fecha.isBefore(fin);
  }

  bool _esFacturaIntracomunitaria(Factura f) {
    final datos = f.datosFiscales;
    if (datos == null) return false;
    if (datos.esIntracomunitario) return true;
    if ((datos.nifIvaComunitario ?? '').trim().isNotEmpty) return true;
    final pais = (datos.pais ?? '').trim().toUpperCase();
    if (pais.isNotEmpty && pais != 'ESPANA' && pais != 'ES') return true;
    return _tienePrefijoVatEu(datos.nif ?? '');
  }

  bool _esFacturaRecibidaIntracomunitaria(FacturaRecibida f) {
    if (f.esIntracomunitario) return true;
    if ((f.nifIvaComunitario ?? '').trim().isNotEmpty) return true;
    return _tienePrefijoVatEu(f.nifProveedor);
  }

  bool _tienePrefijoVatEu(String value) {
    final limpio = value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (limpio.length < 2) return false;
    final prefijo = limpio.substring(0, 2);
    const codigos = {
      'AT','BE','BG','CY','HR','CZ','DE','DK','EE','EL','FI','FR','GB','HU',
      'IE','IT','LT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK','XI'
    };
    return codigos.contains(prefijo);
  }

  // ── HISTORIAL POR CLIENTE ─────────────────────────────────────────────────

  /// Devuelve todas las facturas emitidas a un cliente concreto.
  /// Busca por [clienteNombre] y, si se proporciona, también por [clienteCorreo]
  /// (fusionando resultados y eliminando duplicados).
  /// El resultado viene ordenado por fecha de emisión descendente.
  Future<List<Factura>> facturasPorCliente({
    required String empresaId,
    required String clienteNombre,
    String? clienteCorreo,
  }) async {
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    // Consulta por nombre
    futures.add(
      _facturas(empresaId)
          .where('cliente_nombre', isEqualTo: clienteNombre)
          .orderBy('fecha_emision', descending: true)
          .get(),
    );

    // Consulta adicional por correo (captura facturas donde cambió el nombre)
    if (clienteCorreo != null && clienteCorreo.isNotEmpty) {
      futures.add(
        _facturas(empresaId)
            .where('cliente_correo', isEqualTo: clienteCorreo)
            .orderBy('fecha_emision', descending: true)
            .get(),
      );
    }

    final snapshots = await Future.wait(futures);
    final seen = <String>{};
    final result = <Factura>[];

    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) {
          result.add(Factura.fromFirestore(doc));
        }
      }
    }

    result.sort((a, b) => b.fechaEmision.compareTo(a.fechaEmision));
    return result;
  }

  /// Resumen estadístico de las facturas de un cliente.
  /// Devuelve: totalFacturado, pendienteCobro, totalFacturas,
  /// ultimaFactura (o null), facturacionMensual (Map mes→importe, últimos 6 meses).
  Future<Map<String, dynamic>> resumenClienteFacturas({
    required String empresaId,
    required String clienteNombre,
    String? clienteCorreo,
  }) async {
    final facturas = await facturasPorCliente(
      empresaId: empresaId,
      clienteNombre: clienteNombre,
      clienteCorreo: clienteCorreo,
    );

    final activas = facturas
        .where((f) => f.estado != EstadoFactura.anulada)
        .toList();

    final totalFacturado =
        activas.fold(0.0, (s, f) => s + f.total);
    final pendienteCobro = activas
        .where((f) =>
            f.estado == EstadoFactura.pendiente ||
            f.estado == EstadoFactura.vencida)
        .fold(0.0, (s, f) => s + f.total);

    // Facturación de los últimos 6 meses (clave: 'yyyy-MM')
    final ahora = DateTime.now();
    final facturacionMensual = <String, double>{};
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(ahora.year, ahora.month - i, 1);
      facturacionMensual['${m.year}-${m.month.toString().padLeft(2, '0')}'] = 0.0;
    }
    for (final f in activas) {
      final key =
          '${f.fechaEmision.year}-${f.fechaEmision.month.toString().padLeft(2, '0')}';
      if (facturacionMensual.containsKey(key)) {
        facturacionMensual[key] = (facturacionMensual[key] ?? 0) + f.total;
      }
    }

    return {
      'facturas': facturas,
      'total_facturado': totalFacturado,
      'pendiente_cobro': pendienteCobro,
      'total_facturas': facturas.length,
      'ultima_factura': facturas.isNotEmpty ? facturas.first : null,
      'facturacion_mensual': facturacionMensual,
    };
  }

  // ── CREAR FACTURA DESDE PEDIDO ────────────────────────────────────────────

  Future<ResultadoCrearFactura> crearFacturaDesdePedido({
    required String empresaId,
    required String pedidoId,
    required String clienteNombre,
    String? clienteTelefono,
    String? clienteCorreo,
    required List<Map<String, dynamic>> lineasPedido,
    double porcentajeIva = 21.0,
    String usuarioId = '',
    String usuarioNombre = '',
  }) async {
    final lineas = lineasPedido
        .map((l) => LineaFactura(
              descripcion: l['producto_nombre'] ?? '',
              precioUnitario: (l['precio_unitario'] as num?)?.toDouble() ?? 0,
              cantidad: (l['cantidad'] as num?)?.toInt() ?? 1,
              porcentajeIva: porcentajeIva,
            ))
        .toList();

    return crearFactura(
      empresaId: empresaId,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteCorreo: clienteCorreo,
      lineas: lineas,
      pedidoId: pedidoId,
      tipo: TipoFactura.pedido,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
    );
  }
}



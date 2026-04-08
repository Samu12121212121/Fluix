import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/contabilidad.dart';
import '../domain/modelos/factura.dart';
import '../domain/modelos/factura_recibida.dart';
import '../core/utils/validador_nif_cif.dart';

/// Servicio central de contabilidad.
/// Gestiona gastos, proveedores, libros contables y exportación CSV.
class ContabilidadService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── REFS ──────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _gastos(String e) =>
      _db.collection('empresas').doc(e).collection('gastos');

  CollectionReference<Map<String, dynamic>> _proveedores(String e) =>
      _db.collection('empresas').doc(e).collection('proveedores');

  CollectionReference<Map<String, dynamic>> _facturas(String e) =>
      _db.collection('empresas').doc(e).collection('facturas');

  CollectionReference<Map<String, dynamic>> _facturasRecibidas(String e) =>
      _db.collection('empresas').doc(e).collection('facturas_recibidas');

  // ═════════════════════════════════════════════════════════════════════════
  // PROVEEDORES
  // ═════════════════════════════════════════════════════════════════════════

  Stream<List<Proveedor>> obtenerProveedores(String empresaId) {
    return _proveedores(empresaId)
        .orderBy('nombre')
        .snapshots()
        .map((s) => s.docs
            .map((d) => Proveedor.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<Proveedor> guardarProveedor(
      String empresaId, Proveedor proveedor) async {
    final ref = proveedor.id.isEmpty
        ? _proveedores(empresaId).doc()
        : _proveedores(empresaId).doc(proveedor.id);

    final data = proveedor.toMap();
    data['id'] = ref.id;
    await ref.set(data, SetOptions(merge: true));

    return Proveedor.fromMap(data);
  }

  Future<void> eliminarProveedor(String empresaId, String proveedorId) =>
      _proveedores(empresaId).doc(proveedorId).delete();

  // ═════════════════════════════════════════════════════════════════════════
  // GASTOS
  // ═════════════════════════════════════════════════════════════════════════

  Stream<List<Gasto>> obtenerGastos(String empresaId) {
    return _gastos(empresaId)
        .orderBy('fecha_gasto', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Gasto.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<Gasto>> obtenerGastosPorPeriodo(
      String empresaId, DateTime inicio, DateTime fin) {
    return _gastos(empresaId)
        .where('fecha_gasto',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_gasto', isLessThan: Timestamp.fromDate(fin))
        .snapshots()
        .map((s) {
          final lista = s.docs
              .map((d) => Gasto.fromMap({...d.data(), 'id': d.id}))
              .toList()
            ..sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));
          return lista;
        });
  }

  Future<Gasto> guardarGasto(String empresaId, {
    required String concepto,
    required CategoriaGasto categoria,
    String? proveedorId,
    String? proveedorNombre,
    String? numeroFacturaProveedor,
    required double baseImponible,
    double porcentajeIva = 21.0,
    bool ivaDeducible = true,
    required DateTime fechaGasto,
    String? metodoPago,
    String? notas,
    String creadoPor = '',
    String? gastoIdEditar,
  }) async {
    final importeIva = ivaDeducible ? baseImponible * (porcentajeIva / 100) : 0.0;
    final total = baseImponible + importeIva;

    final ref = (gastoIdEditar != null && gastoIdEditar.isNotEmpty)
        ? _gastos(empresaId).doc(gastoIdEditar)
        : _gastos(empresaId).doc();

    final gasto = Gasto(
      id: ref.id,
      empresaId: empresaId,
      concepto: concepto,
      categoria: categoria,
      proveedorId: proveedorId,
      proveedorNombre: proveedorNombre,
      numeroFacturaProveedor: numeroFacturaProveedor,
      baseImponible: baseImponible,
      porcentajeIva: ivaDeducible ? porcentajeIva : 0,
      importeIva: importeIva,
      total: total,
      ivaDeducible: ivaDeducible,
      fechaGasto: fechaGasto,
      metodoPago: metodoPago,
      notas: notas,
      fechaCreacion: DateTime.now(),
      creadoPor: creadoPor,
    );

    await ref.set(gasto.toMap(), SetOptions(merge: true));

    // Actualizar cache mensual
    await _actualizarCacheGastos(empresaId, fechaGasto.year, fechaGasto.month,
        baseImponible, importeIva, total, gastoIdEditar == null);

    return gasto;
  }

  Future<void> pagarGasto(String empresaId, String gastoId,
      String metodoPago) async {
    await _gastos(empresaId).doc(gastoId).update({
      'estado': EstadoGasto.pagado.name,
      'fecha_pago': Timestamp.fromDate(DateTime.now()),
      'metodo_pago': metodoPago,
    });
  }

  Future<void> eliminarGasto(String empresaId, String gastoId) =>
      _gastos(empresaId).doc(gastoId).delete();

  // ═════════════════════════════════════════════════════════════════════════
  // CACHE CONTABLE — documento por mes para lecturas ultrarrápidas
  // estructura: empresas/{e}/cache_contable/{YYYY-MM}
  // ═════════════════════════════════════════════════════════════════════════

  DocumentReference<Map<String, dynamic>> _cacheContable(
          String e, int anio, int mes) =>
      _db
          .collection('empresas')
          .doc(e)
          .collection('cache_contable')
          .doc('$anio-${mes.toString().padLeft(2, '0')}');

  Future<void> _actualizarCacheGastos(String empresaId, int anio, int mes,
      double base, double iva, double total, bool esNuevo) async {
    await _cacheContable(empresaId, anio, mes).set({
      'gastos_base': FieldValue.increment(base),
      'gastos_iva_soportado': FieldValue.increment(iva),
      'gastos_total': FieldValue.increment(total),
      if (esNuevo) 'num_gastos': FieldValue.increment(1),
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> actualizarCacheIngresos(String empresaId, int anio, int mes,
      double base, double iva, double total) async {
    await _cacheContable(empresaId, anio, mes).set({
      'ingresos_base': FieldValue.increment(base),
      'iva_repercutido': FieldValue.increment(iva),
      'ingresos_total': FieldValue.increment(total),
      'num_facturas': FieldValue.increment(1),
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // RESUMEN CONTABLE — calcula todo para un periodo
  // ═════════════════════════════════════════════════════════════════════════

  Future<ResumenContable> calcularResumen({
    required String empresaId,
    required int anio,
    int? mes,
    int? trimestre,
  }) async {
    // Determinar rango de fechas
    DateTime inicio;
    DateTime fin;

    if (mes != null) {
      inicio = DateTime(anio, mes, 1);
      fin = DateTime(anio, mes + 1, 1);
    } else if (trimestre != null) {
      final mesInicio = (trimestre - 1) * 3 + 1;
      inicio = DateTime(anio, mesInicio, 1);
      fin = DateTime(anio, mesInicio + 3, 1);
    } else {
      inicio = DateTime(anio, 1, 1);
      fin = DateTime(anio + 1, 1, 1);
    }

    // Facturas emitidas (solo pagadas para IVA devengado)
    final snapFacturas = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .get();

    final facturas = snapFacturas.docs
        .map((d) => Factura.fromFirestore(d))
        .where((f) => f.estado != EstadoFactura.anulada)
        .toList();

    final facturasPagadas = facturas.where((f) => f.esPagada).toList();

    double baseEmitida = 0, ivaRepercutido = 0, totalFacturado = 0;
    for (final f in facturasPagadas) {
      baseEmitida += f.subtotal;
      ivaRepercutido += f.totalIva;
      totalFacturado += f.total;
    }

    // Gastos — filtramos estado en Dart para evitar índice compuesto
    final snapGastos = await _gastos(empresaId)
        .where('fecha_gasto',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_gasto', isLessThan: Timestamp.fromDate(fin))
        .get();

    final gastos = snapGastos.docs
        .map((d) => Gasto.fromMap({...d.data(), 'id': d.id}))
        .where((g) => g.estado == EstadoGasto.pagado)
        .toList();

    double baseRecibida = 0, ivaSoportado = 0, totalGastado = 0;
    for (final g in gastos) {
      baseRecibida += g.baseImponible;
      if (g.ivaDeducible) ivaSoportado += g.importeIva;
      totalGastado += g.total;
    }

    return ResumenContable(
      anio: anio,
      mes: mes,
      trimestre: trimestre,
      baseImponibleEmitida: baseEmitida,
      ivaRepercutido: ivaRepercutido,
      totalFacturado: totalFacturado,
      baseImponibleRecibida: baseRecibida,
      ivaSoportado: ivaSoportado,
      totalGastado: totalGastado,
      numFacturasEmitidas: facturas.length,
      numGastos: gastos.length,
      numFacturasPendientes: facturas.where((f) => f.esPendiente).length,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // LIBRO CONTABLE — genera líneas para exportación
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<LineaLibroContable>> generarLibroEmitidas(
      String empresaId, int anio, {int? mes}) async {
    final inicio = mes != null
        ? DateTime(anio, mes, 1)
        : DateTime(anio, 1, 1);
    final fin = mes != null
        ? DateTime(anio, mes + 1, 1)
        : DateTime(anio + 1, 1, 1);

    final snap = await _facturas(empresaId)
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .get();

    final docs = snap.docs.map((d) => Factura.fromFirestore(d)).toList()
      ..sort((a, b) => a.fechaEmision.compareTo(b.fechaEmision));

    return docs.map((f) {
      return LineaLibroContable(
        tipo: 'ingreso',
        fecha: f.fechaEmision,
        numero: f.numeroFactura,
        concepto: 'Factura a ${f.clienteNombre}',
        nifContraparte: f.datosFiscales?.nif,
        nombreContraparte: f.datosFiscales?.razonSocial ?? f.clienteNombre,
        baseImponible: f.subtotal,
        porcentajeIva: f.totalIva > 0
            ? (f.totalIva / f.subtotal * 100).roundToDouble()
            : 0,
        importeIva: f.totalIva,
        total: f.total,
        estado: f.estado.etiqueta,
      );
    }).toList();
  }

  Future<List<LineaLibroContable>> generarLibroRecibidas(
      String empresaId, int anio, {int? mes}) async {
    final inicio = mes != null
        ? DateTime(anio, mes, 1)
        : DateTime(anio, 1, 1);
    final fin = mes != null
        ? DateTime(anio, mes + 1, 1)
        : DateTime(anio + 1, 1, 1);

    final snap = await _gastos(empresaId)
        .where('fecha_gasto',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_gasto', isLessThan: Timestamp.fromDate(fin))
        .get();

    final gastos = snap.docs
        .map((d) => Gasto.fromMap({...d.data(), 'id': d.id}))
        .toList()
      ..sort((a, b) => a.fechaGasto.compareTo(b.fechaGasto));

    return gastos.map((g) {
      return LineaLibroContable(
        tipo: 'gasto',
        fecha: g.fechaGasto,
        numero: g.numeroFacturaProveedor ?? '-',
        concepto: g.concepto,
        nifContraparte: null,
        nombreContraparte: g.proveedorNombre,
        baseImponible: g.baseImponible,
        porcentajeIva: g.porcentajeIva,
        importeIva: g.importeIva,
        total: g.total,
        estado: g.estado.name,
      );
    }).toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EXPORTACIÓN CSV
  // ═════════════════════════════════════════════════════════════════════════

  static const String _cabeceraCsv =
      'Tipo,Fecha,Número,Concepto,NIF Contraparte,Nombre Contraparte,'
      'Base Imponible,% IVA,Importe IVA,Total,Estado';

  /// Genera el CSV completo del libro de facturas emitidas
  Future<String> exportarLibroEmitidasCsv(String empresaId, int anio,
      {int? mes}) async {
    final lineas = await generarLibroEmitidas(empresaId, anio, mes: mes);
    final buf = StringBuffer();
    buf.writeln(_cabeceraCsv);
    for (final l in lineas) buf.writeln(l.toCsvRow());
    return buf.toString();
  }

  /// Genera el CSV completo del libro de gastos/facturas recibidas
  Future<String> exportarLibroRecibidasCsv(String empresaId, int anio,
      {int? mes}) async {
    final lineas = await generarLibroRecibidas(empresaId, anio, mes: mes);
    final buf = StringBuffer();
    buf.writeln(_cabeceraCsv);
    for (final l in lineas) buf.writeln(l.toCsvRow());
    return buf.toString();
  }

  /// Genera CSV completo (ingresos + gastos) para enviar a gestoría
  Future<String> exportarInformeGestoriaCsv(String empresaId, int anio) async {
    final emitidas = await generarLibroEmitidas(empresaId, anio);
    final recibidas = await generarLibroRecibidas(empresaId, anio);
    final resumen = await calcularResumen(empresaId: empresaId, anio: anio);

    final buf = StringBuffer();

    // ── Resumen ejecutivo ─────────────────────────────────────────────────
    buf.writeln('INFORME ANUAL PARA GESTORÍA — AÑO $anio');
    buf.writeln('Generado el,${DateTime.now().toIso8601String()}');
    buf.writeln();
    buf.writeln('=== RESUMEN FISCAL ===');
    buf.writeln('Concepto,Importe (€)');
    buf.writeln('Base imponible ingresos,${resumen.baseImponibleEmitida.toStringAsFixed(2)}');
    buf.writeln('IVA repercutido (ventas),${resumen.ivaRepercutido.toStringAsFixed(2)}');
    buf.writeln('Total facturado,${resumen.totalFacturado.toStringAsFixed(2)}');
    buf.writeln('Base imponible gastos,${resumen.baseImponibleRecibida.toStringAsFixed(2)}');
    buf.writeln('IVA soportado (gastos),${resumen.ivaSoportado.toStringAsFixed(2)}');
    buf.writeln('Total gastado,${resumen.totalGastado.toStringAsFixed(2)}');
    buf.writeln('BENEFICIO NETO,${resumen.beneficioNeto.toStringAsFixed(2)}');
    buf.writeln('IVA A INGRESAR (mod. 303),${resumen.ivaAIngresar.toStringAsFixed(2)}');
    buf.writeln('PAGO FRACCIONADO IRPF (mod. 130),${resumen.pagoFraccionadoIRPF.toStringAsFixed(2)}');
    buf.writeln();

    // ── Libro emitidas ────────────────────────────────────────────────────
    buf.writeln('=== LIBRO DE FACTURAS EMITIDAS ===');
    buf.writeln(_cabeceraCsv);
    for (final l in emitidas) buf.writeln(l.toCsvRow());
    buf.writeln();

    // ── Libro recibidas ───────────────────────────────────────────────────
    buf.writeln('=== LIBRO DE FACTURAS RECIBIDAS / GASTOS ===');
    buf.writeln(_cabeceraCsv);
    for (final l in recibidas) buf.writeln(l.toCsvRow());

    return buf.toString();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STREAM DE FACTURAS — para el libro de ingresos en tiempo real
  // ═════════════════════════════════════════════════════════════════════════

  Stream<List<Factura>> obtenerFacturasStream(String empresaId) {
    return _facturas(empresaId)
        .orderBy('fecha_emision', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Factura.fromFirestore(d)).toList());
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DATOS MENSUALES — para gráficos de evolución anual
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<DatoMensual>> obtenerDatosMensuales(
      String empresaId, int anio) async {
    final resultado = <DatoMensual>[];
    for (int mes = 1; mes <= 12; mes++) {
      final resumen =
          await calcularResumen(empresaId: empresaId, anio: anio, mes: mes);
      resultado.add(DatoMensual(
        mes: mes,
        ingresos: resumen.totalFacturado,
        gastos: resumen.totalGastado,
      ));
    }
    return resultado;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MODELOS FISCALES TRIMESTRALES — 303 (IVA) y 130 (IRPF)
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<ModeloFiscalTrimestral>> calcularModelosFiscales(
      String empresaId, int anio) async {
    final resultados = <ModeloFiscalTrimestral>[];
    for (int t = 1; t <= 4; t++) {
      final resumen = await calcularResumen(
          empresaId: empresaId, anio: anio, trimestre: t);
      resultados.add(ModeloFiscalTrimestral(
        anio: anio,
        trimestre: t,
        resumen: resumen,
      ));
    }
    return resultados;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // RESUMEN POR TRIMESTRES — útil para el dashboard fiscal
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<ResumenContable>> calcularTrimestres(
      String empresaId, int anio) async {
    final resultados = <ResumenContable>[];
    for (int t = 1; t <= 4; t++) {
      resultados.add(await calcularResumen(
          empresaId: empresaId, anio: anio, trimestre: t));
    }
    return resultados;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS RÁPIDAS DE GASTOS
  // ═════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> estadisticasGastosMes(
      String empresaId, int anio, int mes) async {
    final inicio = DateTime(anio, mes, 1);
    final fin = DateTime(anio, mes + 1, 1);

    final snap = await _gastos(empresaId)
        .where('fecha_gasto',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_gasto', isLessThan: Timestamp.fromDate(fin))
        .get();

    final gastos = snap.docs
        .map((d) => Gasto.fromMap({...d.data(), 'id': d.id}))
        .toList();

    // Agrupar por categoría
    final porCategoria = <String, double>{};
    for (final g in gastos) {
      final cat = g.categoria.nombre;
      porCategoria[cat] = (porCategoria[cat] ?? 0) + g.total;
    }

    return {
      'num_gastos': gastos.length,
      'total_gastos': gastos.fold(0.0, (s, g) => s + g.total),
      'iva_soportado': gastos
          .where((g) => g.ivaDeducible)
          .fold(0.0, (s, g) => s + g.importeIva),
      'pendientes': gastos.where((g) => g.estado == EstadoGasto.pendiente).length,
      'por_categoria': porCategoria,
    };
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FACTURAS RECIBIDAS (Libro de compras)
  // ═════════════════════════════════════════════════════════════════════════

  Stream<List<FacturaRecibida>> obtenerFacturasRecibidas(String empresaId) {
    return _facturasRecibidas(empresaId)
        .orderBy('fecha_recepcion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FacturaRecibida.fromFirestore(d))
            .toList());
  }

  Stream<List<FacturaRecibida>> obtenerFacturasRecibidasPorPeriodo(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) {
    return _facturasRecibidas(empresaId)
        .where('fecha_recepcion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .orderBy('fecha_recepcion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FacturaRecibida.fromFirestore(d))
            .toList());
  }

  Stream<List<FacturaRecibida>> obtenerFacturasRecibidasPorProveedor(
    String empresaId,
    String nifProveedor,
  ) {
    return _facturasRecibidas(empresaId)
        .where('nif_proveedor', isEqualTo: nifProveedor)
        .orderBy('fecha_recepcion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FacturaRecibida.fromFirestore(d))
            .toList());
  }

  Stream<List<FacturaRecibida>> obtenerFacturasRecibidasPorEstado(
    String empresaId,
    EstadoFacturaRecibida estado,
  ) {
    return _facturasRecibidas(empresaId)
        .where('estado', isEqualTo: estado.name)
        .orderBy('fecha_recepcion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FacturaRecibida.fromFirestore(d))
            .toList());
  }

  Future<FacturaRecibida> guardarFacturaRecibida({
    required String empresaId,
    required String numeroFactura,
    required String nifProveedor,
    required String nombreProveedor,
    required double baseImponible,
    required double porcentajeIva,
    DateTime? fechaEmision,
    DateTime? fechaRecepcion,
    bool ivaDeducible = true,
    double descuentoGlobal = 0,
    String? direccionProveedor,
    String? telefonoProveedor,
    String? notas,
    String? facturaRecibidaIdEditar,
    // Arrendamiento (Mod.115)
    bool esArrendamiento = false,
    String? nifArrendador,
    String? conceptoArrendamiento,
  }) async {
    // Validar NIF
    final validNif = ValidadorNifCif.validar(nifProveedor);
    if (!validNif.valido) {
      throw Exception('NIF/CIF inválido: ${validNif.razon}');
    }

    final ahora = DateTime.now();
    final emision = fechaEmision ?? ahora;
    final recepcion = fechaRecepcion ?? ahora;

    // Calcular totales
    final importeIva = baseImponible * (porcentajeIva / 100);
    final totalConImpuestos = baseImponible + importeIva;

    final doc = FacturaRecibida(
      id: facturaRecibidaIdEditar ?? '',
      empresaId: empresaId,
      numeroFactura: numeroFactura,
      fechaEmision: emision,
      fechaRecepcion: recepcion,
      nifProveedor: ValidadorNifCif.limpiar(nifProveedor),
      nombreProveedor: nombreProveedor,
      baseImponible: baseImponible,
      porcentajeIva: porcentajeIva,
      importeIva: importeIva,
      ivaDeducible: ivaDeducible,
      descuentoGlobal: descuentoGlobal,
      totalConImpuestos: totalConImpuestos,
      direccionProveedor: direccionProveedor,
      telefonoProveedor: telefonoProveedor,
      esArrendamiento: esArrendamiento,
      nifArrendador: esArrendamiento ? (nifArrendador ?? nifProveedor) : null,
      conceptoArrendamiento: conceptoArrendamiento,
      notas: notas,
      fechaCreacion: ahora,
    );

    final ref = facturaRecibidaIdEditar != null && facturaRecibidaIdEditar.isNotEmpty
        ? _facturasRecibidas(empresaId).doc(facturaRecibidaIdEditar)
        : _facturasRecibidas(empresaId).doc();

    final data = doc.toFirestore();
    data['id'] = ref.id;
    await ref.set(data);

    return FacturaRecibida.fromFirestore(await ref.get());
  }

  Future<void> actualizarEstadoFacturaRecibida({
    required String empresaId,
    required String facturaRecibidaId,
    required EstadoFacturaRecibida nuevoEstado,
    String? metodoPago,
  }) async {
    final datos = <String, dynamic>{
      'estado': nuevoEstado.name,
      'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
    };

    if (nuevoEstado == EstadoFacturaRecibida.pagada) {
      datos['fecha_pago'] = Timestamp.fromDate(DateTime.now());
      if (metodoPago != null) datos['metodo_pago'] = metodoPago;
    }

    await _facturasRecibidas(empresaId).doc(facturaRecibidaId).update(datos);
  }

  Future<void> eliminarFacturaRecibida(
    String empresaId,
    String facturaRecibidaId,
  ) =>
      _facturasRecibidas(empresaId).doc(facturaRecibidaId).delete();

  /// Calcula IVA soportado total del período (facturas recibidas deducibles)
  Future<double> calcularIvaSoportado(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final snap = await _facturasRecibidas(empresaId)
        .where('fecha_recepcion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .where('iva_deducible', isEqualTo: true)
        .get();

    double total = 0.0;
    for (final doc in snap.docs) {
      final data = doc.data();
      total += ((data['importe_iva'] as num?)?.toDouble() ?? 0);
    }
    return total;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EXPORTACIÓN CSV FACTURAS RECIBIDAS (con filtros avanzados)
  // ═════════════════════════════════════════════════════════════════════════

  /// Exporta CSV de facturas recibidas con filtros de fecha, estado y proveedor.
  /// El filtrado por estado y proveedor se hace en memoria para evitar
  /// índices compuestos en Firestore.
  Future<String> exportarCSVRecibidasFiltrado(
    String empresaId, {
    DateTime? desde,
    DateTime? hasta,
    EstadoFacturaRecibida? estado,
    String? proveedorFiltro,
  }) async {
    // ── Consulta base ────────────────────────────────────────────────────────
    Query<Map<String, dynamic>> query = _facturasRecibidas(empresaId);

    if (desde != null) {
      query = query.where(
        'fecha_recepcion',
        isGreaterThanOrEqualTo: Timestamp.fromDate(desde),
      );
    }
    if (hasta != null) {
      query = query.where(
        'fecha_recepcion',
        isLessThan: Timestamp.fromDate(
          DateTime(hasta.year, hasta.month, hasta.day + 1),
        ),
      );
    }
    query = query.orderBy('fecha_recepcion');

    final snap = await query.get();
    List<FacturaRecibida> facturas =
        snap.docs.map((d) => FacturaRecibida.fromFirestore(d)).toList();

    // ── Filtros en memoria ────────────────────────────────────────────────────
    if (estado != null) {
      facturas = facturas.where((f) => f.estado == estado).toList();
    }
    if (proveedorFiltro != null && proveedorFiltro.trim().isNotEmpty) {
      final q = proveedorFiltro.trim().toLowerCase();
      facturas = facturas
          .where((f) =>
              f.nombreProveedor.toLowerCase().contains(q) ||
              f.nifProveedor.toLowerCase().contains(q))
          .toList();
    }

    // ── Construcción CSV ─────────────────────────────────────────────────────
    String _esc(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    String _fmtDate(DateTime? d) {
      if (d == null) return '';
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    final buf = StringBuffer();
    buf.writeln(
      'Número,Fecha,Proveedor,NIF Proveedor,Concepto,'
      'Base Imponible,IVA%,Cuota IVA,IVA Deducible,'
      'Total,Retención,Estado Pago,Fecha Pago',
    );

    for (final f in facturas) {
      buf.writeln([
        _esc(f.numeroFactura),
        _fmtDate(f.fechaRecepcion),
        _esc(f.nombreProveedor),
        _esc(f.nifProveedor),
        _esc(f.notas ?? ''),
        f.baseImponible.toStringAsFixed(2),
        f.porcentajeIva.toStringAsFixed(0),
        f.importeIva.toStringAsFixed(2),
        f.ivaDeducible ? 'Sí' : 'No',
        f.totalConImpuestos.toStringAsFixed(2),
        (f.importeRetencion ?? 0.0).toStringAsFixed(2),
        _esc(f.estado.etiqueta),
        _fmtDate(f.fechaPago),
      ].join(','));
    }

    return buf.toString();
  }

  /// Resumen de facturas recibidas por período
  Future<Map<String, dynamic>> generarResumenFacturasRecibidas(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final snap = await _facturasRecibidas(empresaId)
        .where('fecha_recepcion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .get();

    final facturas = snap.docs
        .map((d) => FacturaRecibida.fromFirestore(d))
        .toList();

    final ivaDeducible = facturas
        .where((f) => f.ivaDeducible)
        .fold(0.0, (sum, f) => sum + f.ivaDeducibleReal);

    final noDeducible = facturas
        .where((f) => !f.ivaDeducible)
        .fold(0.0, (sum, f) => sum + f.importeIva);

    return {
      'num_facturas': facturas.length,
      'base_imponible_total': facturas.fold(0.0, (sum, f) => sum + f.baseImponible),
      'iva_deducible': ivaDeducible,
      'iva_no_deducible': noDeducible,
      'total_facturas': facturas.fold(0.0, (sum, f) => sum + f.totalConImpuestos),
      'pagadas': facturas.where((f) => f.estaPagada).length,
      'pendientes': facturas.where((f) => f.estaPendiente).length,
    };
  }
}







import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/factura.dart';
import '../../domain/modelos/factura_recibida.dart';
import '../../domain/modelos/empresa.dart';
import 'exportadores_aeat/mod_303_exporter.dart';
import 'exportadores_aeat/dr303e26v101_exporter.dart';
import 'exportadores_aeat/libro_registro_iva_exporter.dart';

/// Servicio para generar automáticamente MOD 303 y Libro IVA
class Mod303Service {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<CriterioIVA> _obtenerCriterioIVA(String empresaId) async {
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('fiscal')
        .get();
    final valor = (doc.data()?['criterio_iva'] as String?) ?? 'devengo';
    return CriterioIVA.values.firstWhere(
      (e) => e.name == valor,
      orElse: () => CriterioIVA.devengo,
    );
  }

  bool _incluyeEmitida(
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

  bool _incluyeRecibida(
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

  /// Calcula datos MOD 303 a partir de facturas emitidas y recibidas
  Future<Map<String, dynamic>> calcularMod303({
    required String empresaId,
    required int anio,
    required int trimestre,
  }) async {
    final rango = Mod303Exporter.rangoMesesTrimestre(trimestre);
    final fechaInicio = DateTime(anio, rango.mesInicio, 1);
    final fechaFin = DateTime(anio, rango.mesFin + 1, 1);
    final criterio = await _obtenerCriterioIVA(empresaId);

    // Obtener facturas emitidas y recibidas con ventana amplia y filtrar por criterio
    final facturasEmitidas = (await _obtenerFacturasEmitidas(
      empresaId,
      fechaInicio.subtract(const Duration(days: 120)),
      fechaFin,
    ))
        .where((f) => _incluyeEmitida(f, criterio, fechaInicio, fechaFin))
        .where((f) => !_esFacturaIntracomunitaria(f))
        .toList();

    final facturasRecibidas = (await _obtenerFacturasRecibidas(
      empresaId,
      fechaInicio.subtract(const Duration(days: 120)),
      fechaFin,
    ))
        .where((f) => _incluyeRecibida(f, criterio, fechaInicio, fechaFin))
        .where((f) => !_esFacturaRecibidaIntracomunitaria(f))
        .toList();

    // Calcular totales
    final totales = _calcularTotales(facturasEmitidas, facturasRecibidas);
    totales['criterio_iva'] = criterio.name;
    return totales;
  }

  /// Obtiene facturas emitidas del período
  Future<List<Factura>> _obtenerFacturasEmitidas(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .where('fecha_emision', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((d) => Factura.fromFirestore(d))
        .where((f) => f.estado != EstadoFactura.anulada)
        .toList();
  }

  /// Obtiene facturas recibidas del período
  Future<List<FacturaRecibida>> _obtenerFacturasRecibidas(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas_recibidas')
        .where('fecha_recepcion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((d) => FacturaRecibida.fromFirestore(d))
        .where((f) => f.estado != EstadoFacturaRecibida.rechazada)
        .toList();
  }

  /// Calcula totales para MOD 303
  Map<String, dynamic> _calcularTotales(
    List<Factura> emitidas,
    List<FacturaRecibida> recibidas,
  ) {
    // Calcular bases y cuotas (emitidas)
    final baseGeneral =
        emitidas.fold(0.0, (sum, f) => sum + f.lineas
            .where((l) => l.porcentajeIva == 21)
            .fold(0.0, (s, l) => s + l.subtotalSinIva));

    final cuotaGeneral =
        emitidas.fold(0.0, (sum, f) => sum + f.lineas
            .where((l) => l.porcentajeIva == 21)
            .fold(0.0, (s, l) => s + l.importeIva));

    final baseReducida =
        emitidas.fold(0.0, (sum, f) => sum + f.lineas
            .where((l) => l.porcentajeIva == 10)
            .fold(0.0, (s, l) => s + l.subtotalSinIva));

    final cuotaReducida =
        emitidas.fold(0.0, (sum, f) => sum + f.lineas
            .where((l) => l.porcentajeIva == 10)
            .fold(0.0, (s, l) => s + l.importeIva));

    final baseSuperReducida =
        emitidas.fold(0.0, (sum, f) => sum + f.lineas
            .where((l) => l.porcentajeIva == 4)
            .fold(0.0, (s, l) => s + l.subtotalSinIva));

    final cuotaSuperReducida =
        emitidas.fold(0.0, (sum, f) => sum + f.lineas
            .where((l) => l.porcentajeIva == 4)
            .fold(0.0, (s, l) => s + l.importeIva));

    // Calcular IVA soportado (recibidas deducibles)
    final ivaSoportado =
        recibidas.where((f) => f.ivaDeducible)
            .fold(0.0, (sum, f) => sum + f.ivaDeducibleReal);

    final totalRepercutido = cuotaGeneral + cuotaReducida + cuotaSuperReducida;
    final iva303 = totalRepercutido - ivaSoportado;

    return {
      'base_general': baseGeneral,
      'cuota_general': cuotaGeneral,
      'base_reducida': baseReducida,
      'cuota_reducida': cuotaReducida,
      'base_super_reducida': baseSuperReducida,
      'cuota_super_reducida': cuotaSuperReducida,
      'total_repercutido': totalRepercutido,
      'iva_soportado': ivaSoportado,
      'iva_303': iva303,
      'num_facturas_emitidas': emitidas.length,
      'num_facturas_recibidas': recibidas.length,
      'facturas_emitidas': emitidas,
      'facturas_recibidas': recibidas,
    };
  }

  /// Genera MOD 303 en formato AEAT descargable usando DR303e26v101
  Future<String> generarMod303Dr303e26v101({
    required String empresaId,
    required String nifEmpresa,
    required String nombreEmpresa,
    required int anio,
    required int trimestre,
  }) async {
    final datos = await calcularMod303(
      empresaId: empresaId,
      anio: anio,
      trimestre: trimestre,
    );

    final periodo = _periodoTrimestral(trimestre);
    final casillas = _construirCasillas(datos);
    final porcentajes = _construirPorcentajes(datos);

    final exporter = Dr303e26v101Exporter();
    return exporter.exportar(
      DatosDr303e26v101(
        nifDeclarante: nifEmpresa,
        nombreRazonSocial: nombreEmpresa,
        ejercicio: anio,
        periodo: periodo,
        tipoDeclaracion: 1,
        casillas: casillas,
        porcentajes5: porcentajes,
      ),
    );
  }

  /// Genera MOD 303 en formato AEAT descargable (legacy, compatibilidad)
  Future<String> generarMod303Descargable({
    required String empresaId,
    required String nifEmpresa,
    required int anio,
    required int trimestre,
  }) async {
    final datos = await calcularMod303(
      empresaId: empresaId,
      anio: anio,
      trimestre: trimestre,
    );

    return Mod303Exporter.generar(
      nifEmpresa: nifEmpresa,
      trimestre: trimestre,
      anio: anio,
      baseGeneral: datos['base_general'] ?? 0.0,
      cuotaGeneral: datos['cuota_general'] ?? 0.0,
      baseReducida: datos['base_reducida'] ?? 0.0,
      cuotaReducida: datos['cuota_reducida'] ?? 0.0,
      baseSuperReducida: datos['base_super_reducida'] ?? 0.0,
      cuotaSuperReducida: datos['cuota_super_reducida'] ?? 0.0,
      ivaRepercutido: datos['total_repercutido'] ?? 0.0,
      ivaSoportado: datos['iva_soportado'] ?? 0.0,
      compensaciones: 0.0,
    );
  }

  /// Genera Libro Registro IVA
  Future<String> generarLibroIva({
    required String empresaId,
    required String nifEmpresa,
    required int mes,
    required int anio,
  }) async {
    final fechaInicio = DateTime(anio, mes, 1);
    final fechaFin = DateTime(anio, mes + 1, 1);

    final facturasEmitidas = await _obtenerFacturasEmitidas(
      empresaId,
      fechaInicio,
      fechaFin,
    );

    final facturasRecibidas = await _obtenerFacturasRecibidas(
      empresaId,
      fechaInicio,
      fechaFin,
    );

    final libroEmitidas = LibroRegistroIvaExporter.generarLibroEmitidas(
      nifEmpresa,
      mes,
      anio,
      facturasEmitidas,
    );

    final libroRecibidas = LibroRegistroIvaExporter.generarLibroRecibidas(
      nifEmpresa,
      mes,
      anio,
      facturasRecibidas,
    );

    return '$libroEmitidas\n$libroRecibidas';
  }

  /// Resumen visual para pantalla
  String _periodoTrimestral(int trimestre) {
    switch (trimestre) {
      case 1: return '1T';
      case 2: return '2T';
      case 3: return '3T';
      case 4: return '4T';
      default: return '1T';
    }
  }

  Map<String, double> _construirCasillas(Map<String, dynamic> datos) {
    return <String, double>{
      '01': (datos['base_reducida'] ?? 0.0) as double,
      '03': (datos['cuota_reducida'] ?? 0.0) as double,
      '04': (datos['base_general'] ?? 0.0) as double,
      '06': (datos['cuota_general'] ?? 0.0) as double,
      '46': (datos['total_repercutido'] ?? 0.0) as double,
      '20': (datos['iva_soportado'] ?? 0.0) as double,
      '47': (datos['iva_soportado'] ?? 0.0) as double,
      '48': ((datos['total_repercutido'] ?? 0.0) - (datos['iva_soportado'] ?? 0.0)) as double,
      '69': ((datos['total_repercutido'] ?? 0.0) - (datos['iva_soportado'] ?? 0.0)) as double,
      '71': ((datos['total_repercutido'] ?? 0.0) - (datos['iva_soportado'] ?? 0.0)) as double,
    };
  }

  Map<String, double> _construirPorcentajes(Map<String, dynamic> datos) {
    return <String, double>{'65': 100.0};
  }
  Future<Map<String, dynamic>> resumenMod303Pantalla({
    required String empresaId,
    required int anio,
    required int trimestre,
  }) async {
    final datos = await calcularMod303(
      empresaId: empresaId,
      anio: anio,
      trimestre: trimestre,
    );

    return {
      'trimestre': trimestre,
      'anio': anio,
      'base_general': datos['base_general'],
      'cuota_general': datos['cuota_general'],
      'base_reducida': datos['base_reducida'],
      'cuota_reducida': datos['cuota_reducida'],
      'base_super_reducida': datos['base_super_reducida'],
      'cuota_super_reducida': datos['cuota_super_reducida'],
      'total_repercutido': datos['total_repercutido'],
      'iva_soportado': datos['iva_soportado'],
      'iva_303': datos['iva_303'],
      'num_facturas_emitidas': datos['num_facturas_emitidas'],
      'num_facturas_recibidas': datos['num_facturas_recibidas'],
    };
  }
}






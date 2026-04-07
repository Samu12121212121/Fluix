import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/modelo111.dart';
import '../domain/modelos/nomina.dart';

/// Servicio del Modelo 111 — Retenciones e ingresos a cuenta IRPF.
///
/// Agrega datos de nóminas pagadas del trimestre para generar la declaración.
/// Colección Firestore: `empresas/{empresaId}/modelos111/{ejercicio_trimestre}`
class Modelo111Service {
  static final Modelo111Service _i = Modelo111Service._();
  factory Modelo111Service() => _i;
  Modelo111Service._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('modelos111');

  CollectionReference<Map<String, dynamic>> _nominas(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('nominas');

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO AUTOMÁTICO DESDE NÓMINAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el Modelo 111 para un trimestre a partir de nóminas pagadas.
  Future<Modelo111> calcularDesdeNominas({
    required String empresaId,
    required int ejercicio,
    required String trimestre,
    double deducirComplementaria = 0,
    TipoDeclaracion111? tipoForzado,
  }) async {
    final rango = Modelo111.rangoMeses(trimestre);
    final nominas = await _obtenerNominasPagadasTrimestre(
      empresaId, ejercicio, rango.mesInicio, rango.mesFin,
    );

    return agregarNominas(
      empresaId: empresaId,
      ejercicio: ejercicio,
      trimestre: trimestre,
      nominas: nominas,
      deducirComplementaria: deducirComplementaria,
      tipoForzado: tipoForzado,
    );
  }

  /// Agrega una lista de nóminas y devuelve el Modelo111 calculado.
  Modelo111 agregarNominas({
    required String empresaId,
    required int ejercicio,
    required String trimestre,
    required List<Nomina> nominas,
    double deducirComplementaria = 0,
    TipoDeclaracion111? tipoForzado,
  }) {
    final rango = Modelo111.rangoMeses(trimestre);
    final fechaInicio = DateTime(ejercicio, rango.mesInicio, 1);
    final fechaFin = DateTime(ejercicio, rango.mesFin + 1, 0); // último día
    final plazo = Modelo111.calcularPlazoLimite(ejercicio, trimestre);

    // Empleados únicos con rendimientos dinerarios
    final empleadosDinerarios = <String>{};
    // Empleados únicos con retribuciones en especie
    final empleadosEspecie = <String>{};

    double sumaBrutosDinerarios = 0;
    double sumaRetencionesDinerarias = 0;
    double sumaEspecie = 0;
    // Ingreso a cuenta especie: se aproxima como retencionIrpf * (especie/totalDevengos)
    double sumaIngresosCtaEspecie = 0;

    final ids = <String>[];

    for (final n in nominas) {
      ids.add(n.id);

      // Dinerarios: totalDevengosCash
      final dinerario = n.totalDevengosCash;
      if (dinerario > 0) {
        empleadosDinerarios.add(n.empleadoId);
        sumaBrutosDinerarios += dinerario;
      }

      // Retención IRPF: se reparte proporcionalmente entre dinerario y especie
      final especie = n.retribucionesEspecie;
      final totalDev = n.totalDevengos;

      if (especie > 0 && totalDev > 0) {
        empleadosEspecie.add(n.empleadoId);
        sumaEspecie += especie;
        // Proporción del IRPF que corresponde a especie
        final propEspecie = especie / totalDev;
        final irpfEspecie = n.retencionIrpf * propEspecie;
        sumaIngresosCtaEspecie += irpfEspecie;
        // El resto del IRPF es sobre dinerario
        sumaRetencionesDinerarias += n.retencionIrpf - irpfEspecie;
      } else {
        sumaRetencionesDinerarias += n.retencionIrpf;
      }
    }

    final c03 = _r2(sumaRetencionesDinerarias);
    final c06 = _r2(sumaIngresosCtaEspecie);
    final totalRetenciones = c03 + c06;

    final TipoDeclaracion111 tipo;
    if (tipoForzado != null) {
      tipo = tipoForzado;
    } else if (deducirComplementaria > 0) {
      tipo = TipoDeclaracion111.complementaria;
    } else if (totalRetenciones > 0) {
      tipo = TipoDeclaracion111.ingreso;
    } else {
      tipo = TipoDeclaracion111.negativa;
    }

    return Modelo111(
      id: '${ejercicio}_$trimestre',
      empresaId: empresaId,
      ejercicio: ejercicio,
      trimestre: trimestre,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      plazoLimite: plazo,
      c01: empleadosDinerarios.length,
      c02: _r2(sumaBrutosDinerarios),
      c03: c03,
      c04: empleadosEspecie.length,
      c05: _r2(sumaEspecie),
      c06: c06,
      // Secciones II-V: 0 para PYMEs estándar
      c29: _r2(deducirComplementaria),
      tipo: tipo,
      estado: EstadoModelo111.borrador,
      fechaCreacion: DateTime.now(),
      nominasIncluidas: ids,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSULTA DE NÓMINAS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Nomina>> _obtenerNominasPagadasTrimestre(
    String empresaId,
    int ejercicio,
    int mesInicio,
    int mesFin,
  ) async {
    final snap = await _nominas(empresaId)
        .where('anio', isEqualTo: ejercicio)
        .where('estado', isEqualTo: EstadoNomina.pagada.name)
        .get();

    return snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .where((n) => n.mes >= mesInicio && n.mes <= mesFin)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD FIRESTORE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Modelo111> guardar(String empresaId, Modelo111 modelo) async {
    final docId = '${modelo.ejercicio}_${modelo.trimestre}';
    final data = modelo.toMap();
    data['id'] = docId;
    await _col(empresaId).doc(docId).set(data, SetOptions(merge: true));
    return Modelo111.fromMap(data);
  }

  Future<Modelo111?> obtener(
    String empresaId,
    int ejercicio,
    String trimestre,
  ) async {
    final doc = await _col(empresaId).doc('${ejercicio}_$trimestre').get();
    if (!doc.exists) return null;
    return Modelo111.fromMap({...doc.data()!, 'id': doc.id});
  }

  Stream<List<Modelo111>> obtenerTodos(String empresaId, int ejercicio) {
    return _col(empresaId)
        .where('ejercicio', isEqualTo: ejercicio)
        .orderBy('trimestre')
        .snapshots()
        .map((s) => s.docs
            .map((d) => Modelo111.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> marcarPresentado(String empresaId, String docId) async {
    await _col(empresaId).doc(docId).update({
      'estado': EstadoModelo111.presentado.name,
    });
  }

  Future<void> eliminar(String empresaId, String docId) async {
    final doc = await _col(empresaId).doc(docId).get();
    if (doc.exists && doc.data()?['estado'] == 'borrador') {
      await doc.reference.delete();
    }
  }

  /// Resumen rápido del trimestre actual para el dashboard.
  Future<Map<String, dynamic>> resumenTrimestreActual(String empresaId) async {
    final ahora = DateTime.now();
    final trimestre = _trimestreActual(ahora.month);
    final modelo = await obtener(empresaId, ahora.year, trimestre);
    final plazo = Modelo111.calcularPlazoLimite(ahora.year, trimestre);
    final diasRestantes = plazo.difference(ahora).inDays;

    if (modelo != null) {
      return {
        'trimestre': trimestre,
        'ejercicio': ahora.year,
        'estado': modelo.estado.etiqueta,
        'c30': modelo.c30,
        'dias_restantes': diasRestantes,
        'plazo': plazo,
        'existe': true,
      };
    }

    // Estimar desde nóminas pagadas sin modelo guardado
    final rango = Modelo111.rangoMeses(trimestre);
    final nominas = await _obtenerNominasPagadasTrimestre(
      empresaId, ahora.year, rango.mesInicio, rango.mesFin,
    );
    final estimado = nominas.fold(0.0, (s, n) => s + n.retencionIrpf);

    return {
      'trimestre': trimestre,
      'ejercicio': ahora.year,
      'estado': 'Pendiente',
      'c30': _r2(estimado),
      'dias_restantes': diasRestantes,
      'plazo': plazo,
      'existe': false,
    };
  }

  static String _trimestreActual(int mes) {
    if (mes <= 3) return '1T';
    if (mes <= 6) return '2T';
    if (mes <= 9) return '3T';
    return '4T';
  }

  static double _r2(double v) => (v * 100).roundToDouble() / 100;
}


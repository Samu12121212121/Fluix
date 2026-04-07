import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/festivo_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE FESTIVOS — Descarga desde Nager.Date API + Firestore + Caché
// ═══════════════════════════════════════════════════════════════════════════════

class FestivosService {
  static final FestivosService _i = FestivosService._();
  factory FestivosService() => _i;
  FestivosService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Caché en memoria: año → Set<DateTime> de festivos.
  final Map<int, Set<DateTime>> _cacheFestivos = {};

  /// Caché de objetos Festivo completos: año → lista.
  final Map<int, List<Festivo>> _cacheFestivosFull = {};

  // ── REFS ────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _festivosCol(
          String empresaId, int anio) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('festivos')
          .doc('$anio')
          .collection('dias');

  DocumentReference<Map<String, dynamic>> _metaDoc(
          String empresaId, int anio) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('festivos')
          .doc('$anio');

  // ═══════════════════════════════════════════════════════════════════════════
  // OBTENER FESTIVOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtiene los festivos del año desde Firestore (o caché).
  Future<List<Festivo>> obtenerFestivos(String empresaId, int anio) async {
    if (_cacheFestivosFull.containsKey(anio)) {
      return _cacheFestivosFull[anio]!;
    }

    final snap = await _festivosCol(empresaId, anio).get();
    final festivos =
        snap.docs.map((d) => Festivo.fromMap(d.data())).toList();

    // Guardar en caché
    _cacheFestivosFull[anio] = festivos;
    _cacheFestivos[anio] =
        festivos.map((f) => f.fechaNormalizada).toSet();

    return festivos;
  }

  /// Devuelve el Set<DateTime> de festivos del año (solo fechas, para cálculos rápidos).
  Future<Set<DateTime>> obtenerFechasFestivos(
      String empresaId, int anio) async {
    if (_cacheFestivos.containsKey(anio)) {
      return _cacheFestivos[anio]!;
    }
    await obtenerFestivos(empresaId, anio);
    return _cacheFestivos[anio] ?? {};
  }

  /// ¿Es festivo esta fecha?
  Future<bool> esFestivo(String empresaId, DateTime fecha) async {
    final anio = fecha.year;
    final set = await obtenerFechasFestivos(empresaId, anio);
    return set.contains(DateTime(fecha.year, fecha.month, fecha.day));
  }

  /// Nombre del festivo (null si no lo es).
  Future<String?> nombreFestivo(String empresaId, DateTime fecha) async {
    final anio = fecha.year;
    final festivos = await obtenerFestivos(empresaId, anio);
    final key = DateTime(fecha.year, fecha.month, fecha.day);
    try {
      return festivos
          .firstWhere((f) => f.fechaNormalizada == key)
          .nombre;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DE DÍAS HÁBILES (excluyendo fines de semana + festivos)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula días hábiles entre dos fechas (ambas incluidas),
  /// excluyendo sábados, domingos y festivos.
  Future<int> calcularDiasHabiles(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final a = DateTime(inicio.year, inicio.month, inicio.day);
    final b = DateTime(fin.year, fin.month, fin.day);

    // Reunir festivos de todos los años involucrados
    final Set<DateTime> festivos = {};
    for (int anio = a.year; anio <= b.year; anio++) {
      festivos.addAll(await obtenerFechasFestivos(empresaId, anio));
    }

    int count = 0;
    DateTime current = a;
    while (!current.isAfter(b)) {
      final esFinde = current.weekday == DateTime.saturday ||
          current.weekday == DateTime.sunday;
      final esFest = festivos.contains(current);
      if (!esFinde && !esFest) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  /// Días festivos dentro de un rango (excluyendo fines de semana).
  /// Útil para mostrar cuántos festivos se "ahorra" el empleado.
  Future<int> contarFestivosEnRango(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final a = DateTime(inicio.year, inicio.month, inicio.day);
    final b = DateTime(fin.year, fin.month, fin.day);

    final Set<DateTime> festivos = {};
    for (int anio = a.year; anio <= b.year; anio++) {
      festivos.addAll(await obtenerFechasFestivos(empresaId, anio));
    }

    int count = 0;
    DateTime current = a;
    while (!current.isAfter(b)) {
      final esFinde = current.weekday == DateTime.saturday ||
          current.weekday == DateTime.sunday;
      final esFest = festivos.contains(current);
      if (!esFinde && esFest) {
        count++; // Es festivo en día laborable
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IMPORTAR DESDE NAGER.DATE API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Descarga festivos de España desde la API Nager.Date y los guarda en Firestore.
  /// Filtra por comunidad autónoma si se proporciona.
  Future<int> importarFestivosDesdeAPI(
    String empresaId,
    int anio, {
    String? codigoComunidad,
  }) async {
    final url = 'https://date.nager.at/api/v3/PublicHolidays/$anio/ES';
    debugPrint('FestivosService: importando festivos de $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('FestivosService: error HTTP ${response.statusCode}');
        return 0;
      }

      final List<dynamic> jsonList = jsonDecode(response.body);
      final festivos = <Festivo>[];

      for (final json in jsonList) {
        final festivo = Festivo.fromNagerApi(json as Map<String, dynamic>);

        // Incluir: nacionales (global) + los de la comunidad autónoma configurada
        final counties = json['counties'] as List<dynamic>?;
        final isGlobal = json['global'] == true ||
            (counties == null || counties.isEmpty);

        if (isGlobal) {
          festivos.add(festivo);
        } else if (codigoComunidad != null &&
            counties.contains(codigoComunidad)) {
          festivos.add(festivo);
        }
      }

      // Guardar en Firestore
      final batch = _db.batch();
      for (final f in festivos) {
        final docId =
            '${f.fecha.year}-${f.fecha.month.toString().padLeft(2, '0')}-${f.fecha.day.toString().padLeft(2, '0')}';
        final ref = _festivosCol(empresaId, anio).doc(docId);
        batch.set(ref, f.toMap());
      }

      // Metadata
      batch.set(
        _metaDoc(empresaId, anio),
        {
          'anio': anio,
          'comunidad_autonoma': codigoComunidad,
          'total_festivos': festivos.length,
          'importado_desde': 'nager.date',
          'fecha_importacion': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Invalidar caché
      _cacheFestivos.remove(anio);
      _cacheFestivosFull.remove(anio);

      debugPrint(
          'FestivosService: ${festivos.length} festivos importados para $anio');
      return festivos.length;
    } catch (e) {
      debugPrint('FestivosService: error importando festivos: $e');
      return 0;
    }
  }

  /// Verifica si ya se importaron festivos para el año dado.
  Future<bool> festivosImportados(String empresaId, int anio) async {
    final doc = await _metaDoc(empresaId, anio).get();
    return doc.exists && (doc.data()?['total_festivos'] as num? ?? 0) > 0;
  }

  /// Importa festivos del año actual y siguiente si no están ya importados.
  Future<void> asegurarFestivosImportados(
    String empresaId, {
    String? codigoComunidad,
  }) async {
    final ahora = DateTime.now();
    final anioActual = ahora.year;
    final anioSiguiente = anioActual + 1;

    if (!await festivosImportados(empresaId, anioActual)) {
      await importarFestivosDesdeAPI(empresaId, anioActual,
          codigoComunidad: codigoComunidad);
    }
    if (!await festivosImportados(empresaId, anioSiguiente)) {
      await importarFestivosDesdeAPI(empresaId, anioSiguiente,
          codigoComunidad: codigoComunidad);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FESTIVOS LOCALES (CRUD manual)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Añade un festivo local manualmente.
  Future<void> anadirFestivoLocal(
    String empresaId,
    DateTime fecha,
    String nombre,
  ) async {
    final anio = fecha.year;
    final docId =
        'local-${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

    final festivo = Festivo(
      fecha: fecha,
      nombre: nombre,
      tipo: TipoFestivo.local,
      esLocal: true,
    );

    await _festivosCol(empresaId, anio).doc(docId).set(festivo.toMap());

    // Actualizar meta
    await _metaDoc(empresaId, anio).set(
      {'total_festivos': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    // Invalidar caché
    _cacheFestivos.remove(anio);
    _cacheFestivosFull.remove(anio);
  }

  /// Elimina un festivo local.
  Future<void> eliminarFestivoLocal(
    String empresaId,
    DateTime fecha,
  ) async {
    final anio = fecha.year;
    final docId =
        'local-${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

    await _festivosCol(empresaId, anio).doc(docId).delete();

    // Invalidar caché
    _cacheFestivos.remove(anio);
    _cacheFestivosFull.remove(anio);
  }

  /// Obtiene solo los festivos locales (añadidos manualmente).
  Future<List<Festivo>> obtenerFestivosLocales(
      String empresaId, int anio) async {
    final snap = await _festivosCol(empresaId, anio)
        .where('es_local', isEqualTo: true)
        .get();
    return snap.docs.map((d) => Festivo.fromMap(d.data())).toList();
  }

  /// Limpia la caché en memoria.
  void limpiarCache() {
    _cacheFestivos.clear();
    _cacheFestivosFull.clear();
  }

  /// Obtiene la comunidad autónoma configurada para la empresa.
  Future<String?> obtenerComunidadAutonoma(String empresaId) async {
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('vacaciones')
        .get();
    return doc.data()?['comunidad_autonoma'] as String?;
  }

  /// Guarda la comunidad autónoma en la configuración de la empresa.
  Future<void> guardarComunidadAutonoma(
      String empresaId, String codigoComunidad) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('vacaciones')
        .set(
      {'comunidad_autonoma': codigoComunidad},
      SetOptions(merge: true),
    );
  }
}



import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/modelo390.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD 390 POSICIONAL — Declaración-Resumen Anual IVA
// Diseño de registro AEAT ejercicio 2025, versión 1.02
//
// Ref: Resolución AEAT BOE publicación diseño registro Mod.390 ejercicio 2025
// ═══════════════════════════════════════════════════════════════════════════════

/// Resultado de la generación del fichero posicional.
class Mod390PosicionalResult {
  final Uint8List bytes;
  final String nombreFichero;
  final int totalPaginas;
  final List<String> alertas;

  const Mod390PosicionalResult({
    required this.bytes,
    required this.nombreFichero,
    required this.totalPaginas,
    this.alertas = const [],
  });
}

/// Servicio que genera el fichero posicional oficial del MOD 390.
///
/// Estructura del fichero:
///  Página 0  — Cabecera envolvente (con AUX)
///  Página 1  — Sujeto pasivo (1187 pos)
///  Página 2  — IVA repercutido (1806 pos)
///  Página 2B — Recargo de equivalencia (531 pos)
///  Página 3  — IVA deducible operaciones interiores (1840 pos)
///  Página 4  — IVA deducible bienes inversión (854 pos)
///  Página 6  — Resultado liquidación y volumen (828 pos)
class Mod390PosicionalService {
  final FirebaseFirestore _db;

  Mod390PosicionalService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ─── GENERAR ───────────────────────────────────────────────────────────────

  /// Genera el fichero posicional del MOD 390 para el [anio] indicado.
  ///
  /// Lee los datos del Modelo390 guardado en Firestore y la config de la empresa.
  ///
  /// Lanza [Exception] si algún trimestre de Mod.303 no existe todavía.
  Future<Mod390PosicionalResult> generar({
    required String empresaId,
    required int anio,
  }) async {
    // 1. Obtener datos de empresa
    final empDoc =
        await _db.collection('empresas').doc(empresaId).get();
    final empresa = empDoc.data() ?? {};
    final nif = (empresa['nif'] as String? ?? '').toUpperCase().trim();
    final razonSocial = (empresa['nombre'] as String? ?? '').trim();

    if (nif.isEmpty) {
      throw Exception('La empresa no tiene NIF configurado');
    }

    // 2. Verificar que existen los 4 trimestres de Mod.303
    final alertas = <String>[];
    for (int t = 1; t <= 4; t++) {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('modelos303')
          .where('anio', isEqualTo: anio)
          .where('trimestre', isEqualTo: t)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        alertas.add(
            '⚠️ Trimestre ${t}T $anio sin Mod.303 — algunos datos pueden ser 0');
      }
    }

    // 3. Obtener el Modelo390 calculado previamente
    final m390Snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('modelos390')
        .where('ejercicio', isEqualTo: anio)
        .limit(1)
        .get();

    final Modelo390 modelo;
    if (m390Snap.docs.isNotEmpty) {
      modelo = Modelo390.fromFirestore(m390Snap.docs.first);
    } else {
      throw Exception(
          'No existe Mod.390 calculado para $anio. '
          'Pulse "Calcular" primero en la pantalla del Mod.390.');
    }

    // 4. Construir páginas
    final b = Mod390Builder();
    final pag1 = b.construirPagina1(
        nif: nif, razonSocial: razonSocial, ejercicio: anio);
    final pag2 = b.construirPagina2(modelo);
    final pag2b = b.construirPagina2B(modelo);
    final pag3 = b.construirPagina3(modelo);
    final pag4 = b.construirPagina4(modelo);
    final pag6 = b.construirPagina6(modelo);

    // 5. Construir Página 0 (cabecera envolvente)
    final contenido = pag1 + pag2 + pag2b + pag3 + pag4 + pag6;
    final fichero = b.construirPagina0(
      anio: anio,
      contenidoPaginas: contenido,
    );

    // 6. Codificar en ISO-8859-1
    final bytesISO = b.codificarISO88591(fichero);

    // 7. Nombre del fichero: 390[NIF]A[AÑO].390
    final nombreFichero = '390${nif}A$anio.390';

    return Mod390PosicionalResult(
      bytes: bytesISO,
      nombreFichero: nombreFichero,
      totalPaginas: 6,
      alertas: alertas,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOD 390 BUILDER — Construcción de páginas posicionales
// ═══════════════════════════════════════════════════════════════════════════════

class Mod390Builder {
  static const _version = '1.02';
  // ⚠️ IMPORTANTE: Reemplazar con el NIF REAL de FluixTech (empresa desarrolladora).
  // Un NIF ficticio puede causar rechazo del fichero por la AEAT.
  static const _nifDesarrollador = 'B12345678'; // TODO: sustituir por NIF real de FluixTech
  ///
  /// Estructura total:
  ///   Cabecera (328 pos) + páginas + cierre (18 pos)
  String construirPagina0({
    required int anio,
    required String contenidoPaginas,
  }) {
    final anioStr = anio.toString().padLeft(4, '0');
    final buf = StringBuffer();

    // Pos 1-17: <T3900AAAA0A0000>
    buf.write('<T390');         // pos 1-5
    buf.write('0');             // pos 6: discriminante
    buf.write(anioStr);         // pos 7-10: año
    buf.write('0A');            // pos 11-12: período anual
    buf.write('0000>');         // pos 13-17: tipo y cierre

    // Pos 18-22: <AUX>
    buf.write('<AUX>');

    // Pos 23-94: 72 blancos (pos 23-24 reservados + pos 25-94 = 70 spec)
    buf.write(' ' * 72);

    // Pos 95-98: versión del programa (4 chars)
    buf.write(formatearAn(_version, 4));

    // Pos 99-102: 4 blancos
    buf.write(' ' * 4);

    // Pos 103-111: NIF desarrollador (9 chars)
    buf.write(formatearAn(_nifDesarrollador, 9));

    // Pos 112-322: 211 blancos
    buf.write(' ' * 211);

    // Pos 323-328: </AUX>
    buf.write('</AUX>');

    // Pos 329-...: contenido de páginas
    buf.write(contenidoPaginas);

    // Final: </T3900AAAA0A0000> (18 chars)
    buf.write('</T3900${anioStr}0A0000>');

    return buf.toString();
  }

  // ─── PÁGINA 1 — Sujeto pasivo (1187 posiciones) ────────────────────────────

  String construirPagina1({
    required String nif,
    required String razonSocial,
    required int ejercicio,
  }) {
    // 1187 posiciones totales: cabecera (11) + contenido (1164) + cierre (12)
    final page = List<String>.filled(1187, ' ');

    // Cabecera: <T39001000> (pos 1-11, 0-indexed: 0-10)
    _write(page, 0, '<T39001000>');

    // Pos 12: indicador complementaria (blanco)
    _write(page, 11, ' ');
    // Pos 13: reservado AEAT (blanco)
    _write(page, 12, ' ');
    // Pos 14-22: NIF empresa (9 chars)
    _write(page, 13, formatearAn(nif, 9));
    // Pos 23-82: Razón social (60 chars, alineado izq)
    _write(page, 22, formatearAn(convertirISO88591(razonSocial), 60));
    // Pos 83-102: Nombre (20 chars, blancos para personas jurídicas)
    _write(page, 82, ' ' * 20);
    // Pos 103-106: ejercicio (4 chars)
    _write(page, 102, ejercicio.toString().padLeft(4, '0'));
    // Pos 107-108: reservado AEAT
    _write(page, 106, '  ');
    // Pos 109: registro devolución mensual
    _write(page, 108, '0');
    // Pos 110: régimen especial grupo
    _write(page, 109, '0');
    // Pos 111-117: número de grupo (7 chars)
    _write(page, 110, '0000000');
    // Pos 118: dominante
    _write(page, 117, '0');
    // Pos 119: dependiente
    _write(page, 118, '0');
    // Pos 120: tipo régimen especial art 163
    _write(page, 119, '0');
    // Pos 121-129: NIF entidad dominante (blancos)
    _write(page, 120, ' ' * 9);
    // Pos 130: concurso acreedores
    _write(page, 129, '0');
    // Pos 131: criterio caja
    _write(page, 130, '0');
    // Pos 132: destinatario criterio caja
    _write(page, 131, '0');
    // Pos 133: sustitutiva
    _write(page, 132, '0');
    // Pos 134: sustitutiva rectificación
    _write(page, 133, '0');
    // Pos 135-147: nº justificante anterior (13 blancos)
    _write(page, 134, ' ' * 13);
    // Pos 148-972: datos actividades (825 blancos para PYME simple)
    _write(page, 147, ' ' * 825);
    // Pos 973-985: reservado AEAT (13 blancos)
    _write(page, 972, ' ' * 13);
    // Pos 986-998: sello electrónico (13 blancos)
    _write(page, 985, ' ' * 13);
    // Pos 999-1018: identificador cliente EEDD (20 blancos)
    _write(page, 998, ' ' * 20);
    // Pos 1019-1168: reservado AEAT (150 blancos)
    _write(page, 1018, ' ' * 150);
    // Pos 1169-1175: reservado (7 blancos para completar hasta pos 1175)
    // Pos 1176-1187: </T39001000> (12 chars)
    _write(page, 1175, '</T39001000>');

    return page.join();
  }

  // ─── PÁGINA 2 — Operaciones régimen general (1806 posiciones) ──────────────

  String construirPagina2(Modelo390 m) {
    final page = List<String>.filled(1806, ' ');

    // Cabecera: <T39002000> (pos 1-11, idx 0-10)
    _write(page, 0, '<T39002000>');

    // [01] Base 4%: pos 81-97 (idx 80-96), 17 chars N
    _writeN(page, 80, m.c01);
    // [02] Cuota 4%: pos 98-114 (idx 97-113)
    _writeN(page, 97, m.c02);
    // [03] Base 10%: pos 183-199 (idx 182-198)
    _writeN(page, 182, m.c03);
    // [04] Cuota 10%: pos 200-216 (idx 199-215)
    _writeN(page, 199, m.c04);
    // [05] Base 21%: pos 217-233 (idx 216-232)
    _writeN(page, 216, m.c05);
    // [06] Cuota 21%: pos 234-250 (idx 233-249)
    _writeN(page, 233, m.c06);
    // Posiciones 115-182 (idx 114-181): otros tipos (4%, 7.5%, etc.) → ceros
    _writeN(page, 114, 0); // 115-131 tipo 7,5%  base
    _writeN(page, 131, 0); // 132-148 tipo 7,5%  cuota
    _writeN(page, 148, 0); // 149-165 tipo 0%    base
    _writeN(page, 165, 0); // 166-182 tipo 0%    cuota
    // [29] Modif. bases: pos 1509-1525 (idx 1508-1524)
    _writeN(page, 1508, 0);
    // [30] Modif. cuotas: pos 1526-1542 (idx 1525-1541)
    _writeN(page, 1525, 0);
    // [33] Total bases: pos 1611-1627 (idx 1610-1626)
    _writeN(page, 1610, m.c01 + m.c03 + m.c05);
    // [34] Total cuotas IVA: pos 1628-1644 (idx 1627-1643)
    _writeN(page, 1627, m.c47);
    // Pos 1645-1794: reservado AEAT (150 chars) — blancos
    // Pos 1795-1806: </T39002000> (12 chars, idx 1794-1805)
    _write(page, 1794, '</T39002000>');

    return page.join();
  }

  // ─── PÁGINA 2B — Recargo de equivalencia (531 posiciones) ─────────────────

  String construirPagina2B(Modelo390 m) {
    final page = List<String>.filled(531, ' ');

    _write(page, 0, '<T39002B00>');

    // Todos los campos a 0 para PYME en régimen general
    // [35] RE 0,5% Base: pos 81-97 (idx 80-96)
    _writeN(page, 80, 0);
    // [36] RE 0,5% Cuota: pos 98-114 (idx 97-113)
    _writeN(page, 97, 0);
    // [41] RE 1,4% Base: pos 183-199 (idx 182-198)
    _writeN(page, 182, 0);
    // [42] RE 1,4% Cuota: pos 200-216 (idx 199-215)
    _writeN(page, 199, 0);
    // [47] Total cuotas IVA y recargo: pos 353-369 (idx 352-368)
    _writeN(page, 352, 0);
    // Pos 370-519: reservado AEAT (150 chars)
    // Pos 520-531: </T39002B00> (12 chars, idx 519-530)
    _write(page, 519, '</T39002B00>');

    return page.join();
  }

  // ─── PÁGINA 3 — IVA deducible operaciones interiores (1840 posiciones) ─────

  String construirPagina3(Modelo390 m) {
    final page = List<String>.filled(1840, ' ');

    _write(page, 0, '<T39003000>');

    // [48] Total BI oper. inter. corrientes: pos 217-233 (idx 216-232)
    _writeN(page, 216, m.c48);
    // [49] Total cuota oper. inter. corrientes: pos 234-250 (idx 233-249)
    _writeN(page, 233, m.c49);
    // [52] Total BI import. bienes: pos 1169-1185 (idx 1168-1184)
    _writeN(page, 1168, m.c52);
    // [53] Total cuota import. bienes: pos 1186-1202 (idx 1185-1201)
    _writeN(page, 1185, m.c53);
    // [56] Total BI adquis. intra. bienes: pos 1645-1661 (idx 1644-1660)
    _writeN(page, 1644, m.c56);
    // [57] Total cuota adquis. intra. bienes: pos 1662-1678 (idx 1661-1677)
    _writeN(page, 1661, m.c57);
    // Pos 1679-1828: reservado AEAT
    // Pos 1829-1840: </T39003000> (12 chars, idx 1828-1839)
    _write(page, 1828, '</T39003000>');

    return page.join();
  }

  // ─── PÁGINA 4 — IVA deducible bienes de inversión (854 posiciones) ─────────

  String construirPagina4(Modelo390 m) {
    final page = List<String>.filled(854, ' ');

    _write(page, 0, '<T39004000>');

    // [58] Total BI adq. intra. b.inv.: pos 217-233 (idx 216-232)
    _writeN(page, 216, m.c58);
    // [59] Total cuota adq. intra. b.inv.: pos 234-250 (idx 233-249)
    _writeN(page, 233, m.c59);
    // [62] Rectificación deducciones: pos 574-590 (idx 573-589)
    _writeN(page, 573, m.c522); // c522 = regularización prorrata → casilla 62
    // [63] Regularización inversiones: pos 625-641 (idx 624-640)
    _writeN(page, 624, m.c63);
    // [64] Suma de deducciones: pos 642-658 (idx 641-657)
    _writeN(page, 641, m.c64);
    // [65] Resultado régimen general: pos 659-675 (idx 658-674)
    _writeN(page, 658, m.c65);
    // Pos 693-842: reservado AEAT (pos 693-842 = idx 692-841, 150 chars)
    // Pos 843-854: </T39004000> (12 chars, idx 842-853)
    _write(page, 842, '</T39004000>');

    return page.join();
  }

  // ─── PÁGINA 6 — Resultado liquidación (828 posiciones) ─────────────────────

  String construirPagina6(Modelo390 m) {
    final page = List<String>.filled(828, ' ');

    _write(page, 0, '<T39006000>');

    // [84] Suma de resultados: pos 30-46 (idx 29-45)
    _writeN(page, 29, m.c84);
    // [85] Compensación ejercicio anterior: pos 64-80 (idx 63-79)
    _writeN(page, 63, m.c85);
    // [86] Resultado liquidación: pos 81-97 (idx 80-96)
    _writeN(page, 80, m.c86);
    // [95] Total a ingresar: pos 225-241 (idx 224-240)
    _writeN(page, 224, m.c86 > 0 ? m.c86 : 0);
    // [97] Último período a compensar: pos 276-292 (idx 275-291)
    _writeN(page, 275, m.c86 < 0 ? (-m.c86) : 0);
    // [98] Último período a devolver: pos 293-309 (idx 292-308) → 0 PYME
    _writeN(page, 292, 0);
    // [99] Volumen oper. régimen general: pos 361-377 (idx 360-376)
    _writeN(page, 360, m.c99);
    // [108] Total volumen: pos 650-666 (idx 649-665)
    _writeN(page, 649, m.c99 + m.c103 + m.c104 + m.c105 + m.c110);
    // Pos 667-816: reservado AEAT
    // Pos 817-828: </T39006000> (12 chars, idx 816-827)
    _write(page, 816, '</T39006000>');

    return page.join();
  }

  // ─── FORMATOS ──────────────────────────────────────────────────────────────

  /// Campo N (numérico con signo): 17 chars, alineado derecha, ceros izquierda.
  /// Negativos llevan "N" en primera posición.
  /// El importe se expresa con 2 decimales implícitos (sin separador).
  /// Ejemplo: 1234.56 → "00000000000123456"
  String formatearN(double importe, [int longitud = 17]) {
    final negativo = importe < 0;
    final abs = importe.abs();
    // Convertir a entero con 2 decimales implícitos
    final centimos = (abs * 100).round();
    final numStr = centimos.toString().padLeft(longitud - 1, '0');
    if (numStr.length > longitud - 1) {
      // Truncar si excede (no debería ocurrir con importes razonables)
      final truncado = numStr.substring(numStr.length - (longitud - 1));
      return negativo ? 'N$truncado' : '0${truncado.substring(1)}';
    }
    return negativo ? 'N$numStr' : '0$numStr';
  }

  /// Campo Num (solo dígitos): alineado derecha, ceros por izquierda.
  String formatearNum(int numero, int longitud) {
    return numero.toString().padLeft(longitud, '0').substring(
        (numero.toString().length > longitud)
            ? numero.toString().length - longitud
            : 0);
  }

  /// Campo An (alfanumérico): alineado izquierda, blancos por derecha.
  String formatearAn(String texto, int longitud) {
    final t = convertirISO88591(texto);
    if (t.length >= longitud) return t.substring(0, longitud);
    return t.padRight(longitud);
  }

  /// Convierte caracteres españoles a su equivalente ISO-8859-1.
  String convertirISO88591(String texto) {
    return texto
        .replaceAll('á', 'á')
        .replaceAll('é', 'é')
        .replaceAll('í', 'í')
        .replaceAll('ó', 'ó')
        .replaceAll('ú', 'ú')
        .replaceAll('Á', 'Á')
        .replaceAll('É', 'É')
        .replaceAll('Í', 'Í')
        .replaceAll('Ó', 'Ó')
        .replaceAll('Ú', 'Ú')
        .replaceAll('ñ', 'ñ')
        .replaceAll('Ñ', 'Ñ')
        .replaceAll('ü', 'ü')
        .replaceAll('Ü', 'Ü')
        .replaceAll('ç', 'ç')
        .replaceAll('Ç', 'Ç');
  }

  /// Codifica el fichero en ISO-8859-1.
  Uint8List codificarISO88591(String texto) {
    // En Dart, Latin1Codec es equivalente a ISO-8859-1
    final bytes = <int>[];
    for (final rune in texto.runes) {
      if (rune <= 0xFF) {
        bytes.add(rune);
      } else {
        // Carácter fuera de ISO-8859-1: reemplazar con '?'
        bytes.add(0x3F);
      }
    }
    return Uint8List.fromList(bytes);
  }

  // ─── HELPERS PRIVADOS ──────────────────────────────────────────────────────

  /// Escribe [texto] en [page] comenzando en [startIdx] (0-indexed).
  void _write(List<String> page, int startIdx, String texto) {
    for (var i = 0; i < texto.length; i++) {
      final idx = startIdx + i;
      if (idx < page.length) page[idx] = texto[i];
    }
  }

  /// Escribe un campo N (numérico con signo, 17 chars) en [page].
  void _writeN(List<String> page, int startIdx, double importe) {
    _write(page, startIdx, formatearN(importe));
  }
}




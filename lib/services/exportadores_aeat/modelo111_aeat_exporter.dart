import 'dart:typed_data';
import '../../domain/modelos/modelo111.dart';
import '../../domain/modelos/empresa_config.dart';

/// Exportador de Modelo 111 en formato posicional AEAT (DR111e16v18).
///
/// Genera fichero .txt con 2 registros de 500 chars cada uno.
/// Codificación: ISO-8859-1. Terminador: CRLF.
class Modelo111AeatExporter {
  static const int _regLen = 500;

  /// Genera el fichero AEAT como bytes ISO-8859-1.
  static Uint8List exportar({
    required Modelo111 modelo,
    required EmpresaConfig empresa,
  }) {
    _validar(modelo, empresa);

    final nif = _normalizarNif(empresa.nifNormalizado);
    final razon = _normalizarTexto(empresa.razonSocial);

    final reg1 = _buildRegistro1(modelo, nif, razon);
    final reg2 = _buildRegistro2(modelo, nif);

    // Verificar longitud (se ejecuta también en release, no solo en debug)
    if (reg1.length != _regLen) {
      throw StateError('MOD111 — Registro 1: longitud ${reg1.length} != $_regLen. '
          'Verificar campos posicionales.');
    }
    if (reg2.length != _regLen) {
      throw StateError('MOD111 — Registro 2: longitud ${reg2.length} != $_regLen. '
          'Verificar campos posicionales.');
    }
    assert(reg2.length == _regLen, 'Registro 2: ${reg2.length} != $_regLen');

    final contenido = '$reg1\r\n$reg2\r\n';
    return _encodeIso88591(contenido);
  }

  /// Genera el contenido como String (para tests).
  static String exportarTexto({
    required Modelo111 modelo,
    required EmpresaConfig empresa,
  }) {
    final bytes = exportar(modelo: modelo, empresa: empresa);
    return String.fromCharCodes(bytes);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGISTRO TIPO 1 — CABECERA DECLARANTE
  // ═══════════════════════════════════════════════════════════════════════════

  static String _buildRegistro1(Modelo111 m, String nif, String razon) {
    final buf = List<String>.filled(_regLen, ' ');

    // Pos 1-2: tipo registro "11"
    _write(buf, 0, '11');
    // Pos 3-4: modelo "11"
    _write(buf, 2, '11');
    // Pos 5-8: ejercicio
    _write(buf, 4, m.ejercicio.toString().padLeft(4, '0'));
    // Pos 9-10: período
    _write(buf, 8, m.periodoAeat.padRight(2));
    // Pos 11-19: NIF declarante (9 chars)
    _write(buf, 10, _padAlpha(nif, 9));
    // Pos 20-59: razón social (40 chars)
    _write(buf, 19, _padAlpha(razon, 40));
    // Pos 60: tipo declaración (I/N/C)
    _write(buf, 59, m.tipoAutomatico.codigo);
    // Pos 61-75: importe casilla 28 (15 dígitos, céntimos)
    _write(buf, 60, _importeCentimos(m.c28, 15));
    // Pos 76-80: número de páginas
    _write(buf, 75, '00001');

    return buf.join();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGISTRO TIPO 2 — DATOS LIQUIDACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  static String _buildRegistro2(Modelo111 m, String nif) {
    final buf = List<String>.filled(_regLen, ' ');

    // Pos 1-2: tipo registro "21"
    _write(buf, 0, '21');
    // Pos 3-4: modelo "11"
    _write(buf, 2, '11');
    // Pos 5-8: ejercicio
    _write(buf, 4, m.ejercicio.toString().padLeft(4, '0'));
    // Pos 9-10: período
    _write(buf, 8, m.periodoAeat.padRight(2));
    // Pos 11-19: NIF declarante
    _write(buf, 10, _padAlpha(nif, 9));

    // Sección I — Rendimientos del trabajo
    _write(buf, 19, _padNum(m.c01, 5));     // 20-24: c01
    _write(buf, 24, _importeCentimos(m.c02, 15)); // 25-39: c02
    _write(buf, 39, _importeCentimos(m.c03, 15)); // 40-54: c03
    _write(buf, 54, _padNum(m.c04, 5));     // 55-59: c04
    _write(buf, 59, _importeCentimos(m.c05, 15)); // 60-74: c05
    _write(buf, 74, _importeCentimos(m.c06, 15)); // 75-89: c06

    // Sección II — Rendimientos actividades económicas
    _write(buf, 89, _padNum(m.c07, 5));     // 90-94
    _write(buf, 94, _importeCentimos(m.c08, 15)); // 95-109
    _write(buf, 109, _importeCentimos(m.c09, 15)); // 110-124
    _write(buf, 124, _padNum(m.c10, 5));    // 125-129
    _write(buf, 129, _importeCentimos(m.c11, 15)); // 130-144
    _write(buf, 144, _importeCentimos(m.c12, 15)); // 145-159

    // Sección III — Premios
    _write(buf, 159, _padNum(m.c13, 5));    // 160-164
    _write(buf, 164, _importeCentimos(m.c14, 15)); // 165-179
    _write(buf, 179, _importeCentimos(m.c15, 15)); // 180-194
    _write(buf, 194, _padNum(m.c16, 5));    // 195-199
    _write(buf, 199, _importeCentimos(m.c17, 15)); // 200-214
    _write(buf, 214, _importeCentimos(m.c18, 15)); // 215-229

    // Sección IV — Forestales
    _write(buf, 229, _padNum(m.c19, 5));    // 230-234
    _write(buf, 234, _importeCentimos(m.c20, 15)); // 235-249
    _write(buf, 249, _importeCentimos(m.c21, 15)); // 250-264
    _write(buf, 264, _padNum(m.c22, 5));    // 265-269
    _write(buf, 269, _importeCentimos(m.c23, 15)); // 270-284
    _write(buf, 284, _importeCentimos(m.c24, 15)); // 285-299

    // Sección V — Cesión derechos imagen
    _write(buf, 299, _padNum(m.c25, 5));    // 300-304
    _write(buf, 304, _importeCentimos(m.c26, 15)); // 305-319
    _write(buf, 319, _importeCentimos(m.c27, 15)); // 320-334

    // Totales
    _write(buf, 334, _importeCentimos(m.c28, 15)); // 335-349: c28
    _write(buf, 349, _importeCentimos(m.c29, 15)); // 350-364: c29
    _write(buf, 364, _importeCentimos(m.c30, 15)); // 365-379: c30

    return buf.join();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════════════════

  static void _write(List<String> buf, int pos, String texto) {
    for (var i = 0; i < texto.length && (pos + i) < buf.length; i++) {
      buf[pos + i] = texto[i];
    }
  }

  static String _padAlpha(String valor, int len) {
    if (valor.length >= len) return valor.substring(0, len);
    return valor.padRight(len);
  }

  static String _padNum(int valor, int len) {
    final s = valor.abs().toString();
    if (s.length >= len) return s.substring(s.length - len);
    return s.padLeft(len, '0');
  }

  /// Convierte euros a céntimos y formatea con ceros a la izquierda.
  static String _importeCentimos(double euros, int len) {
    final centimos = (euros.abs() * 100).round();
    return centimos.toString().padLeft(len, '0');
  }

  static String _normalizarNif(String nif) {
    final limpio = nif.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return limpio.length <= 9 ? limpio : limpio.substring(0, 9);
  }

  static String _normalizarTexto(String input) {
    const map = {
      'á': 'A', 'à': 'A', 'ä': 'A', 'â': 'A',
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A',
      'é': 'E', 'è': 'E', 'ë': 'E', 'ê': 'E',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'í': 'I', 'ì': 'I', 'ï': 'I', 'î': 'I',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'ó': 'O', 'ò': 'O', 'ö': 'O', 'ô': 'O',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
      'ú': 'U', 'ù': 'U', 'ü': 'U', 'û': 'U',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'ñ': 'N', 'Ñ': 'N', 'ç': 'C', 'Ç': 'C',
    };
    final sb = StringBuffer();
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      sb.write(map[c] ?? c);
    }
    return sb.toString().toUpperCase();
  }

  static Uint8List _encodeIso88591(String s) {
    return Uint8List.fromList(s.codeUnits.map((c) => c > 255 ? 0x3F : c).toList());
  }

  static void _validar(Modelo111 m, EmpresaConfig e) {
    if (!e.tieneNifValido) {
      throw const FormatException('NIF declarante inválido para MOD 111');
    }
    if (!RegExp(r'^[1-4]T$').hasMatch(m.trimestre)) {
      throw FormatException('Trimestre inválido: ${m.trimestre}');
    }
  }
}



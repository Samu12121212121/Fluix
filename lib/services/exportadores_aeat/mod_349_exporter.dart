import 'dart:typed_data';

import '../../domain/modelos/empresa_config.dart';

enum ClaveOperacion349 {
  entregasExentas('E'),
  adquisiciones('A'),
  triangulares('T'),
  prestacionServicios('S'),
  adquisicionServicios('I'),
  entregasPostImportacion('M'),
  entregasPostImportacionRepFiscal('H'),
  transferenciasConsigna('R'),
  devolucionesConsigna('D'),
  sustitucionesConsigna('C');

  const ClaveOperacion349(this.codigo);
  final String codigo;
}

class Operador349 {
  final String codigoPaisNif;
  final String numeroNif;
  final String razonSocial;
  final ClaveOperacion349 claveOperacion;
  final double baseImponible;
  final String? codigoPaisSustituto;
  final String? nifSustituto;
  final String? nombreSustituto;

  const Operador349({
    required this.codigoPaisNif,
    required this.numeroNif,
    required this.razonSocial,
    required this.claveOperacion,
    required this.baseImponible,
    this.codigoPaisSustituto,
    this.nifSustituto,
    this.nombreSustituto,
  });
}

class Rectificacion349 {
  final String codigoPaisNif;
  final String numeroNif;
  final String razonSocial;
  final ClaveOperacion349 claveOperacion;
  final int ejercicioRectificado;
  final String periodoRectificado;
  final double baseImponibleRectificada;
  final double baseImponibleAnterior;
  final String? codigoPaisSustituto;
  final String? nifSustituto;
  final String? nombreSustituto;

  const Rectificacion349({
    required this.codigoPaisNif,
    required this.numeroNif,
    required this.razonSocial,
    required this.claveOperacion,
    required this.ejercicioRectificado,
    required this.periodoRectificado,
    required this.baseImponibleRectificada,
    required this.baseImponibleAnterior,
    this.codigoPaisSustituto,
    this.nifSustituto,
    this.nombreSustituto,
  });
}

class DatosMod349 {
  final EmpresaConfig empresa;
  final int ejercicio;
  final String periodo;
  final List<Operador349> operadores;
  final List<Rectificacion349> rectificaciones;
  final bool cambioPeriodicidad;
  final String telefonoContacto;
  final String nombreContacto;
  final bool declaracionComplementaria;
  final bool declaracionSustitutiva;
  final String numeroDeclaracionAnterior;
  final String nifRepresentanteLegal;
  final String? numeroDeclaracion;

  const DatosMod349({
    required this.empresa,
    required this.ejercicio,
    required this.periodo,
    required this.operadores,
    this.rectificaciones = const [],
    this.cambioPeriodicidad = false,
    this.telefonoContacto = '',
    this.nombreContacto = '',
    this.declaracionComplementaria = false,
    this.declaracionSustitutiva = false,
    this.numeroDeclaracionAnterior = '',
    this.nifRepresentanteLegal = '',
    this.numeroDeclaracion,
  });
}

class Mod349Exporter {
  static const int _registroLen = 500;
  static const String _placeholderLegacyNif = 'A12345678';

  Future<Uint8List> exportar(DatosMod349 datos) async {
    final nifDeclarante = _normalizarNifDeclarante(datos.empresa.nifNormalizado);
    if (nifDeclarante == _placeholderLegacyNif || !datos.empresa.tieneNifValido) {
      throw const FormatException('NIF declarante invalido para MOD 349');
    }
    _validarPeriodo(datos.periodo);

    final lineas = <String>[
      _buildRegistroTipo1(datos),
      ...datos.operadores
          .map((o) => _buildRegistroOperador(o, nifDeclarante, datos.ejercicio)),
      ...datos.rectificaciones
          .map((r) => _buildRegistroRectificacion(r, nifDeclarante, datos.ejercicio)),
    ];

    final contenido = '${lineas.join('\r\n')}\r\n';
    return _encodeIso88591(contenido);
  }

  String _buildRegistroTipo1(DatosMod349 d) {
    var buf = ' ' * _registroLen;
    final nifDeclarante = _normalizarNifDeclarante(d.empresa.nifNormalizado);

    final totalOperadores = d.operadores.length;
    final importeOperadores = d.operadores.fold<double>(
      0,
      (s, op) => s + op.baseImponible,
    );
    final totalRectificaciones = d.rectificaciones.length;
    final importeRectificaciones = d.rectificaciones.fold<double>(
      0,
      (s, r) => s + r.baseImponibleRectificada.abs(),
    );

    buf = _setNumeric(buf, 1, 1, 1);
    buf = _setNumeric(buf, 2, 4, 349);
    buf = _setNumeric(buf, 5, 8, d.ejercicio);
    buf = _setAlpha(buf, 9, 17, nifDeclarante.padLeft(9, '0'));
    buf = _setAlpha(buf, 18, 57, d.empresa.razonSocial);
    buf = _setAlpha(buf, 58, 58, ' ');
    buf = _setAlpha(buf, 59, 67, _soloDigitos(d.telefonoContacto).padLeft(9, '0'));
    buf = _setAlpha(buf, 68, 107, d.nombreContacto);
    buf = _setAlpha(buf, 108, 120, _numeroDeclaracion(d));
    buf = _setAlpha(buf, 121, 121, d.declaracionComplementaria ? 'C' : ' ');
    buf = _setAlpha(buf, 122, 122, d.declaracionSustitutiva ? 'S' : ' ');
    buf = _setAlpha(
      buf,
      123,
      135,
      _soloDigitos(d.numeroDeclaracionAnterior).padLeft(13, '0'),
    );
    buf = _setAlpha(buf, 136, 137, d.periodo);
    buf = _setNumeric(buf, 138, 146, totalOperadores);
    buf = _setImporteConDecimal(buf, 147, 159, 160, 161, importeOperadores);
    buf = _setNumeric(buf, 162, 170, totalRectificaciones);
    buf = _setImporteConDecimal(buf, 171, 183, 184, 185, importeRectificaciones);
    buf = _setAlpha(buf, 186, 186, d.cambioPeriodicidad ? 'X' : ' ');
    buf = _setAlpha(buf, 391, 399, d.nifRepresentanteLegal);

    return buf;
  }

  String _buildRegistroOperador(Operador349 op, String nifDeclarante, int ejercicio) {
    var buf = ' ' * _registroLen;

    buf = _setNumeric(buf, 1, 1, 2);
    buf = _setNumeric(buf, 2, 4, 349);
    buf = _setNumeric(buf, 5, 8, ejercicio);
    buf = _setAlpha(buf, 9, 17, nifDeclarante.padLeft(9, '0'));
    buf = _setAlpha(buf, 76, 77, op.codigoPaisNif);
    buf = _setAlpha(buf, 78, 92, op.numeroNif);
    buf = _setAlpha(buf, 93, 132, op.razonSocial);
    buf = _setAlpha(buf, 133, 133, op.claveOperacion.codigo);
    buf = _setImporteConDecimal(buf, 134, 144, 145, 146, op.baseImponible);

    if (op.claveOperacion == ClaveOperacion349.sustitucionesConsigna) {
      buf = _setAlpha(buf, 179, 180, op.codigoPaisSustituto ?? '');
      buf = _setAlpha(buf, 181, 195, op.nifSustituto ?? '');
      buf = _setAlpha(buf, 196, 235, op.nombreSustituto ?? '');
    }

    return buf;
  }

  String _buildRegistroRectificacion(
    Rectificacion349 r,
    String nifDeclarante,
    int ejercicio,
  ) {
    var buf = ' ' * _registroLen;

    _validarPeriodoRectificacion(r.periodoRectificado);

    buf = _setNumeric(buf, 1, 1, 2);
    buf = _setNumeric(buf, 2, 4, 349);
    buf = _setNumeric(buf, 5, 8, ejercicio);
    buf = _setAlpha(buf, 9, 17, nifDeclarante.padLeft(9, '0'));
    buf = _setAlpha(buf, 76, 77, r.codigoPaisNif);
    buf = _setAlpha(buf, 78, 92, r.numeroNif);
    buf = _setAlpha(buf, 93, 132, r.razonSocial);
    buf = _setAlpha(buf, 133, 133, r.claveOperacion.codigo);
    buf = _setNumeric(buf, 147, 150, r.ejercicioRectificado);
    buf = _setAlpha(buf, 151, 152, r.periodoRectificado);
    buf = _setImporteConDecimal(
      buf,
      153,
      163,
      164,
      165,
      r.baseImponibleRectificada,
    );
    buf = _setImporteConDecimal(
      buf,
      166,
      176,
      177,
      178,
      r.baseImponibleAnterior,
    );

    if (r.claveOperacion == ClaveOperacion349.sustitucionesConsigna) {
      buf = _setAlpha(buf, 179, 180, r.codigoPaisSustituto ?? '');
      buf = _setAlpha(buf, 181, 195, r.nifSustituto ?? '');
      buf = _setAlpha(buf, 196, 235, r.nombreSustituto ?? '');
    }

    return buf;
  }

  String _setAlpha(String buf, int inicio, int fin, String valor) {
    final out = buf.split('');
    final len = fin - inicio + 1;
    final limpio = _normalizarTexto(valor);
    final ajustado = limpio.length > len
        ? limpio.substring(0, len)
        : limpio.padRight(len, ' ');
    out.replaceRange(inicio - 1, fin, ajustado.split(''));
    return out.join();
  }

  String _setNumeric(String buf, int inicio, int fin, num valor) {
    final out = buf.split('');
    final len = fin - inicio + 1;
    final numerico = valor
        .toString()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .padLeft(len, '0');
    final ajustado = numerico.substring(numerico.length - len);
    out.replaceRange(inicio - 1, fin, ajustado.split(''));
    return out.join();
  }

  String _setImporteConDecimal(
    String buf,
    int posEntIni,
    int posEntFin,
    int posDecIni,
    int posDecFin,
    double importe,
  ) {
    final centimos = (importe.abs() * 100).round();
    final entera = centimos ~/ 100;
    final decimal = centimos % 100;
    var out = _setNumeric(buf, posEntIni, posEntFin, entera);
    out = _setNumeric(out, posDecIni, posDecFin, decimal);
    return out;
  }

  Uint8List _encodeIso88591(String s) {
    return Uint8List.fromList(s.codeUnits.map((c) {
      if (c > 255) return 0x3F;
      return c;
    }).toList());
  }

  void _validarPeriodo(String periodo) {
    const permitidos = {
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      '07',
      '08',
      '09',
      '10',
      '11',
      '12',
      '1T',
      '2T',
      '3T',
      '4T',
    };
    if (!permitidos.contains(periodo)) {
      throw FormatException('Periodo MOD 349 invalido: $periodo');
    }
  }

  void _validarPeriodoRectificacion(String periodo) {
    const permitidos = {
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      '07',
      '08',
      '09',
      '10',
      '11',
      '12',
      '1T',
      '2T',
      '3T',
      '4T',
      '0A',
    };
    if (!permitidos.contains(periodo)) {
      throw FormatException('Periodo rectificado invalido: $periodo');
    }
  }

  String _normalizarNifDeclarante(String nif) {
    final limpio = nif.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (limpio.length <= 9) return limpio;
    return limpio.substring(0, 9);
  }

  String _normalizarTexto(String input) {
    final map = <String, String>{
      'á': 'A',
      'à': 'A',
      'ä': 'A',
      'â': 'A',
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'é': 'E',
      'è': 'E',
      'ë': 'E',
      'ê': 'E',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'í': 'I',
      'ì': 'I',
      'ï': 'I',
      'î': 'I',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'ó': 'O',
      'ò': 'O',
      'ö': 'O',
      'ô': 'O',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'ú': 'U',
      'ù': 'U',
      'ü': 'U',
      'û': 'U',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'ñ': 'N',
      'Ñ': 'N',
      'ç': 'C',
      'Ç': 'C',
    };

    final sb = StringBuffer();
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      sb.write(map[c] ?? c);
    }
    return sb.toString().toUpperCase();
  }

  String _soloDigitos(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String _numeroDeclaracion(DatosMod349 d) {
    if (d.numeroDeclaracion != null && d.numeroDeclaracion!.trim().isNotEmpty) {
      final digits = _soloDigitos(d.numeroDeclaracion!);
      final padded = digits.padLeft(13, '0');
      return padded.substring(padded.length - 13);
    }

    final periodoNum = {
          '01': '01',
          '02': '02',
          '03': '03',
          '04': '04',
          '05': '05',
          '06': '06',
          '07': '07',
          '08': '08',
          '09': '09',
          '10': '10',
          '11': '11',
          '12': '12',
          '1T': '13',
          '2T': '23',
          '3T': '33',
          '4T': '43',
        }[d.periodo] ??
        '00';

    return '349${d.ejercicio.toString().padLeft(4, '0')}${periodoNum}0000';
  }
}



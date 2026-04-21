import 'dart:typed_data';
import '../../domain/modelos/factura.dart';
import '../../domain/modelos/factura_recibida.dart';

// ── CONSTANTES ────────────────────────────────────────────────────────────────
const double _kUmbral347 = 3005.06; // Art. 33 RD 1065/2007
const int _kRegistroLen = 500;

// ── ENUMS ─────────────────────────────────────────────────────────────────────

/// Clave de operación oficial AEAT Mod.347 (corregida según BOE).
/// A=adquisiciones (compras), B=entregas (ventas), C=cobros por cuenta terceros.
enum ClaveOperacion347 {
  adquisiciones('A', 'Adquisiciones bienes/servicios'),
  entregas('B', 'Entregas bienes/servicios'),
  cobros('C', 'Cobros por cuenta terceros');

  final String codigo;
  final String etiqueta;
  const ClaveOperacion347(this.codigo, this.etiqueta);
}

enum SituacionInmueble {
  conRefCatastral('1'),
  paisVascaNavarra('2'),
  sinRefCatastral('3'),
  extranjero('4');

  final String codigo;
  const SituacionInmueble(this.codigo);
}

// ── MODELOS ───────────────────────────────────────────────────────────────────

class ImportesTrimestral {
  final double t1;
  final double t2;
  final double t3;
  final double t4;

  const ImportesTrimestral({
    this.t1 = 0, this.t2 = 0, this.t3 = 0, this.t4 = 0,
  });

  double get total => t1 + t2 + t3 + t4;
}

class Operacion347 {
  final String nifTercero;
  final String nombreTercero;
  final ClaveOperacion347 clave;
  final double totalAnual; // IVA incluido, en EUROS
  final ImportesTrimestral trimestres;
  final bool esArrendamiento;
  final bool superaUmbral;
  // Datos NIF comunitario (pos 264-280)
  final String? codigoPaisNifComunitario;
  final String? numeroNifComunitario;

  const Operacion347({
    required this.nifTercero,
    required this.nombreTercero,
    required this.clave,
    required this.totalAnual,
    required this.trimestres,
    this.esArrendamiento = false,
    this.superaUmbral = false,
    this.codigoPaisNifComunitario,
    this.numeroNifComunitario,
  });
}

class InmuebleArrendado {
  final String nifArrendatario;
  final String nombreArrendatario;
  final double importeAnual; // EUROS
  final SituacionInmueble situacion;
  final String? refCatastral;
  final String? tipoVia;
  final String? nombreVia;
  final String? numero;
  final String? bloque;
  final String? escalera;
  final String? planta;
  final String? puerta;
  final String? municipio;
  final String? codigoMunicipioINE;
  final String? codigoPostal;
  final String? provincia;
  final String? codigoProvinciaINE;

  const InmuebleArrendado({
    required this.nifArrendatario,
    required this.nombreArrendatario,
    required this.importeAnual,
    this.situacion = SituacionInmueble.sinRefCatastral,
    this.refCatastral,
    this.tipoVia,
    this.nombreVia,
    this.numero,
    this.bloque,
    this.escalera,
    this.planta,
    this.puerta,
    this.municipio,
    this.codigoMunicipioINE,
    this.codigoPostal,
    this.provincia,
    this.codigoProvinciaINE,
  });
}

class Resumen347 {
  final int anio;
  final List<Operacion347> operacionesVenta;   // clave B
  final List<Operacion347> operacionesCompra;  // clave A
  final List<InmuebleArrendado> inmuebles;
  final double totalVentas;
  final double totalCompras;
  final int numDeclaraciones;

  const Resumen347({
    required this.anio,
    required this.operacionesVenta,
    required this.operacionesCompra,
    this.inmuebles = const [],
    required this.totalVentas,
    required this.totalCompras,
    required this.numDeclaraciones,
  });
}

// ── EXPORTADOR ────────────────────────────────────────────────────────────────

class Mod347Exporter {
  // ── CÁLCULO ──────────────────────────────────────────────────────────────

  static Resumen347 calcular({
    required int anio,
    required List<Factura> facturasEmitidas,
    required List<FacturaRecibida> facturasRecibidas,
  }) {
    // VENTAS (clave B)
    final mapaVentas = <String, _Acumulado>{};
    for (final f in facturasEmitidas) {
      if (f.estado == EstadoFactura.anulada) continue;
      final nif = f.datosFiscales?.nif;
      if (nif == null || nif.isEmpty) continue;
      if (f.datosFiscales?.esIntracomunitario ?? false) continue; // → 349
      final acum = mapaVentas.putIfAbsent(nif, () => _Acumulado(
        nif: nif,
        nombre: f.datosFiscales?.razonSocial ?? f.clienteNombre,
      ));
      acum.add(_trimestre(f.fechaEmision), f.total);
    }

    // COMPRAS (clave A)
    final mapaCompras = <String, _Acumulado>{};
    for (final f in facturasRecibidas) {
      if (f.estado == EstadoFacturaRecibida.rechazada) continue;
      final nif = f.nifProveedor;
      if (nif.isEmpty) continue;
      if (f.esArrendamiento && (f.importeRetencion ?? 0) > 0) continue; // → 115/180
      if (f.esIntracomunitario) continue;                      // → 349
      final acum = mapaCompras.putIfAbsent(nif, () => _Acumulado(
        nif: nif,
        nombre: f.nombreProveedor,
      ));
      acum.add(_trimestre(f.fechaRecepcion), f.totalConImpuestos);
    }

    List<Operacion347> _toOps(_Acumulado a, ClaveOperacion347 clave) {
      final trim = ImportesTrimestral(
        t1: _r2(a.t1), t2: _r2(a.t2),
        t3: _r2(a.t3), t4: _r2(a.t4),
      );
      final total = _r2(trim.total);
      return [
        Operacion347(
          nifTercero: a.nif,
          nombreTercero: a.nombre,
          clave: clave,
          totalAnual: total,
          trimestres: trim,
          superaUmbral: total >= _kUmbral347,
        )
      ];
    }

    final ventas = mapaVentas.values
        .expand((a) => _toOps(a, ClaveOperacion347.entregas))
        .where((o) => o.superaUmbral)
        .toList()
      ..sort((a, b) => b.totalAnual.compareTo(a.totalAnual));

    final compras = mapaCompras.values
        .expand((a) => _toOps(a, ClaveOperacion347.adquisiciones))
        .where((o) => o.superaUmbral)
        .toList()
      ..sort((a, b) => b.totalAnual.compareTo(a.totalAnual));

    return Resumen347(
      anio: anio,
      operacionesVenta: ventas,
      operacionesCompra: compras,
      totalVentas: ventas.fold(0, (s, o) => s + o.totalAnual),
      totalCompras: compras.fold(0, (s, o) => s + o.totalAnual),
      numDeclaraciones: ventas.length + compras.length,
    );
  }

  // ── GENERACIÓN FICHERO ────────────────────────────────────────────────────

  /// Genera el fichero MOD 347 posicional AEAT.
  /// 500 chars + CRLF por registro, ISO-8859-1, importes en EUROS con decimal.
  static Uint8List generarFichero({
    required String nifDeclarante,
    required String nombreDeclarante,
    required Resumen347 resumen,
    String telefonoContacto = '',
    String nombreContacto = '',
    String? nifRepresentanteLegal,
    bool esComplementaria = false,
    bool esSustitutiva = false,
    String? nDeclaracionAnterior,
  }) {
    final lineas = <String>[
      _tipo1(
        nifDeclarante: nifDeclarante,
        nombreDeclarante: nombreDeclarante,
        resumen: resumen,
        telefono: telefonoContacto,
        contacto: nombreContacto,
        nifRepresentante: nifRepresentanteLegal,
        complementaria: esComplementaria,
        sustitutiva: esSustitutiva,
        nDeclaracionAnterior: nDeclaracionAnterior,
      ),
      for (final op in [...resumen.operacionesVenta, ...resumen.operacionesCompra])
        _tipo2Declarado(nifDeclarante, resumen.anio, op),
      for (final inm in resumen.inmuebles)
        _tipo2Inmueble(nifDeclarante, resumen.anio, inm),
    ];

    return _encodeIso88591('${lineas.join('\r\n')}\r\n');
  }

  static String generarFicheroTexto({
    required String nifDeclarante,
    required String nombreDeclarante,
    required Resumen347 resumen,
  }) =>
      String.fromCharCodes(generarFichero(
        nifDeclarante: nifDeclarante,
        nombreDeclarante: nombreDeclarante,
        resumen: resumen,
      ));

  // ── REGISTRO TIPO 1 ───────────────────────────────────────────────────────

  static String _tipo1({
    required String nifDeclarante,
    required String nombreDeclarante,
    required Resumen347 resumen,
    String telefono = '',
    String contacto = '',
    String? nifRepresentante,
    bool complementaria = false,
    bool sustitutiva = false,
    String? nDeclaracionAnterior,
  }) {
    final buf = _buf();
    _w(buf, 0, '1');
    _w(buf, 1, '347');
    _w(buf, 4, resumen.anio.toString().padLeft(4, '0'));
    _w(buf, 8, _nif9(nifDeclarante));
    _w(buf, 17, _al(_norm(nombreDeclarante), 40));
    _w(buf, 57, 'T'); // soporte telemático
    _w(buf, 58, _soloDigitos(telefono).padLeft(9, '0'));
    _w(buf, 67, _al(_norm(contacto), 40));
    // pos 108-120: número identificativo (13 chars)
    final numId = '347${resumen.anio}${_soloDigitos(_nif9(nifDeclarante))}'.padRight(13).substring(0, 13);
    _w(buf, 107, numId);
    _w(buf, 120, complementaria ? 'C' : ' ');
    _w(buf, 121, sustitutiva ? 'S' : ' ');
    _w(buf, 122, _soloDigitos(nDeclaracionAnterior ?? '').padLeft(13, '0'));
    // pos 136-144: total personas/entidades (9 dígitos)
    final totalEntidades = resumen.numDeclaraciones + resumen.inmuebles.length;
    _w(buf, 135, totalEntidades.toString().padLeft(9, '0'));
    // pos 145: signo importe total
    final importeTotal = resumen.totalVentas + resumen.totalCompras;
    _w(buf, 144, importeTotal < 0 ? 'N' : ' ');
    // pos 146-158: entera (13d), pos 159-160: decimal (2d)
    _wImporteDecimal(buf, 145, importeTotal.abs());
    // pos 161-169: total inmuebles
    _w(buf, 160, resumen.inmuebles.length.toString().padLeft(9, '0'));
    // pos 170: signo arrendamientos
    final importeAlq = resumen.inmuebles.fold<double>(0, (s, i) => s + i.importeAnual);
    _w(buf, 169, importeAlq < 0 ? 'N' : ' ');
    // pos 171-183: entera (13d), pos 184-185: decimal (2d)
    _wImporteDecimal(buf, 170, importeAlq.abs());
    // pos 391-399: NIF representante legal
    if (nifRepresentante != null && nifRepresentante.isNotEmpty) {
      _w(buf, 390, _nif9(nifRepresentante));
    }
    assert(buf.length == _kRegistroLen);
    return buf.join();
  }

  // ── REGISTRO TIPO 2 — DECLARADO (hoja D) ─────────────────────────────────

  static String _tipo2Declarado(String nifDeclarante, int anio, Operacion347 op) {
    final buf = _buf();
    _w(buf, 0, '2');
    _w(buf, 1, '347');
    _w(buf, 4, anio.toString().padLeft(4, '0'));
    _w(buf, 8, _nif9(nifDeclarante));
    _w(buf, 17, _nif9(op.nifTercero));
    // pos 27-35: NIF representante declarado (blancos)
    _w(buf, 35, _al(_norm(op.nombreTercero), 40)); // pos 36-75
    _w(buf, 75, 'D'); // pos 76: tipo hoja
    _w(buf, 76, '28'); // pos 77-78: código provincia (default 28=Madrid)
    // pos 79-80: código país ISO (blancos para residentes)
    _w(buf, 80, ' '); // pos 81: blanco
    _w(buf, 81, op.clave.codigo); // pos 82: clave
    _w(buf, 82, op.totalAnual < 0 ? 'N' : ' '); // pos 83: signo
    // pos 84-96: entera(13d), pos 97-98: decimal(2d)
    _wImporteDecimal(buf, 83, op.totalAnual.abs());
    _w(buf, 98, ' '); // pos 99: operación seguro
    _w(buf, 99, op.esArrendamiento ? 'X' : ' '); // pos 100: arrendamiento
    _w(buf, 100, '0' * 15); // pos 101-115: importe metálico
    _w(buf, 115, '0' * 16); // pos 116-131: transmisiones inmuebles IVA
    _w(buf, 131, '0000'); // pos 132-135: ejercicio cobro metálico
    // Desglose trimestral (pos 136-263): signo(1)+entera(13)+decimal(2)=16 por trimestre
    // + transmisiones inmuebles por trimestre: 16 → total 32 por trimestre
    _wTrimestreDecimal(buf, 135, op.trimestres.t1); // pos 136-151
    _w(buf, 151, '0' * 16);                          // pos 152-167
    _wTrimestreDecimal(buf, 167, op.trimestres.t2); // pos 168-183
    _w(buf, 183, '0' * 16);                          // pos 184-199
    _wTrimestreDecimal(buf, 199, op.trimestres.t3); // pos 200-215
    _w(buf, 215, '0' * 16);                          // pos 216-231
    _wTrimestreDecimal(buf, 231, op.trimestres.t4); // pos 232-247
    _w(buf, 247, '0' * 16);                          // pos 248-263
    // pos 264-265: código país NIF comunitario
    if (op.codigoPaisNifComunitario != null) {
      _w(buf, 263, _al(op.codigoPaisNifComunitario!, 2));
    }
    // pos 266-280: número NIF comunitario (15 chars izquierda)
    if (op.numeroNifComunitario != null) {
      _w(buf, 265, _al(op.numeroNifComunitario!, 15));
    }
    assert(buf.length == _kRegistroLen);
    return buf.join();
  }

  // ── REGISTRO TIPO 2 — INMUEBLE (hoja I) ──────────────────────────────────

  static String _tipo2Inmueble(String nifDeclarante, int anio, InmuebleArrendado inm) {
    final buf = _buf();
    _w(buf, 0, '2');
    _w(buf, 1, '347');
    _w(buf, 4, anio.toString().padLeft(4, '0'));
    _w(buf, 8, _nif9(nifDeclarante));
    _w(buf, 17, _nif9(inm.nifArrendatario));
    // pos 27-35: NIF representante arrendatario (blancos)
    _w(buf, 35, _al(_norm(inm.nombreArrendatario), 40)); // pos 36-75
    _w(buf, 75, 'I'); // pos 76: tipo hoja
    // pos 77-98: BLANCOS (22 chars) — ya inicializados
    _w(buf, 98, inm.importeAnual < 0 ? 'N' : ' '); // pos 99: signo
    // pos 100-114: entera(13d)+decimal(2d) = 15 chars (EUROS)
    _wImporteDecimal(buf, 99, inm.importeAnual.abs());
    _w(buf, 114, inm.situacion.codigo); // pos 115
    _w(buf, 115, _al(inm.refCatastral ?? '', 25)); // pos 116-140
    _w(buf, 140, _al(_norm(inm.tipoVia ?? 'CL'), 5)); // pos 141-145
    _w(buf, 145, _al(_norm(inm.nombreVia ?? ''), 50)); // pos 146-195
    _w(buf, 195, _al('NUM', 3)); // pos 196-198
    final numCasa = _soloDigitos(inm.numero ?? '0').padLeft(5, '0');
    _w(buf, 198, numCasa.length > 5 ? numCasa.substring(0, 5) : numCasa); // pos 199-203
    // pos 204-206: calificador (blancos)
    _w(buf, 206, _al(inm.bloque ?? '', 2)); // pos 207-208
    // pos 209-210: portal (blancos)
    _w(buf, 210, _al(inm.escalera ?? '', 2)); // pos 211-212
    _w(buf, 212, _al(inm.planta ?? '', 3)); // pos 213-215
    _w(buf, 215, _al(inm.puerta ?? '', 3)); // pos 216-218
    // pos 219-258: complemento (blancos)
    _w(buf, 258, _al(_norm(inm.municipio ?? ''), 40)); // pos 259-298
    _w(buf, 298, _al(inm.codigoMunicipioINE ?? '', 10)); // pos 299-308
    final cp = _soloDigitos(inm.codigoPostal ?? '').padLeft(5, '0');
    _w(buf, 308, _al(cp, 10)); // pos 309-318
    _w(buf, 318, _al(_norm(inm.provincia ?? ''), 10)); // pos 319-328
    _w(buf, 328, _soloDigitos(inm.codigoProvinciaINE ?? '99').padLeft(2, '0')); // pos 329-330
    // pos 331-500: blancos
    assert(buf.length == _kRegistroLen);
    return buf.join();
  }

  // ── UTILIDADES ────────────────────────────────────────────────────────────

  static List<String> _buf() => List<String>.filled(_kRegistroLen, ' ');

  static void _w(List<String> buf, int pos, String texto) {
    for (var i = 0; i < texto.length && (pos + i) < buf.length; i++) {
      buf[pos + i] = texto[i];
    }
  }

  /// Escribe importe en EUROS: entera (13d) + decimal (2d) en posición pos.
  static void _wImporteDecimal(List<String> buf, int pos, double importe) {
    final absVal = importe.abs();
    final enteros = absVal.truncate();
    final decimales = ((absVal - enteros) * 100).round();
    _w(buf, pos, enteros.toString().padLeft(13, '0'));
    _w(buf, pos + 13, decimales.toString().padLeft(2, '0'));
  }

  /// Escribe campo trimestral: signo(1) + entera(13) + decimal(2) = 16 chars.
  static void _wTrimestreDecimal(List<String> buf, int pos, double importe) {
    _w(buf, pos, importe < 0 ? 'N' : ' ');
    _wImporteDecimal(buf, pos + 1, importe.abs());
  }

  static String _nif9(String nif) {
    final clean = nif.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return clean.length >= 9 ? clean.substring(0, 9) : clean.padLeft(9, '0');
  }

  static String _al(String valor, int len) =>
      valor.length >= len ? valor.substring(0, len) : valor.padRight(len);

  static String _soloDigitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  static double _r2(double v) => (v * 100).roundToDouble() / 100;

  static int _trimestre(DateTime fecha) {
    if (fecha.month <= 3) return 1;
    if (fecha.month <= 6) return 2;
    if (fecha.month <= 9) return 3;
    return 4;
  }

  static String _norm(String input) {
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

  static Uint8List _encodeIso88591(String s) =>
      Uint8List.fromList(s.codeUnits.map((c) => c > 255 ? 0x3F : c).toList());
}

// ── ACUMULADOR INTERNO ────────────────────────────────────────────────────────

class _Acumulado {
  final String nif;
  final String nombre;
  double t1 = 0, t2 = 0, t3 = 0, t4 = 0;

  _Acumulado({required this.nif, required this.nombre});

  void add(int trimestre, double importe) {
    switch (trimestre) {
      case 1: t1 += importe; break;
      case 2: t2 += importe; break;
      case 3: t3 += importe; break;
      case 4: t4 += importe; break;
    }
  }
}

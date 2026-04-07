class DatosDr303e26v101 {
  final String nifDeclarante;
  final String nombreRazonSocial;
  final int ejercicio;
  final String periodo; // 01..12 o 1T..4T
  final int tipoDeclaracion;

  // Configuracion de cabecera pagina 01
  final int tributacionForalImportacion;
  final int inscritoRegistroDevolucionMensual;
  final int tributaRegimenSimplificado;
  final int autoliquidacionConjunta;
  final int criterioCaja;
  final int destinatarioCriterioCaja;
  final int opcionProrrataEspecial;
  final int revocacionProrrataEspecial;
  final int declaradoEnConcurso;
  final String fechaAutoConcurso; // DDMMYYYY o blanco
  final String tipoAutoliqConcurso; // 1/2/blanco
  final int acogidoSii;
  final int exonerado390;
  final int volumenDistintoCero;
  final int derechoDeducirGasoleos;

  // Casillas numericas de 17 posiciones (15 enteros + 2 decimales)
  final Map<String, double> casillas;

  // Casillas porcentaje 5 posiciones (3 enteros + 2 decimales)
  final Map<String, double> porcentajes5;

  final bool sinActividad;
  final bool autoliquidacionRectificativa;
  final String numeroJustificanteAnterior; // 13
  final bool solicitudBajaModificacionDomiciliacion;
  final bool motivoRectificacionGeneral;
  final bool motivoRectificacionSentencia;

  // Forma de pago en pagina 03: D/C/R o blanco
  final String formaPago;
  final String iban;
  final String nrc;

  // Envolvente AUX (normalmente para EEDD)
  final String versionPrograma;
  final String nifEmpresaDesarrollo;

  // Pagina DID opcional
  final bool incluirDid;
  final String swiftBic;
  final String ibanDevolucion;
  final String bancoDevolucion;
  final String direccionBanco;
  final String ciudadBanco;
  final String codigoPaisBanco;
  final int marcaSepa; // 0..3

  const DatosDr303e26v101({
    required this.nifDeclarante,
    required this.nombreRazonSocial,
    required this.ejercicio,
    required this.periodo,
    this.tipoDeclaracion = 1,
    this.tributacionForalImportacion = 2,
    this.inscritoRegistroDevolucionMensual = 2,
    this.tributaRegimenSimplificado = 3,
    this.autoliquidacionConjunta = 2,
    this.criterioCaja = 2,
    this.destinatarioCriterioCaja = 2,
    this.opcionProrrataEspecial = 2,
    this.revocacionProrrataEspecial = 2,
    this.declaradoEnConcurso = 2,
    this.fechaAutoConcurso = '',
    this.tipoAutoliqConcurso = '',
    this.acogidoSii = 2,
    this.exonerado390 = 2,
    this.volumenDistintoCero = 2,
    this.derechoDeducirGasoleos = 2,
    this.casillas = const {},
    this.porcentajes5 = const {},
    this.sinActividad = false,
    this.autoliquidacionRectificativa = false,
    this.numeroJustificanteAnterior = '',
    this.solicitudBajaModificacionDomiciliacion = false,
    this.motivoRectificacionGeneral = false,
    this.motivoRectificacionSentencia = false,
    this.formaPago = '',
    this.iban = '',
    this.nrc = '',
    this.versionPrograma = '0000',
    this.nifEmpresaDesarrollo = '000000000',
    this.incluirDid = false,
    this.swiftBic = '',
    this.ibanDevolucion = '',
    this.bancoDevolucion = '',
    this.direccionBanco = '',
    this.ciudadBanco = '',
    this.codigoPaisBanco = '',
    this.marcaSepa = 0,
  });
}

class Dr303e26v101Exporter {
  String exportar(DatosDr303e26v101 d) {
    _validar(d);

    final paginas = <String>[
      _buildPagina01(d),
      _buildPagina03(d),
      if (d.incluirDid) _buildPaginaDid(d),
    ];

    final open = '<T3030${d.ejercicio.toString().padLeft(4, '0')}${d.periodo}0000>';
    final aux = _buildAux(d);
    final close = '</T3030${d.ejercicio.toString().padLeft(4, '0')}${d.periodo}0000>';

    return '$open\r\n$aux\r\n${paginas.join('\r\n')}\r\n$close';
  }

  String _buildAux(DatosDr303e26v101 d) {
    final b = StringBuffer();
    b.write('<AUX>');
    b.write(' ' * 70);
    b.write(_alpha(d.versionPrograma, 4));
    b.write(' ' * 4);
    b.write(_alpha(d.nifEmpresaDesarrollo, 9));
    b.write(' ' * 213);
    b.write('</AUX>');
    return b.toString();
  }

  String _buildPagina01(DatosDr303e26v101 d) {
    final b = StringBuffer();
    b.write('<T30301000>');

    b.write(' '); // Indicador complementaria
    b.write(_num(d.tipoDeclaracion, 1));
    b.write(_alpha(_cleanId(d.nifDeclarante), 9));
    b.write(_alpha(d.nombreRazonSocial, 80));
    b.write(_num(d.ejercicio, 4));
    b.write(_alpha(d.periodo, 2));

    b.write(_num(d.tributacionForalImportacion, 1));
    b.write(_num(d.inscritoRegistroDevolucionMensual, 1));
    b.write(_num(d.tributaRegimenSimplificado, 1));
    b.write(_num(d.autoliquidacionConjunta, 1));
    b.write(_num(d.criterioCaja, 1));
    b.write(_num(d.destinatarioCriterioCaja, 1));
    b.write(_num(d.opcionProrrataEspecial, 1));
    b.write(_num(d.revocacionProrrataEspecial, 1));
    b.write(_num(d.declaradoEnConcurso, 1));
    b.write(_alpha(_soloDigitos(d.fechaAutoConcurso), 8));
    b.write(_alpha(d.tipoAutoliqConcurso, 1));
    b.write(_num(d.acogidoSii, 1));
    b.write(_num(d.exonerado390, 1));
    b.write(_num(d.volumenDistintoCero, 1));
    b.write(_num(d.derechoDeducirGasoleos, 1));

    // IVA devengado regimen general
    b.write(_impNum(d.casillas['150'] ?? 0));
    b.write(_pctConst('00000'));
    b.write(_impNum(d.casillas['152'] ?? 0));
    b.write(_impNum(d.casillas['165'] ?? 0));
    b.write(_pctConst('00000'));
    b.write(_impNum(d.casillas['167'] ?? 0));
    b.write(_impNum(d.casillas['01'] ?? 0));
    b.write(_pctConst('00400'));
    b.write(_impNum(d.casillas['03'] ?? 0));
    b.write(_impNum(d.casillas['153'] ?? 0));
    b.write(_pctConst('01000'));
    b.write(_impNum(d.casillas['155'] ?? 0));
    b.write(_impNum(d.casillas['04'] ?? 0));
    b.write(_pctConst('02100'));
    b.write(_impNum(d.casillas['06'] ?? 0));
    b.write(_impNum(d.casillas['156'] ?? 0));
    b.write(_pct5(d.porcentajes5['157'] ?? 0));
    b.write(_impNum(d.casillas['158'] ?? 0));
    b.write(_impNum(d.casillas['159'] ?? 0));
    b.write(_pct5(d.porcentajes5['160'] ?? 0));
    b.write(_impNum(d.casillas['161'] ?? 0));
    b.write(_impN(d.casillas['500'] ?? 0));
    b.write(_impN(d.casillas['501'] ?? 0));
    b.write(_impNum(d.casillas['07'] ?? 0));
    b.write(_impNum(d.casillas['08'] ?? 0));
    b.write(_impNum(d.casillas['09'] ?? 0));
    b.write(_impNum(d.casillas['10'] ?? 0));
    b.write(_impNum(d.casillas['11'] ?? 0));
    b.write(_impNum(d.casillas['12'] ?? 0));
    b.write(_impNum(d.casillas['13'] ?? 0));
    b.write(_impNum(d.casillas['14'] ?? 0));
    b.write(_impNum(d.casillas['15'] ?? 0));
    b.write(_impNum(d.casillas['16'] ?? 0));
    b.write(_impNum(d.casillas['17'] ?? 0));
    b.write(_impN(d.casillas['18'] ?? 0));
    b.write(_impN(d.casillas['46'] ?? 0));

    // IVA deducible regimen general
    b.write(_impNum(d.casillas['19'] ?? 0));
    b.write(_impNum(d.casillas['20'] ?? 0));
    b.write(_impNum(d.casillas['21'] ?? 0));
    b.write(_impNum(d.casillas['22'] ?? 0));
    b.write(_impNum(d.casillas['23'] ?? 0));
    b.write(_impNum(d.casillas['24'] ?? 0));
    b.write(_impNum(d.casillas['25'] ?? 0));
    b.write(_impNum(d.casillas['26'] ?? 0));
    b.write(_impNum(d.casillas['27'] ?? 0));
    b.write(_impNum(d.casillas['28'] ?? 0));
    b.write(_impNum(d.casillas['29'] ?? 0));
    b.write(_impNum(d.casillas['30'] ?? 0));
    b.write(_impN(d.casillas['31'] ?? 0));
    b.write(_impN(d.casillas['32'] ?? 0));
    b.write(_impN(d.casillas['33'] ?? 0));
    b.write(_impN(d.casillas['34'] ?? 0));
    b.write(_impN(d.casillas['47'] ?? 0));
    b.write(_impN(d.casillas['48'] ?? 0));
    b.write(_alpha((d.casillas['prorrata_activa'] ?? 0) > 0 ? 'S' : '', 1));
    b.write(_impN(d.casillas['49'] ?? 0));
    b.write(_impN(d.casillas['50'] ?? 0));
    b.write(_impN(d.casillas['51'] ?? 0));
    b.write(_impN(d.casillas['52'] ?? 0));
    b.write(_impN(d.casillas['53'] ?? 0));
    b.write(_impN(d.casillas['54'] ?? 0));
    b.write(_impN(d.casillas['55'] ?? 0));
    b.write(_impN(d.casillas['56'] ?? 0));
    b.write(_impN(d.casillas['57'] ?? 0));
    b.write(_impN(d.casillas['58'] ?? 0));

    b.write('</T30301000>');
    return b.toString();
  }

  String _buildPagina03(DatosDr303e26v101 d) {
    final b = StringBuffer();
    b.write('<T30303000>');

    b.write(_impN(d.casillas['59'] ?? 0));
    b.write(_impN(d.casillas['60'] ?? 0));
    b.write(_impN(d.casillas['120'] ?? 0));
    b.write(_impN(d.casillas['122'] ?? 0));
    b.write(_impN(d.casillas['123'] ?? 0));
    b.write(_impN(d.casillas['124'] ?? 0));
    b.write(_impN(d.casillas['62'] ?? 0));
    b.write(_impN(d.casillas['63'] ?? 0));
    b.write(_impN(d.casillas['74'] ?? 0));
    b.write(_impN(d.casillas['75'] ?? 0));
    b.write(_impN(d.casillas['76'] ?? 0));
    b.write(_impN(d.casillas['64'] ?? 0));
    b.write(_pct5(d.porcentajes5['65'] ?? 100));
    b.write(_impN(d.casillas['66'] ?? 0));
    b.write(_impNum(d.casillas['77'] ?? 0));
    b.write(_impNum(d.casillas['110'] ?? 0));
    b.write(_impNum(d.casillas['78'] ?? 0));
    b.write(_impNum(d.casillas['87'] ?? 0));
    b.write(_impN(d.casillas['68'] ?? 0));
    b.write(_impN(d.casillas['108'] ?? 0));
    b.write(_impN(d.casillas['69'] ?? 0));
    b.write(_impNum(d.casillas['70'] ?? 0));
    b.write(_impNum(d.casillas['109'] ?? 0));
    b.write(_impNum(d.casillas['112'] ?? 0));
    b.write(_impN(d.casillas['71'] ?? 0));

    b.write(_alpha(d.sinActividad ? 'X' : '', 1));
    b.write(_alpha(d.autoliquidacionRectificativa ? 'X' : '', 1));
    b.write(_alpha(_soloDigitos(d.numeroJustificanteAnterior), 13));
    b.write(_alpha(d.solicitudBajaModificacionDomiciliacion ? 'X' : '', 1));
    b.write(_impNum(d.casillas['111'] ?? 0));
    b.write(_alpha(d.motivoRectificacionGeneral ? 'X' : '', 1));
    b.write(_alpha(d.motivoRectificacionSentencia ? 'X' : '', 1));
    b.write(_alpha(d.formaPago, 1));
    b.write(_alpha(_cleanIban(d.iban), 34));
    b.write(_alpha(_soloAlnum(d.nrc), 22));

    b.write('</T30303000>');
    return b.toString();
  }

  String _buildPaginaDid(DatosDr303e26v101 d) {
    final b = StringBuffer();
    b.write('<T303DID00>');
    b.write(_alpha(_soloAlnum(d.swiftBic), 11));
    b.write(_alpha(_cleanIban(d.ibanDevolucion), 34));
    b.write(_alpha(d.bancoDevolucion, 70));
    b.write(_alpha(d.direccionBanco, 35));
    b.write(_alpha(d.ciudadBanco, 30));
    b.write(_alpha(d.codigoPaisBanco, 2));
    b.write(_num(d.marcaSepa, 1));
    b.write(' ' * 617);
    b.write('</T303DID00>');
    return b.toString();
  }

  String _alpha(String value, int len) {
    final clean = _soloAlnumEspacios(value).toUpperCase();
    if (clean.length >= len) return clean.substring(0, len);
    return clean.padRight(len, ' ');
  }

  String _num(num value, int len) {
    final clean = value
        .toString()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .padLeft(len, '0');
    return clean.substring(clean.length - len);
  }

  String _impNum(double value) {
    final cents = (value.abs() * 100).round();
    return _num(cents, 17);
  }

  String _impN(double value) {
    if (value < 0) {
      final cents = (value.abs() * 100).round();
      return 'N${_num(cents, 16)}';
    }
    return _impNum(value);
  }

  String _pctConst(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '').padLeft(5, '0');
    return clean.substring(clean.length - 5);
  }

  String _pct5(double value) {
    final raw = (value * 100).round();
    return _num(raw, 5);
  }

  String _cleanId(String value) => _soloAlnum(value).toUpperCase();

  String _cleanIban(String value) => _soloAlnum(value).toUpperCase();

  String _soloDigitos(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String _soloAlnum(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  String _soloAlnumEspacios(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ');

  void _validar(DatosDr303e26v101 d) {
    if (!RegExp(r'^[0-9]{4}$').hasMatch(d.ejercicio.toString())) {
      throw const FormatException('Ejercicio invalido');
    }
    if (!RegExp(r'^(0[1-9]|1[0-2]|[1-4]T)$').hasMatch(d.periodo)) {
      throw const FormatException('Periodo invalido');
    }
    final nif = _cleanId(d.nifDeclarante);
    if (nif.isEmpty || nif.length > 9) {
      throw const FormatException('NIF declarante invalido');
    }
    final fp = d.formaPago.trim().toUpperCase();
    if (fp.isNotEmpty && !const {'D', 'C', 'R'}.contains(fp)) {
      throw const FormatException('Forma de pago invalida');
    }
    if (d.autoliquidacionRectificativa &&
        d.numeroJustificanteAnterior.trim().isEmpty) {
      throw const FormatException(
        'Falta numero justificante anterior para rectificativa',
      );
    }
    if (d.incluirDid && (d.marcaSepa < 0 || d.marcaSepa > 3)) {
      throw const FormatException('Marca SEPA invalida');
    }
  }
}



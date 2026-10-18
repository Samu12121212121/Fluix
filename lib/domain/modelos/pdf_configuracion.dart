import 'package:cloud_firestore/cloud_firestore.dart';

// ── Modelo PdfConfiguracion ───────────────────────────────────────────────────
// Fuente única de verdad para todos los datos que aparecen en los PDFs de una
// empresa. Se guarda en empresas/{empresaId}/configuracion/pdf.
// Las 49 plantillas leen de aquí; ningún texto de tipo está escrito a mano.

// ── Tipos de vía normalizados ────────────────────────────────────────────────
const kTiposVia = [
  'Calle', 'Avenida', 'Plaza', 'Paseo', 'Camino', 'Carretera',
  'Ronda', 'Travesía', 'Boulevard', 'Urbanización', 'Polígono', 'Otro',
];

// ── Configuración por tipo de documento ──────────────────────────────────────
class ConfigTipoDocPdf {
  final String titulo;           // "Factura", "Presupuesto", "Albarán"
  final String etiquetaCliente;  // "Cliente", "Presupuesto para", "Entregar a"
  final int diasVencimiento;     // 30 para facturas; 0 para albarán
  final String pieLegal;         // texto del footer
  final String? notasDefecto;
  final bool mostrarPago;
  final bool mostrarColumnaIva;
  final bool mostrarImportes;    // albarán valorado/sin valorar
  final bool mostrarFirma;       // recuadro firma en albarán
  final bool mostrarVerifactu;   // QR solo en factura/rectificativa
  final double tipoIvaDefecto;
  final String? condiciones;     // condiciones del presupuesto

  const ConfigTipoDocPdf({
    required this.titulo,
    required this.etiquetaCliente,
    required this.diasVencimiento,
    required this.pieLegal,
    this.notasDefecto,
    required this.mostrarPago,
    required this.mostrarColumnaIva,
    required this.mostrarImportes,
    required this.mostrarFirma,
    required this.mostrarVerifactu,
    required this.tipoIvaDefecto,
    this.condiciones,
  });

  factory ConfigTipoDocPdf.fromMap(Map<String, dynamic> m) => ConfigTipoDocPdf(
    titulo: m['titulo'] as String? ?? 'Documento',
    etiquetaCliente: m['etiqueta_cliente'] as String? ?? 'Cliente',
    diasVencimiento: (m['dias_vencimiento'] as num?)?.toInt() ?? 30,
    pieLegal: m['pie_legal'] as String? ?? '',
    notasDefecto: m['notas_defecto'] as String?,
    mostrarPago: m['mostrar_pago'] as bool? ?? true,
    mostrarColumnaIva: m['mostrar_columna_iva'] as bool? ?? true,
    mostrarImportes: m['mostrar_importes'] as bool? ?? true,
    mostrarFirma: m['mostrar_firma'] as bool? ?? false,
    mostrarVerifactu: m['mostrar_verifactu'] as bool? ?? false,
    tipoIvaDefecto: (m['tipo_iva_defecto'] as num?)?.toDouble() ?? 21.0,
    condiciones: m['condiciones'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'etiqueta_cliente': etiquetaCliente,
    'dias_vencimiento': diasVencimiento,
    'pie_legal': pieLegal,
    if (notasDefecto != null) 'notas_defecto': notasDefecto,
    'mostrar_pago': mostrarPago,
    'mostrar_columna_iva': mostrarColumnaIva,
    'mostrar_importes': mostrarImportes,
    'mostrar_firma': mostrarFirma,
    'mostrar_verifactu': mostrarVerifactu,
    'tipo_iva_defecto': tipoIvaDefecto,
    if (condiciones != null) 'condiciones': condiciones,
  };

  ConfigTipoDocPdf copyWith({
    String? titulo, String? etiquetaCliente, int? diasVencimiento,
    String? pieLegal, String? notasDefecto, bool? mostrarPago,
    bool? mostrarColumnaIva, bool? mostrarImportes, bool? mostrarFirma,
    bool? mostrarVerifactu, double? tipoIvaDefecto, String? condiciones,
  }) => ConfigTipoDocPdf(
    titulo: titulo ?? this.titulo,
    etiquetaCliente: etiquetaCliente ?? this.etiquetaCliente,
    diasVencimiento: diasVencimiento ?? this.diasVencimiento,
    pieLegal: pieLegal ?? this.pieLegal,
    notasDefecto: notasDefecto ?? this.notasDefecto,
    mostrarPago: mostrarPago ?? this.mostrarPago,
    mostrarColumnaIva: mostrarColumnaIva ?? this.mostrarColumnaIva,
    mostrarImportes: mostrarImportes ?? this.mostrarImportes,
    mostrarFirma: mostrarFirma ?? this.mostrarFirma,
    mostrarVerifactu: mostrarVerifactu ?? this.mostrarVerifactu,
    tipoIvaDefecto: tipoIvaDefecto ?? this.tipoIvaDefecto,
    condiciones: condiciones ?? this.condiciones,
  );

  // Defaults por tipo
  static const factura = ConfigTipoDocPdf(
    titulo: 'Factura', etiquetaCliente: 'Cliente', diasVencimiento: 30,
    pieLegal: 'Factura emitida conforme al Real Decreto 1619/2012.',
    mostrarPago: true, mostrarColumnaIva: true, mostrarImportes: true,
    mostrarFirma: false, mostrarVerifactu: true, tipoIvaDefecto: 21.0,
  );
  static const rectificativa = ConfigTipoDocPdf(
    titulo: 'Factura Rectificativa', etiquetaCliente: 'Cliente', diasVencimiento: 0,
    pieLegal: 'Factura rectificativa emitida conforme al Art. 15 del R.D. 1619/2012.',
    mostrarPago: false, mostrarColumnaIva: true, mostrarImportes: true,
    mostrarFirma: false, mostrarVerifactu: true, tipoIvaDefecto: 21.0,
  );
  static const presupuesto = ConfigTipoDocPdf(
    titulo: 'Presupuesto', etiquetaCliente: 'Cliente', diasVencimiento: 30,
    pieLegal: 'Documento sin validez fiscal. No constituye factura a efectos del R.D. 1619/2012.',
    mostrarPago: false, mostrarColumnaIva: true, mostrarImportes: true,
    mostrarFirma: false, mostrarVerifactu: false, tipoIvaDefecto: 21.0,
  );
  static const proforma = ConfigTipoDocPdf(
    titulo: 'Proforma', etiquetaCliente: 'Cliente', diasVencimiento: 30,
    pieLegal: 'Factura proforma. No constituye factura a efectos del R.D. 1619/2012.',
    mostrarPago: false, mostrarColumnaIva: true, mostrarImportes: true,
    mostrarFirma: false, mostrarVerifactu: false, tipoIvaDefecto: 21.0,
  );
  static const albaran = ConfigTipoDocPdf(
    titulo: 'Albarán', etiquetaCliente: 'Entregar a', diasVencimiento: 0,
    pieLegal: 'Albarán de entrega. Firme y selle el documento como conformidad de recepción.',
    mostrarPago: false, mostrarColumnaIva: false, mostrarImportes: false,
    mostrarFirma: true, mostrarVerifactu: false, tipoIvaDefecto: 21.0,
  );
  static const fichajes = ConfigTipoDocPdf(
    titulo: 'Informe de Fichajes', etiquetaCliente: 'Empleado', diasVencimiento: 0,
    pieLegal: 'Informe de control horario conforme al R.D.L. 8/2019.',
    mostrarPago: false, mostrarColumnaIva: false, mostrarImportes: false,
    mostrarFirma: false, mostrarVerifactu: false, tipoIvaDefecto: 0.0,
  );
  static const informeInterno = ConfigTipoDocPdf(
    titulo: 'Informe Interno', etiquetaCliente: 'Dirigido a', diasVencimiento: 0,
    pieLegal: 'Documento de uso interno. Confidencial.',
    mostrarPago: false, mostrarColumnaIva: false, mostrarImportes: false,
    mostrarFirma: false, mostrarVerifactu: false, tipoIvaDefecto: 0.0,
  );
}

// ── Modelo principal ──────────────────────────────────────────────────────────
class PdfConfiguracion {
  // EMISOR
  final String razonSocial;
  final String? nombreComercial;
  final String cif;
  final String tipoVia;
  final String nombreVia;
  final String numero;
  final String? pisoPorta;
  final String codigoPostal;
  final String localidad;
  final String provincia;
  final String pais;
  final String? telefono;
  final String? email;
  final String? web;
  final String? logoUrl;
  final String? registroMercantil;

  // PAGO
  final String? ibanTitular;
  final String? ibanBanco;
  final String? iban;
  final List<String> metodosAceptados;
  final String? textoPagoAdicional;

  // SERIES
  final String prefijoFactura;
  final String prefijoRectificativa;
  final String prefijoPresupuesto;
  final String prefijoProforma;
  final String prefijoAlbaran;

  // CONFIG POR TIPO — keys: 'factura','rectificativa','presupuesto','proforma','albaran','fichajes','informeInterno'
  final Map<String, ConfigTipoDocPdf> configPorTipo;

  // DISEÑO POR TIPO
  final Map<String, String> layoutPorTipo;
  final Map<String, String> colorPorTipo;

  final DateTime updatedAt;

  const PdfConfiguracion({
    required this.razonSocial, this.nombreComercial, required this.cif,
    required this.tipoVia, required this.nombreVia, required this.numero,
    this.pisoPorta, required this.codigoPostal, required this.localidad,
    required this.provincia, this.pais = 'España',
    this.telefono, this.email, this.web, this.logoUrl, this.registroMercantil,
    this.ibanTitular, this.ibanBanco, this.iban,
    this.metodosAceptados = const ['transferencia'],
    this.textoPagoAdicional,
    this.prefijoFactura = 'F',
    this.prefijoRectificativa = 'R',
    this.prefijoPresupuesto = 'PRES',
    this.prefijoProforma = 'PF',
    this.prefijoAlbaran = 'ALB',
    required this.configPorTipo,
    this.layoutPorTipo = const {},
    this.colorPorTipo = const {},
    required this.updatedAt,
  });

  // ── Dirección compuesta ────────────────────────────────────────────────────

  String get domicilioLinea1 {
    final pp = pisoPorta?.trim() ?? '';
    return [tipoVia, nombreVia, numero, if (pp.isNotEmpty) pp]
        .where((s) => s.isNotEmpty).join(', ');
  }

  String get domicilioLinea2 {
    final prov = provincia.trim();
    final loc = localidad.trim();
    return [codigoPostal, loc, if (prov.isNotEmpty && prov != loc) prov]
        .where((s) => s.isNotEmpty).join(' ');
  }

  String get domicilioCompleto =>
      '${domicilioLinea1.trim()} · ${domicilioLinea2.trim()}'.trim();

  // ── Validación para facturas ───────────────────────────────────────────────

  bool get datosEmisorCompletos =>
      razonSocial.isNotEmpty && cif.isNotEmpty &&
      nombreVia.isNotEmpty && codigoPostal.isNotEmpty && localidad.isNotEmpty;

  List<String> get camposFaltantes {
    final f = <String>[];
    if (razonSocial.isEmpty) f.add('Razón social');
    if (cif.isEmpty) f.add('CIF/NIF');
    if (nombreVia.isEmpty) f.add('Dirección (calle)');
    if (codigoPostal.isEmpty) f.add('Código postal');
    if (localidad.isEmpty) f.add('Localidad');
    return f;
  }

  // ── Config por tipo (con fallback a defaults) ──────────────────────────────

  ConfigTipoDocPdf cfgTipo(String tipoKey) =>
      configPorTipo[tipoKey] ?? _defaultParaTipo(tipoKey);

  static ConfigTipoDocPdf _defaultParaTipo(String key) => switch (key) {
    'rectificativa' => ConfigTipoDocPdf.rectificativa,
    'presupuesto'   => ConfigTipoDocPdf.presupuesto,
    'proforma'      => ConfigTipoDocPdf.proforma,
    'albaran'       => ConfigTipoDocPdf.albaran,
    'fichajes'      => ConfigTipoDocPdf.fichajes,
    'informeInterno'=> ConfigTipoDocPdf.informeInterno,
    _               => ConfigTipoDocPdf.factura,
  };

  // ── Prefijo por tipo key ────────────────────────────────────────────────────

  String prefijoParaTipo(String tipoKey) => switch (tipoKey) {
    'rectificativa' => prefijoRectificativa,
    'presupuesto'   => prefijoPresupuesto,
    'proforma'      => prefijoProforma,
    'albaran'       => prefijoAlbaran,
    _               => prefijoFactura,
  };

  // ── Serialización ─────────────────────────────────────────────────────────

  factory PdfConfiguracion.fromMap(Map<String, dynamic> m) {
    final cfgRaw = m['config_por_tipo'] as Map<String, dynamic>? ?? {};
    final cfg = cfgRaw.map((k, v) =>
        MapEntry(k, ConfigTipoDocPdf.fromMap(v as Map<String, dynamic>)));
    return PdfConfiguracion(
      razonSocial: m['razon_social'] as String? ?? '',
      nombreComercial: m['nombre_comercial'] as String?,
      cif: m['cif'] as String? ?? '',
      tipoVia: m['tipo_via'] as String? ?? 'Calle',
      nombreVia: m['nombre_via'] as String? ?? '',
      numero: m['numero'] as String? ?? '',
      pisoPorta: m['piso_porta'] as String?,
      codigoPostal: m['codigo_postal'] as String? ?? '',
      localidad: m['localidad'] as String? ?? '',
      provincia: m['provincia'] as String? ?? '',
      pais: m['pais'] as String? ?? 'España',
      telefono: m['telefono'] as String?,
      email: m['email'] as String?,
      web: m['web'] as String?,
      logoUrl: m['logo_url'] as String?,
      registroMercantil: m['registro_mercantil'] as String?,
      ibanTitular: m['iban_titular'] as String?,
      ibanBanco: m['iban_banco'] as String?,
      iban: m['iban'] as String?,
      metodosAceptados: List<String>.from(m['metodos_aceptados'] as List? ?? ['transferencia']),
      textoPagoAdicional: m['texto_pago_adicional'] as String?,
      prefijoFactura: m['prefijo_factura'] as String? ?? 'F',
      prefijoRectificativa: m['prefijo_rectificativa'] as String? ?? 'R',
      prefijoPresupuesto: m['prefijo_presupuesto'] as String? ?? 'PRES',
      prefijoProforma: m['prefijo_proforma'] as String? ?? 'PF',
      prefijoAlbaran: m['prefijo_albaran'] as String? ?? 'ALB',
      configPorTipo: cfg,
      layoutPorTipo: Map<String, String>.from(m['layout_por_tipo'] as Map? ?? {}),
      colorPorTipo: Map<String, String>.from(m['color_por_tipo'] as Map? ?? {}),
      updatedAt: (m['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'razon_social': razonSocial,
    if (nombreComercial != null) 'nombre_comercial': nombreComercial,
    'cif': cif,
    'tipo_via': tipoVia,
    'nombre_via': nombreVia,
    'numero': numero,
    if (pisoPorta != null) 'piso_porta': pisoPorta,
    'codigo_postal': codigoPostal,
    'localidad': localidad,
    'provincia': provincia,
    'pais': pais,
    if (telefono != null) 'telefono': telefono,
    if (email != null) 'email': email,
    if (web != null) 'web': web,
    if (logoUrl != null) 'logo_url': logoUrl,
    if (registroMercantil != null) 'registro_mercantil': registroMercantil,
    if (ibanTitular != null) 'iban_titular': ibanTitular,
    if (ibanBanco != null) 'iban_banco': ibanBanco,
    if (iban != null) 'iban': iban,
    'metodos_aceptados': metodosAceptados,
    if (textoPagoAdicional != null) 'texto_pago_adicional': textoPagoAdicional,
    'prefijo_factura': prefijoFactura,
    'prefijo_rectificativa': prefijoRectificativa,
    'prefijo_presupuesto': prefijoPresupuesto,
    'prefijo_proforma': prefijoProforma,
    'prefijo_albaran': prefijoAlbaran,
    'config_por_tipo': configPorTipo.map((k, v) => MapEntry(k, v.toMap())),
    'layout_por_tipo': layoutPorTipo,
    'color_por_tipo': colorPorTipo,
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  PdfConfiguracion copyWith({
    String? razonSocial, String? nombreComercial, String? cif,
    String? tipoVia, String? nombreVia, String? numero, String? pisoPorta,
    String? codigoPostal, String? localidad, String? provincia, String? pais,
    String? telefono, String? email, String? web, String? logoUrl,
    String? registroMercantil, String? ibanTitular, String? ibanBanco,
    String? iban, List<String>? metodosAceptados, String? textoPagoAdicional,
    String? prefijoFactura, String? prefijoRectificativa,
    String? prefijoPresupuesto, String? prefijoProforma, String? prefijoAlbaran,
    Map<String, ConfigTipoDocPdf>? configPorTipo,
    Map<String, String>? layoutPorTipo, Map<String, String>? colorPorTipo,
  }) => PdfConfiguracion(
    razonSocial: razonSocial ?? this.razonSocial,
    nombreComercial: nombreComercial ?? this.nombreComercial,
    cif: cif ?? this.cif,
    tipoVia: tipoVia ?? this.tipoVia,
    nombreVia: nombreVia ?? this.nombreVia,
    numero: numero ?? this.numero,
    pisoPorta: pisoPorta ?? this.pisoPorta,
    codigoPostal: codigoPostal ?? this.codigoPostal,
    localidad: localidad ?? this.localidad,
    provincia: provincia ?? this.provincia,
    pais: pais ?? this.pais,
    telefono: telefono ?? this.telefono,
    email: email ?? this.email,
    web: web ?? this.web,
    logoUrl: logoUrl ?? this.logoUrl,
    registroMercantil: registroMercantil ?? this.registroMercantil,
    ibanTitular: ibanTitular ?? this.ibanTitular,
    ibanBanco: ibanBanco ?? this.ibanBanco,
    iban: iban ?? this.iban,
    metodosAceptados: metodosAceptados ?? this.metodosAceptados,
    textoPagoAdicional: textoPagoAdicional ?? this.textoPagoAdicional,
    prefijoFactura: prefijoFactura ?? this.prefijoFactura,
    prefijoRectificativa: prefijoRectificativa ?? this.prefijoRectificativa,
    prefijoPresupuesto: prefijoPresupuesto ?? this.prefijoPresupuesto,
    prefijoProforma: prefijoProforma ?? this.prefijoProforma,
    prefijoAlbaran: prefijoAlbaran ?? this.prefijoAlbaran,
    configPorTipo: configPorTipo ?? this.configPorTipo,
    layoutPorTipo: layoutPorTipo ?? this.layoutPorTipo,
    colorPorTipo: colorPorTipo ?? this.colorPorTipo,
    updatedAt: DateTime.now(),
  );
}

// ── Validaciones ──────────────────────────────────────────────────────────────

bool validarNifEs(String nif) {
  final n = nif.trim().toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  return RegExp(r'^\d{8}[A-Z]$').hasMatch(n) ||
         RegExp(r'^[XYZ]\d{7}[A-Z]$').hasMatch(n) ||
         RegExp(r'^[ABCDEFGHJNPQRSUVW]\d{7}[0-9A-J]$').hasMatch(n);
}

bool validarIban(String iban) {
  final clean = iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (clean.length < 5 || clean.length > 34) return false;
  final rearranged = clean.substring(4) + clean.substring(0, 4);
  final numeric = rearranged.split('').map((c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) ? (code - 55).toString() : c;
  }).join('');
  int r = 0;
  for (final ch in numeric.split('')) { r = (r * 10 + int.parse(ch)) % 97; }
  return r == 1;
}

String formatearIban(String iban) {
  final clean = iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
  return clean.replaceAllMapped(RegExp(r'.{1,4}'), (m) => '${m.group(0)} ').trim();
}

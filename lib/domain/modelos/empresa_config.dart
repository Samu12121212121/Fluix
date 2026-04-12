import 'package:flutter/foundation.dart';
import '../../core/utils/validador_nif_cif.dart';
import 'empresa.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FORMA JURÍDICA
// ═══════════════════════════════════════════════════════════════════════════════

enum FormaJuridica {
  autonomo,
  sl,
  sa,
  slp,
  cooperativa,
  comunidadBienes,
  sociedadCivil,
}

extension FormaJuridicaExt on FormaJuridica {
  String get etiqueta {
    switch (this) {
      case FormaJuridica.autonomo:        return 'Autónomo';
      case FormaJuridica.sl:              return 'Sociedad Limitada (S.L.)';
      case FormaJuridica.sa:              return 'Sociedad Anónima (S.A.)';
      case FormaJuridica.slp:             return 'Sociedad Limitada Profesional (S.L.P.)';
      case FormaJuridica.cooperativa:     return 'Cooperativa';
      case FormaJuridica.comunidadBienes: return 'Comunidad de Bienes';
      case FormaJuridica.sociedadCivil:   return 'Sociedad Civil';
    }
  }

  String get valorFirestore {
    switch (this) {
      case FormaJuridica.autonomo:        return 'autonomo';
      case FormaJuridica.sl:              return 'sl';
      case FormaJuridica.sa:              return 'sa';
      case FormaJuridica.slp:             return 'slp';
      case FormaJuridica.cooperativa:     return 'cooperativa';
      case FormaJuridica.comunidadBienes: return 'comunidad_bienes';
      case FormaJuridica.sociedadCivil:   return 'sociedad_civil';
    }
  }

  /// true si es una sociedad mercantil (obligada a Modelo 200/202)
  bool get esSociedad =>
      this == FormaJuridica.sl ||
      this == FormaJuridica.sa ||
      this == FormaJuridica.slp ||
      this == FormaJuridica.cooperativa;

  /// true si tributa por IRPF (autónomos y asimilados → Modelo 130)
  bool get tributaIRPF =>
      this == FormaJuridica.autonomo ||
      this == FormaJuridica.comunidadBienes ||
      this == FormaJuridica.sociedadCivil;

  static FormaJuridica fromString(String? valor) {
    switch (valor) {
      case 'autonomo':        return FormaJuridica.autonomo;
      case 'sl':              return FormaJuridica.sl;
      case 'sa':              return FormaJuridica.sa;
      case 'slp':             return FormaJuridica.slp;
      case 'cooperativa':     return FormaJuridica.cooperativa;
      case 'comunidad_bienes': return FormaJuridica.comunidadBienes;
      case 'sociedad_civil':  return FormaJuridica.sociedadCivil;
      default:                return FormaJuridica.autonomo;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════

const String _kNifPlaceholderLegacy = 'A12345678';

String _stringOrEmpty(dynamic value) => (value ?? '').toString().trim();

bool _esNifPlaceholderLegacy(String nif) =>
    ValidadorNifCif.limpiar(nif) == _kNifPlaceholderLegacy;

String _resolverNifEmpresa(
  Map<String, dynamic> empresa,
  Map<String, dynamic> fiscal,
) {
  final candidatos = <String>[
    _stringOrEmpty(fiscal['nif']),
    _stringOrEmpty(empresa['nif']),
    _stringOrEmpty(empresa['cif']),
  ];

  for (final candidato in candidatos) {
    if (candidato.isNotEmpty && !_esNifPlaceholderLegacy(candidato)) {
      return candidato;
    }
  }

  return candidatos.firstWhere((c) => c.isNotEmpty, orElse: () => '');
}

@immutable
class EmpresaConfig {
  final String nif;
  final String razonSocial;
  final String domicilioFiscal;
  final String codigoPostal;
  final String municipio;
  final String provincia;
  final String regimenIVA; // general / simplificado / recc
  final String epigrafIAE;
  final bool estaEnSII;
  final CriterioIVA criterioIva;
  final String ibanEmpresa;
  final String bicEmpresa;
  final FormaJuridica formaJuridica;
  // Prefijos de serie (máx. 5 caracteres)
  final String serieFactura;       // default 'F'
  final String serieRectificativa; // default 'R'
  final String serieProforma;      // default 'P'

  const EmpresaConfig({
    this.nif = '',
    this.razonSocial = '',
    this.domicilioFiscal = '',
    this.codigoPostal = '',
    this.municipio = '',
    this.provincia = '',
    this.regimenIVA = 'general',
    this.epigrafIAE = '',
    this.estaEnSII = false,
    this.criterioIva = CriterioIVA.devengo,
    this.ibanEmpresa = '',
    this.bicEmpresa = '',
    this.formaJuridica = FormaJuridica.autonomo,
    this.serieFactura = 'F',
    this.serieRectificativa = 'R',
    this.serieProforma = 'P',
  });

  factory EmpresaConfig.fromSources({
    Map<String, dynamic>? empresaDoc,
    Map<String, dynamic>? fiscalDoc,
  }) {
    final empresa = empresaDoc ?? <String, dynamic>{};
    final fiscal = fiscalDoc ?? <String, dynamic>{};

    return EmpresaConfig(
      nif: _resolverNifEmpresa(empresa, fiscal),
      razonSocial: (fiscal['razon_social'] ?? empresa['razon_social'] ?? empresa['nombre'] ?? '').toString(),
      domicilioFiscal: (fiscal['domicilio_fiscal'] ?? empresa['domicilio_fiscal'] ?? empresa['direccion'] ?? '').toString(),
      codigoPostal: (fiscal['codigo_postal'] ?? empresa['codigo_postal'] ?? '').toString(),
      municipio: (fiscal['municipio'] ?? empresa['municipio'] ?? '').toString(),
      provincia: (fiscal['provincia'] ?? empresa['provincia'] ?? '').toString(),
      regimenIVA: (fiscal['regimen_iva'] ?? 'general').toString(),
      epigrafIAE: (fiscal['epigraf_iae'] ?? empresa['epigraf_iae'] ?? '').toString(),
      estaEnSII: fiscal['esta_en_sii'] == true,
      criterioIva: CriterioIVA.values.firstWhere(
        (e) => e.name == (fiscal['criterio_iva'] ?? 'devengo'),
        orElse: () => CriterioIVA.devengo,
      ),
      ibanEmpresa: (empresa['iban_empresa'] ?? fiscal['iban_empresa'] ?? '').toString(),
      bicEmpresa: (empresa['bic_empresa'] ?? fiscal['bic_empresa'] ?? '').toString(),
      formaJuridica: FormaJuridicaExt.fromString(
        (fiscal['forma_juridica'] ?? empresa['forma_juridica'])?.toString(),
      ),
      serieFactura: _serieValida(empresa['serie_factura'] ?? 'F', 'F'),
      serieRectificativa: _serieValida(empresa['serie_rectificativa'] ?? 'R', 'R'),
      serieProforma: _serieValida(empresa['serie_proforma'] ?? 'P', 'P'),
    );
  }

  Map<String, dynamic> toEmpresaDoc() => {
        'nif': nifNormalizado,
        'razon_social': razonSocial.trim(),
        'domicilio_fiscal': domicilioFiscal.trim(),
        'codigo_postal': codigoPostal.trim(),
        'municipio': municipio.trim(),
        'provincia': provincia.trim(),
        'epigraf_iae': epigrafIAE.trim(),
        if (ibanEmpresa.trim().isNotEmpty) 'iban_empresa': ibanEmpresa.trim(),
        if (bicEmpresa.trim().isNotEmpty) 'bic_empresa': bicEmpresa.trim(),
        'forma_juridica': formaJuridica.valorFirestore,
        'serie_factura': serieFactura.trim().toUpperCase(),
        'serie_rectificativa': serieRectificativa.trim().toUpperCase(),
        'serie_proforma': serieProforma.trim().toUpperCase(),
      };

  Map<String, dynamic> toFiscalDoc() => {
        'nif': nifNormalizado,
        'razon_social': razonSocial.trim(),
        'domicilio_fiscal': domicilioFiscal.trim(),
        'regimen_iva': regimenIVA.trim(),
        'epigraf_iae': epigrafIAE.trim(),
        'esta_en_sii': estaEnSII,
        'criterio_iva': criterioIva.name,
        'forma_juridica': formaJuridica.valorFirestore,
      };

  EmpresaConfig copyWith({
    String? nif,
    String? razonSocial,
    String? domicilioFiscal,
    String? codigoPostal,
    String? municipio,
    String? provincia,
    String? regimenIVA,
    String? epigrafIAE,
    bool? estaEnSII,
    CriterioIVA? criterioIva,
    String? ibanEmpresa,
    String? bicEmpresa,
    FormaJuridica? formaJuridica,
    String? serieFactura,
    String? serieRectificativa,
    String? serieProforma,
  }) {
    return EmpresaConfig(
      nif: nif ?? this.nif,
      razonSocial: razonSocial ?? this.razonSocial,
      domicilioFiscal: domicilioFiscal ?? this.domicilioFiscal,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      municipio: municipio ?? this.municipio,
      provincia: provincia ?? this.provincia,
      regimenIVA: regimenIVA ?? this.regimenIVA,
      epigrafIAE: epigrafIAE ?? this.epigrafIAE,
      estaEnSII: estaEnSII ?? this.estaEnSII,
      criterioIva: criterioIva ?? this.criterioIva,
      ibanEmpresa: ibanEmpresa ?? this.ibanEmpresa,
      bicEmpresa: bicEmpresa ?? this.bicEmpresa,
      formaJuridica: formaJuridica ?? this.formaJuridica,
      serieFactura: serieFactura ?? this.serieFactura,
      serieRectificativa: serieRectificativa ?? this.serieRectificativa,
      serieProforma: serieProforma ?? this.serieProforma,
    );
  }

  String get nifNormalizado => ValidadorNifCif.limpiar(nif);
  bool get usaNifPlaceholderLegacy => _esNifPlaceholderLegacy(nif);
  bool get tieneNifConfigurado => nif.trim().isNotEmpty && !usaNifPlaceholderLegacy;
  bool get tieneNifValido => tieneNifConfigurado && ValidadorNifCif.validar(nif).valido;
  String? get errorNif {
    if (nif.trim().isEmpty) return 'NIF requerido';
    if (usaNifPlaceholderLegacy) {
      return 'Configura el NIF real de la empresa';
    }
    final validacion = ValidadorNifCif.validar(nif);
    return validacion.valido ? null : validacion.razon;
  }
  bool get esRECC => regimenIVA.toLowerCase() == 'recc';

  /// Helpers según forma jurídica
  bool get esSociedad => formaJuridica.esSociedad;
  bool get tributaIRPF => formaJuridica.tributaIRPF;

  List<String> validar() {
    final errores = <String>[];
    final nifCheck = ValidadorNifCif.validar(nif);
    if (nif.trim().isEmpty) {
      errores.add('El NIF es obligatorio');
    } else if (usaNifPlaceholderLegacy) {
      errores.add('Debes configurar el NIF real de la empresa');
    } else if (!nifCheck.valido) {
      errores.add(nifCheck.razon);
    }
    if (razonSocial.trim().isEmpty) errores.add('La razón social es obligatoria');
    if (domicilioFiscal.trim().isEmpty) errores.add('El domicilio fiscal es obligatorio');
    if (codigoPostal.trim().isEmpty) errores.add('El código postal es obligatorio');
    if (municipio.trim().isEmpty) errores.add('El municipio es obligatorio');
    if (provincia.trim().isEmpty) errores.add('La provincia es obligatoria');
    return errores;
  }
}


// EmpresaConfig — fin del archivo

/// Valida y normaliza el prefijo de una serie (máx. 5 caracteres alfanuméricos).
String _serieValida(dynamic valor, String porDefecto) {
  final s = (valor ?? '').toString().trim().toUpperCase();
  if (s.isEmpty || s.length > 5) return porDefecto;
  final soloAlfa = RegExp(r'^[A-Z0-9\-]+$');
  return soloAlfa.hasMatch(s) ? s : porDefecto;
}


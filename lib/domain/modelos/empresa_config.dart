import 'package:flutter/foundation.dart';
import '../../core/utils/validador_nif_cif.dart';
import 'empresa.dart';

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
      };

  Map<String, dynamic> toFiscalDoc() => {
        'nif': nifNormalizado,
        'razon_social': razonSocial.trim(),
        'domicilio_fiscal': domicilioFiscal.trim(),
        'regimen_iva': regimenIVA.trim(),
        'epigraf_iae': epigrafIAE.trim(),
        'esta_en_sii': estaEnSII,
        'criterio_iva': criterioIva.name,
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
      criterioIva: criterioIva ?? this.criterioIva,
      ibanEmpresa: ibanEmpresa ?? this.ibanEmpresa,
      bicEmpresa: bicEmpresa ?? this.bicEmpresa,
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

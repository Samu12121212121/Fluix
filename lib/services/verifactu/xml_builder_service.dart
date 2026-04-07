import '../../domain/modelos/factura.dart';
import 'modelos_verifactu.dart';
import 'xml_payload_verifactu_builder.dart';

/// Construye el payload XML según Orden HAC/1177/2024.
///
/// Envuelve [XmlPayloadVerifactuBuilder] añadiendo soporte para
/// [RegistroFacturacionAlta] del sistema canónico.
class XmlBuilderService {
  /// Genera XML de RegistroAlta a partir del modelo canónico.
  String buildRegistroAlta({
    required RegistroFacturacionAlta registro,
    required Factura factura,
    required String nombreEmisor,
    required String nombreSoftware,
    required String idSoftware,
    required String versionSoftware,
    required String nifFabricante,
  }) {
    final fechaExpedicion =
        '${registro.fechaExpedicion.year}-'
        '${registro.fechaExpedicion.month.toString().padLeft(2, '0')}-'
        '${registro.fechaExpedicion.day.toString().padLeft(2, '0')}';

    final fechaHoraRegistro =
        registro.fechaHoraGeneracion.toUtc().toIso8601String();

    return XmlPayloadVerifactuBuilder.construirSuministroSingleAltaLegacy(
      factura: factura,
      nifEmisor: registro.nifEmisor,
      nombreEmisor: nombreEmisor,
      tipoFactura: registro.tipoFactura.codigo,
      claveRegimen: registro.claveRegimen.codigo,
      hashRegistro: registro.hash,
      hashAnterior: registro.registroAnterior.esPrimerRegistro
          ? ''
          : registro.registroAnterior.hash64Caracteres,
      fechaExpedicion: fechaExpedicion,
      fechaHoraRegistro: fechaHoraRegistro,
      nombreSoftware: nombreSoftware,
      idSoftware: idSoftware,
      versionSoftware: versionSoftware,
      nifFabricante: nifFabricante,
      esSoloVerifactu: registro.esVerifactu,
    );
  }
}


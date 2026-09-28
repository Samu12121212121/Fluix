import '../../domain/modelos/factura.dart';

class XmlPayloadVerifactuBuilder {
  /// Genera el payload XML de SuministroLRFacturasEmitidas (RegistroAlta).
  ///
  /// Las fechas deben estar en formato dd-MM-yyyy (HAC/1177/2024).
  /// El encadenamiento usa los datos de la factura ANTERIOR (no la actual).
  static String construirSuministroSingleAltaLegacy({
    required Factura factura,
    required String nifEmisor,
    required String nombreEmisor,
    required String tipoFactura,
    required String claveRegimen,
    required String hashRegistro,
    required String hashAnterior,
    required String fechaExpedicion,           // fecha de la factura ACTUAL (dd-MM-yyyy)
    required String fechaHoraRegistro,
    required String nombreSoftware,
    required String idSoftware,
    required String versionSoftware,
    required String nifFabricante,
    required bool esSoloVerifactu,
    String numeroFacturaAnterior = '',         // número de la factura ANTERIOR
    String fechaExpedicionAnterior = '',       // fecha de la factura ANTERIOR (dd-MM-yyyy)
  }) {
    final lineasXml = factura.lineas.map((l) => '''
          <vf:DetalleDesglose>
            <vf:Impuesto>01</vf:Impuesto>
            <vf:ClaveRegimen>$claveRegimen</vf:ClaveRegimen>
            <vf:CalificacionOperacion>S1</vf:CalificacionOperacion>
            <vf:TipoImpositivo>${l.porcentajeIva.toStringAsFixed(2)}</vf:TipoImpositivo>
            <vf:BaseImponible>${l.subtotalSinIva.toStringAsFixed(2)}</vf:BaseImponible>
            <vf:CuotaRepercutida>${l.importeIva.toStringAsFixed(2)}</vf:CuotaRepercutida>
          </vf:DetalleDesglose>''').join('\n');

    final contrapartidaNif = (factura.datosFiscales?.nif ?? '').trim();
    final esPrimer = hashAnterior.trim().isEmpty;

    // Bloque de encadenamiento con la factura ANTERIOR (requerido si no es el primero)
    final encadenamiento = esPrimer
        ? ''
        : '''      <vf:EncadenamientoFacturaAnterior>
        <vf:IDEmisorFacturaAnterior>${_xmlEscape(nifEmisor)}</vf:IDEmisorFacturaAnterior>
        <vf:NumSerieFacturaAnterior>${_xmlEscape(numeroFacturaAnterior.isNotEmpty ? numeroFacturaAnterior : factura.numeroFactura)}</vf:NumSerieFacturaAnterior>
        <vf:FechaExpedicionFacturaAnterior>${_xmlEscape(fechaExpedicionAnterior.isNotEmpty ? fechaExpedicionAnterior : fechaExpedicion)}</vf:FechaExpedicionFacturaAnterior>
        <vf:HuellaFacturaAnterior>${_xmlEscape(hashAnterior)}</vf:HuellaFacturaAnterior>
      </vf:EncadenamientoFacturaAnterior>''';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<vf:SuministroLRFacturasEmitidas xmlns:vf="https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/SuministroInformacion.xsd">
  <vf:Cabecera>
    <vf:IDVersionSif>1.0</vf:IDVersionSif>
    <vf:Titular>
      <vf:NombreRazon>${_xmlEscape(nombreEmisor)}</vf:NombreRazon>
      <vf:NIF>${_xmlEscape(nifEmisor)}</vf:NIF>
    </vf:Titular>
  </vf:Cabecera>
  <vf:RegistroFactura>
    <vf:RegistroAlta>
      <vf:IDVersion>1.0</vf:IDVersion>
      <vf:IDFactura>
        <vf:IDEmisorFactura>${_xmlEscape(nifEmisor)}</vf:IDEmisorFactura>
        <vf:NumSerieFactura>${_xmlEscape(factura.numeroFactura)}</vf:NumSerieFactura>
        <vf:FechaExpedicionFacturaEmisor>${_xmlEscape(fechaExpedicion)}</vf:FechaExpedicionFacturaEmisor>
      </vf:IDFactura>
      <vf:NombreRazonEmisor>${_xmlEscape(nombreEmisor)}</vf:NombreRazonEmisor>
      <vf:TipoFactura>${_xmlEscape(tipoFactura)}</vf:TipoFactura>
      <vf:DescripcionOperacion>${_xmlEscape('Factura ${factura.numeroFactura}')}</vf:DescripcionOperacion>
      ${contrapartidaNif.isNotEmpty ? '<vf:Destinatarios><vf:IDDestinatario><vf:NombreRazon>${_xmlEscape(factura.clienteNombre)}</vf:NombreRazon><vf:NIF>${_xmlEscape(contrapartidaNif)}</vf:NIF></vf:IDDestinatario></vf:Destinatarios>' : ''}
      <vf:Desglose>
$lineasXml
      </vf:Desglose>
      <vf:CuotaTotal>${factura.totalIva.toStringAsFixed(2)}</vf:CuotaTotal>
      <vf:ImporteTotal>${factura.total.toStringAsFixed(2)}</vf:ImporteTotal>
      <vf:PrimerRegistro>${esPrimer ? 'S' : 'N'}</vf:PrimerRegistro>
$encadenamiento
      <vf:SistemaInformatico>
        <vf:NombreSistemaInformatico>${_xmlEscape(nombreSoftware)}</vf:NombreSistemaInformatico>
        <vf:IdSistemaInformatico>${_xmlEscape(idSoftware)}</vf:IdSistemaInformatico>
        <vf:Version>${_xmlEscape(versionSoftware)}</vf:Version>
        <vf:NumeroInstalacion>DEFAULT</vf:NumeroInstalacion>
        <vf:TipoUsoPosibleSoloVerifactu>${esSoloVerifactu ? 'S' : 'N'}</vf:TipoUsoPosibleSoloVerifactu>
        <vf:TipoUsoPosibleMultiOT>N</vf:TipoUsoPosibleMultiOT>
        <vf:IndicadorMultiplesOT>N</vf:IndicadorMultiplesOT>
        <vf:NIF>${_xmlEscape(nifFabricante)}</vf:NIF>
        <vf:NombreRazon>${_xmlEscape(nombreSoftware)}</vf:NombreRazon>
      </vf:SistemaInformatico>
      <vf:FechaHoraHusoGenRegistro>${_xmlEscape(fechaHoraRegistro)}</vf:FechaHoraHusoGenRegistro>
      <vf:TipoHuella>01</vf:TipoHuella>
      <vf:Huella>${_xmlEscape(hashRegistro)}</vf:Huella>
    </vf:RegistroAlta>
  </vf:RegistroFactura>
</vf:SuministroLRFacturasEmitidas>''';
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}



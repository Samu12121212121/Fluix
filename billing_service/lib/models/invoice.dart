// lib/models/invoice.dart

enum InvoiceType { complete, simplified, rectificativa }

class Invoice {
  final String       id;
  final String?      tenantId;            // Multi-tenant: empresa propietaria
  final String       serie;
  final String       numero;
  final InvoiceType  tipo;
  final String       tipoVerifactu;       // 'F1' | 'F2' | 'R4'
  final String?      tipoRectificativa;   // 'I' = por diferencias
  final String?      facturaRectificadaSerie;
  final String?      facturaRectificadaNumero;
  final DateTime?    facturaRectificadaFecha;

  // Emisor
  final String emisorNif;
  final String emisorNombre;

  // Destinatario
  final String?  destinatarioNif;
  final String?  destinatarioNombre;
  final String?  destinatarioDireccion;
  final String?  destinatarioEmail;

  // Fechas
  final DateTime fechaExpedicion;
  final DateTime fechaOperacion;

  // Importes
  final double baseImponible;
  final double tipoIva;         // porcentaje, p.ej. 21.0
  final double cuotaIva;
  final double retencionIrpf;
  final double recargo;
  final double importeTotal;

  // Metadatos
  final String  descripcion;
  final String  claveRegimen;          // '01' general
  final String  calificacionOperacion; // 'S1' sujeta y no exenta
  final String? referenciaExterna;
  final String  proveedorPago;

  // Verifactu
  final String? registroVerifactu;
  final String? hashVerifactu;

  const Invoice({
    this.id                     = '',
    this.tenantId,
    required this.serie,
    required this.numero,
    required this.tipo,
    required this.tipoVerifactu,
    this.tipoRectificativa,
    this.facturaRectificadaSerie,
    this.facturaRectificadaNumero,
    this.facturaRectificadaFecha,
    required this.emisorNif,
    required this.emisorNombre,
    this.destinatarioNif,
    this.destinatarioNombre,
    this.destinatarioDireccion,
    this.destinatarioEmail,
    required this.fechaExpedicion,
    required this.fechaOperacion,
    required this.baseImponible,
    required this.tipoIva,
    required this.cuotaIva,
    required this.retencionIrpf,
    required this.recargo,
    required this.importeTotal,
    required this.descripcion,
    required this.claveRegimen,
    required this.calificacionOperacion,
    this.referenciaExterna,
    required this.proveedorPago,
    this.registroVerifactu,
    this.hashVerifactu,
  });

  Invoice copyWith({
    String? id,
    String? tenantId,
    String? registroVerifactu,
    String? hashVerifactu,
  }) => Invoice(
    id:                       id          ?? this.id,
    tenantId:                 tenantId    ?? this.tenantId,
    serie:                    serie,
    numero:                   numero,
    tipo:                     tipo,
    tipoVerifactu:            tipoVerifactu,
    tipoRectificativa:        tipoRectificativa,
    facturaRectificadaSerie:  facturaRectificadaSerie,
    facturaRectificadaNumero: facturaRectificadaNumero,
    facturaRectificadaFecha:  facturaRectificadaFecha,
    emisorNif:                emisorNif,
    emisorNombre:             emisorNombre,
    destinatarioNif:          destinatarioNif,
    destinatarioNombre:       destinatarioNombre,
    destinatarioDireccion:    destinatarioDireccion,
    destinatarioEmail:        destinatarioEmail,
    fechaExpedicion:          fechaExpedicion,
    fechaOperacion:           fechaOperacion,
    baseImponible:            baseImponible,
    tipoIva:                  tipoIva,
    cuotaIva:                 cuotaIva,
    retencionIrpf:            retencionIrpf,
    recargo:                  recargo,
    importeTotal:             importeTotal,
    descripcion:              descripcion,
    claveRegimen:             claveRegimen,
    calificacionOperacion:    calificacionOperacion,
    referenciaExterna:        referenciaExterna,
    proveedorPago:            proveedorPago,
    registroVerifactu:        registroVerifactu ?? this.registroVerifactu,
    hashVerifactu:            hashVerifactu     ?? this.hashVerifactu,
  );

  Map<String, dynamic> toJson() => {
    'id':                          id,
    'tenant_id':                   tenantId,
    'serie':                       serie,
    'numero':                      numero,
    'tipo':                        tipo.name,
    'tipo_verifactu':              tipoVerifactu,
    'tipo_rectificativa':          tipoRectificativa,
    'factura_rectificada_serie':   facturaRectificadaSerie,
    'factura_rectificada_numero':  facturaRectificadaNumero,
    'factura_rectificada_fecha':   facturaRectificadaFecha?.toIso8601String(),
    'emisor_nif':                  emisorNif,
    'emisor_nombre':               emisorNombre,
    'destinatario_nif':            destinatarioNif,
    'destinatario_nombre':         destinatarioNombre,
    'destinatario_direccion':      destinatarioDireccion,
    'destinatario_email':          destinatarioEmail,
    'fecha_expedicion':            fechaExpedicion.toIso8601String(),
    'fecha_operacion':             fechaOperacion.toIso8601String(),
    'base_imponible':              baseImponible,
    'tipo_iva':                    tipoIva,
    'cuota_iva':                   cuotaIva,
    'retencion_irpf':              retencionIrpf,
    'recargo':                     recargo,
    'importe_total':               importeTotal,
    'descripcion':                 descripcion,
    'clave_regimen':               claveRegimen,
    'calificacion_operacion':      calificacionOperacion,
    'referencia_externa':          referenciaExterna,
    'proveedor_pago':              proveedorPago,
    'registro_verifactu':          registroVerifactu,
    'hash_verifactu':              hashVerifactu,
  };
}

// ── Series (resultado de obtener el siguiente número) ──────────────────────

class InvoiceSeries {
  final String serie;
  final String numero;
  final String emisorNif;
  final String emisorNombre;

  const InvoiceSeries({
    required this.serie,
    required this.numero,
    required this.emisorNif,
    required this.emisorNombre,
  });
}






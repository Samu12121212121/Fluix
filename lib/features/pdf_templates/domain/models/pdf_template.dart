import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoDocumentoPdf {
  factura,
  facturaRectificativa,
  proforma,
  presupuesto,
  albaran,
  fichajes,
  horasEmpleado,
  informeInterno,
}

extension TipoDocumentoPdfExt on TipoDocumentoPdf {
  String get label => switch (this) {
        TipoDocumentoPdf.factura => 'Factura',
        TipoDocumentoPdf.facturaRectificativa => 'Factura Rectificativa',
        TipoDocumentoPdf.proforma => 'Factura Proforma',
        TipoDocumentoPdf.presupuesto => 'Presupuesto',
        TipoDocumentoPdf.albaran => 'Albarán',
        TipoDocumentoPdf.fichajes => 'Informe de Fichajes',
        TipoDocumentoPdf.horasEmpleado => 'Reporte de Horas',
        TipoDocumentoPdf.informeInterno => 'Informe Interno',
      };

  String get icon => switch (this) {
        TipoDocumentoPdf.factura => '🧾',
        TipoDocumentoPdf.facturaRectificativa => '🔄',
        TipoDocumentoPdf.proforma => '📋',
        TipoDocumentoPdf.presupuesto => '💼',
        TipoDocumentoPdf.albaran => '📦',
        TipoDocumentoPdf.fichajes => '⏱️',
        TipoDocumentoPdf.horasEmpleado => '📊',
        TipoDocumentoPdf.informeInterno => '📄',
      };

  String get id => name;

  static TipoDocumentoPdf fromId(String id) =>
      TipoDocumentoPdf.values.firstWhere(
        (e) => e.name == id,
        orElse: () => TipoDocumentoPdf.factura,
      );
}

class PdfTemplate {
  final String id;
  final String empresaId;
  final String nombre;
  final String descripcion;
  final TipoDocumentoPdf tipo;
  final bool esDefault;
  final bool activa;
  final DateTime fechaCreacion;
  final DateTime fechaModificacion;

  // Estilos globales
  final String colorPrimario;
  final String colorSecundario;
  final String colorTexto;
  final String colorFondo;
  final double margenHorizontal;
  final double margenVertical;

  // Lista de bloques ordenados
  final List<Map<String, dynamic>> bloques;

  const PdfTemplate({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.descripcion,
    required this.tipo,
    this.esDefault = false,
    this.activa = true,
    required this.fechaCreacion,
    required this.fechaModificacion,
    this.colorPrimario = '#1565C0',
    this.colorSecundario = '#0D47A1',
    this.colorTexto = '#000000',
    this.colorFondo = '#FFFFFF',
    this.margenHorizontal = 36,
    this.margenVertical = 36,
    required this.bloques,
  });

  factory PdfTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PdfTemplate(
      id: doc.id,
      empresaId: data['empresa_id'] ?? '',
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      tipo: TipoDocumentoPdfExt.fromId(data['tipo'] ?? 'factura'),
      esDefault: data['es_default'] ?? false,
      activa: data['activa'] ?? true,
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaModificacion: (data['fecha_modificacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      colorPrimario: data['color_primario'] ?? '#1565C0',
      colorSecundario: data['color_secundario'] ?? '#0D47A1',
      colorTexto: data['color_texto'] ?? '#000000',
      colorFondo: data['color_fondo'] ?? '#FFFFFF',
      margenHorizontal: (data['margen_horizontal'] as num?)?.toDouble() ?? 36,
      margenVertical: (data['margen_vertical'] as num?)?.toDouble() ?? 36,
      bloques: List<Map<String, dynamic>>.from(
        (data['bloques'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
            [],
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'empresa_id': empresaId,
        'nombre': nombre,
        'descripcion': descripcion,
        'tipo': tipo.id,
        'es_default': esDefault,
        'activa': activa,
        'fecha_creacion': Timestamp.fromDate(fechaCreacion),
        'fecha_modificacion': Timestamp.fromDate(fechaModificacion),
        'color_primario': colorPrimario,
        'color_secundario': colorSecundario,
        'color_texto': colorTexto,
        'color_fondo': colorFondo,
        'margen_horizontal': margenHorizontal,
        'margen_vertical': margenVertical,
        'bloques': bloques,
      };

  PdfTemplate copyWith({
    String? id,
    String? empresaId,
    String? nombre,
    String? descripcion,
    TipoDocumentoPdf? tipo,
    bool? esDefault,
    bool? activa,
    DateTime? fechaCreacion,
    DateTime? fechaModificacion,
    String? colorPrimario,
    String? colorSecundario,
    String? colorTexto,
    String? colorFondo,
    double? margenHorizontal,
    double? margenVertical,
    List<Map<String, dynamic>>? bloques,
  }) {
    return PdfTemplate(
      id: id ?? this.id,
      empresaId: empresaId ?? this.empresaId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      esDefault: esDefault ?? this.esDefault,
      activa: activa ?? this.activa,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      colorPrimario: colorPrimario ?? this.colorPrimario,
      colorSecundario: colorSecundario ?? this.colorSecundario,
      colorTexto: colorTexto ?? this.colorTexto,
      colorFondo: colorFondo ?? this.colorFondo,
      margenHorizontal: margenHorizontal ?? this.margenHorizontal,
      margenVertical: margenVertical ?? this.margenVertical,
      bloques: bloques ?? this.bloques,
    );
  }

  /// Plantilla por defecto para facturas
  static PdfTemplate defaultFactura(String empresaId) => PdfTemplate(
        id: '',
        empresaId: empresaId,
        nombre: 'Factura Estándar',
        descripcion: 'Plantilla por defecto para facturas',
        tipo: TipoDocumentoPdf.factura,
        esDefault: true,
        activa: true,
        fechaCreacion: DateTime.now(),
        fechaModificacion: DateTime.now(),
        bloques: _bloquesDefaultFactura,
      );

  static List<Map<String, dynamic>> get _bloquesDefaultFactura => [
        {
          'id': 'header_1',
          'tipo': 'header',
          'orden': 0,
          'activo': true,
          'props': {
            'mostrar_logo': true,
            'mostrar_datos_empresa': true,
            'color_fondo': '#1565C0',
            'color_texto': '#FFFFFF',
            'padding': 18,
            'border_radius': 12,
          },
        },
        {
          'id': 'info_factura_1',
          'tipo': 'info_documento',
          'orden': 1,
          'activo': true,
          'props': {
            'mostrar_numero': true,
            'mostrar_fecha_emision': true,
            'mostrar_fecha_vencimiento': true,
            'mostrar_estado': true,
          },
        },
        {
          'id': 'cliente_1',
          'tipo': 'cliente',
          'orden': 2,
          'activo': true,
          'props': {
            'titulo': 'FACTURAR A:',
            'mostrar_nif': true,
            'mostrar_direccion': true,
            'mostrar_email': true,
            'color_fondo': '#F5F9FF',
            'border_radius': 8,
          },
        },
        {
          'id': 'tabla_1',
          'tipo': 'tabla_lineas',
          'orden': 3,
          'activo': true,
          'props': {
            'mostrar_cantidad': true,
            'mostrar_precio_unitario': true,
            'mostrar_descuento': true,
            'mostrar_iva': true,
            'mostrar_base_imponible': true,
            'color_cabecera': '#0D47A1',
            'color_fila_par': '#FFFFFF',
            'color_fila_impar': '#FAFBFC',
          },
        },
        {
          'id': 'totales_1',
          'tipo': 'totales',
          'orden': 4,
          'activo': true,
          'props': {
            'mostrar_base': true,
            'mostrar_descuento': true,
            'mostrar_iva': true,
            'mostrar_irpf': true,
            'mostrar_total': true,
            'alineacion': 'derecha',
            'ancho': 240,
          },
        },
        {
          'id': 'pago_1',
          'tipo': 'forma_pago',
          'orden': 5,
          'activo': true,
          'props': {
            'mostrar_metodo': true,
            'mostrar_iban': true,
            'color_fondo': '#F5F9FF',
          },
        },
        {
          'id': 'notas_1',
          'tipo': 'notas',
          'orden': 6,
          'activo': true,
          'props': {
            'placeholder': 'Notas adicionales...',
            'tamano_fuente': 9,
            'color_texto': '#757575',
          },
        },
        {
          'id': 'qr_1',
          'tipo': 'qr_verifactu',
          'orden': 7,
          'activo': true,
          'props': {
            'tamano': 57,
            'mostrar_etiqueta': true,
          },
        },
      ];

  /// Plantilla por defecto para fichajes
  static PdfTemplate defaultFichajes(String empresaId) => PdfTemplate(
        id: '',
        empresaId: empresaId,
        nombre: 'Informe Fichajes Estándar',
        descripcion: 'Plantilla por defecto para informes de fichajes',
        tipo: TipoDocumentoPdf.fichajes,
        esDefault: true,
        activa: true,
        fechaCreacion: DateTime.now(),
        fechaModificacion: DateTime.now(),
        bloques: _bloquesDefaultFichajes,
      );

  static List<Map<String, dynamic>> get _bloquesDefaultFichajes => [
        {
          'id': 'header_1',
          'tipo': 'header',
          'orden': 0,
          'activo': true,
          'props': {
            'mostrar_logo': true,
            'mostrar_datos_empresa': true,
            'color_fondo': '#1565C0',
            'color_texto': '#FFFFFF',
            'padding': 18,
            'border_radius': 12,
          },
        },
        {
          'id': 'empleado_1',
          'tipo': 'info_empleado',
          'orden': 1,
          'activo': true,
          'props': {
            'mostrar_nombre': true,
            'mostrar_puesto': true,
            'mostrar_periodo': true,
          },
        },
        {
          'id': 'tabla_fichajes_1',
          'tipo': 'tabla_fichajes',
          'orden': 2,
          'activo': true,
          'props': {
            'mostrar_fecha': true,
            'mostrar_entrada': true,
            'mostrar_salida': true,
            'mostrar_duracion': true,
            'mostrar_tipo': true,
            'color_cabecera': '#0D47A1',
          },
        },
        {
          'id': 'resumen_1',
          'tipo': 'resumen_horas',
          'orden': 3,
          'activo': true,
          'props': {
            'mostrar_total_horas': true,
            'mostrar_horas_extra': true,
            'mostrar_dias_trabajados': true,
          },
        },
      ];

  /// Devuelve la plantilla por defecto para cualquier tipo
  static PdfTemplate defaultParaTipo(String empresaId, TipoDocumentoPdf tipo) {
    switch (tipo) {
      case TipoDocumentoPdf.factura:            return defaultFactura(empresaId);
      case TipoDocumentoPdf.facturaRectificativa: return defaultFacturaRectificativa(empresaId);
      case TipoDocumentoPdf.proforma:           return defaultProforma(empresaId);
      case TipoDocumentoPdf.presupuesto:        return defaultPresupuesto(empresaId);
      case TipoDocumentoPdf.albaran:            return defaultAlbaran(empresaId);
      case TipoDocumentoPdf.fichajes:           return defaultFichajes(empresaId);
      case TipoDocumentoPdf.horasEmpleado:      return defaultHorasEmpleado(empresaId);
      case TipoDocumentoPdf.informeInterno:     return defaultInformeInterno(empresaId);
    }
  }

  /// Factura Rectificativa
  static PdfTemplate defaultFacturaRectificativa(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Factura Rectificativa Estándar',
        descripcion: 'Plantilla por defecto para facturas rectificativas',
        tipo: TipoDocumentoPdf.facturaRectificativa,
        esDefault: true, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#B71C1C', colorSecundario: '#7F0000',
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#B71C1C','color_texto':'#FFFFFF','padding':18,'border_radius':12}},
          {'id':'rectifica_1','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'FACTURA RECTIFICATIVA\nRectifica la factura: FAC-2026-XXX de fecha dd/mm/aaaa\nMotivo: Error en datos / Devolución / Descuento posterior','tamano_fuente':10,'color_texto':'#B71C1C','negrita':true}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':false}},
          {'id':'cliente_1','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'FACTURAR A:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#FFF5F5','border_radius':8}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#7F0000','color_fila_par':'#FFFFFF','color_fila_impar':'#FFF5F5'}},
          {'id':'totales_1','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true}},
          {'id':'sep_1','tipo':'separador','orden':6,'activo':true,'props':{'color':'#FFCDD2','grosor':1,'margen_vertical':8}},
          {'id':'notas_1','tipo':'notas','orden':7,'activo':true,'props':{'placeholder':'Motivo de rectificación detallado...','tamano_fuente':9,'color_texto':'#757575'}},
          {'id':'qr_1','tipo':'qr_verifactu','orden':8,'activo':true,'props':{'tamano':57,'mostrar_etiqueta':true}},
        ]);

  /// Factura Proforma
  static PdfTemplate defaultProforma(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Proforma Estándar',
        descripcion: 'Plantilla por defecto para facturas proforma',
        tipo: TipoDocumentoPdf.proforma,
        esDefault: true, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#E65100', colorSecundario: '#BF360C',
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#E65100','color_texto':'#FFFFFF','padding':18,'border_radius':12}},
          {'id':'aviso_1','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'FACTURA PROFORMA — Este documento no tiene validez fiscal.\nEs una previsualización del importe a facturar.','tamano_fuente':9,'color_texto':'#E65100','negrita':false}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
          {'id':'cliente_1','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'PARA:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#FFF3E0','border_radius':8}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#BF360C','color_fila_par':'#FFFFFF','color_fila_impar':'#FFF8F5'}},
          {'id':'totales_1','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true}},
          {'id':'forma_1','tipo':'forma_pago','orden':6,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#FFF3E0'}},
          {'id':'footer_1','tipo':'footer','orden':7,'activo':true,'props':{'contenido':'PROFORMA — Documento sin efecto fiscal ni contable','tamano_fuente':7,'color_texto':'#BDBDBD'}},
        ]);

  /// Albarán
  static PdfTemplate defaultAlbaran(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Albarán Estándar',
        descripcion: 'Plantilla por defecto para albaranes',
        tipo: TipoDocumentoPdf.albaran,
        esDefault: true, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#00695C', colorSecundario: '#004D40',
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#00695C','color_texto':'#FFFFFF','padding':18,'border_radius':12}},
          {'id':'titulo_1','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'ALBARÁN / NOTA DE ENTREGA','tamano_fuente':13,'color_texto':'#00695C','negrita':true}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':false}},
          {'id':'cliente_1','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'ENTREGAR A:','mostrar_nif':false,'mostrar_direccion':true,'mostrar_email':false,'color_fondo':'#E0F2F1','border_radius':8}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':false,'mostrar_iva':false,'color_cabecera':'#004D40','color_fila_par':'#FFFFFF','color_fila_impar':'#F1FFFE'}},
          {'id':'sep_1','tipo':'separador','orden':5,'activo':true,'props':{'color':'#B2DFDB','grosor':1,'margen_vertical':12}},
          {'id':'firmas_1','tipo':'texto_libre','orden':6,'activo':true,'props':{'contenido':'Entregado conforme:\n\nFirma emisor: ________________      Firma receptor: ________________\n\nFecha de entrega: _______________','tamano_fuente':9,'color_texto':'#424242','negrita':false}},
          {'id':'footer_1','tipo':'footer','orden':7,'activo':true,'props':{'contenido':'Este documento no tiene validez fiscal','tamano_fuente':7,'color_texto':'#BDBDBD'}},
        ]);

  /// Reporte de horas empleado
  static PdfTemplate defaultHorasEmpleado(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Reporte de Horas Estándar',
        descripcion: 'Plantilla por defecto para reportes de horas',
        tipo: TipoDocumentoPdf.horasEmpleado,
        esDefault: true, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#1565C0', colorSecundario: '#0D47A1',
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#1565C0','color_texto':'#FFFFFF','padding':18,'border_radius':12}},
          {'id':'titulo_1','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'REPORTE DE HORAS','tamano_fuente':13,'color_texto':'#1565C0','negrita':true}},
          {'id':'empleado_1','tipo':'info_empleado','orden':2,'activo':true,'props':{'mostrar_nombre':true,'mostrar_puesto':true,'mostrar_periodo':true}},
          {'id':'tabla_1','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_fecha':true,'mostrar_entrada':true,'mostrar_salida':true,'color_cabecera':'#0D47A1'}},
          {'id':'resumen_1','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total_horas':true,'mostrar_horas_extra':true,'mostrar_dias_trabajados':true}},
          {'id':'sep_1','tipo':'separador','orden':5,'activo':true,'props':{'color':'#BBDEFB','grosor':1,'margen_vertical':12}},
          {'id':'firmas_1','tipo':'texto_libre','orden':6,'activo':true,'props':{'contenido':'Aprobado por: ________________      Empleado: ________________\n\nFecha: _______________','tamano_fuente':9,'color_texto':'#424242','negrita':false}},
        ]);

  /// Informe interno
  static PdfTemplate defaultInformeInterno(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Informe Interno Estándar',
        descripcion: 'Plantilla por defecto para informes internos',
        tipo: TipoDocumentoPdf.informeInterno,
        esDefault: true, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#424242', colorSecundario: '#212121',
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#424242','color_texto':'#FFFFFF','padding':18,'border_radius':12}},
          {'id':'titulo_1','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'INFORME INTERNO\nCONFIDENCIAL — Documento de uso interno','tamano_fuente':13,'color_texto':'#212121','negrita':true}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':false}},
          {'id':'sep_1','tipo':'separador','orden':3,'activo':true,'props':{'color':'#BDBDBD','grosor':1,'margen_vertical':8}},
          {'id':'cuerpo_1','tipo':'texto_libre','orden':4,'activo':true,'props':{'contenido':'Resumen ejecutivo:\n\nEscribe aquí el contenido del informe...','tamano_fuente':10,'color_texto':'#212121','negrita':false}},
          {'id':'notas_1','tipo':'notas','orden':5,'activo':true,'props':{'placeholder':'Conclusiones y observaciones...','tamano_fuente':9,'color_texto':'#757575'}},
          {'id':'sep_2','tipo':'separador','orden':6,'activo':true,'props':{'color':'#BDBDBD','grosor':1,'margen_vertical':12}},
          {'id':'firmas_1','tipo':'texto_libre','orden':7,'activo':true,'props':{'contenido':'Elaborado por: ________________      Cargo: ________________\n\nFecha: _______________      Página 1 de 1','tamano_fuente':9,'color_texto':'#424242','negrita':false}},
          {'id':'footer_1','tipo':'footer','orden':8,'activo':true,'props':{'contenido':'CONFIDENCIAL — Documento de uso interno exclusivo','tamano_fuente':7,'color_texto':'#BDBDBD'}},
        ]);

  /// Plantilla por defecto para presupuestos
  static PdfTemplate defaultPresupuesto(String empresaId) => PdfTemplate(
        id: '',
        empresaId: empresaId,
        nombre: 'Presupuesto Estándar',
        descripcion: 'Plantilla por defecto para presupuestos',
        tipo: TipoDocumentoPdf.presupuesto,
        esDefault: true,
        activa: true,
        fechaCreacion: DateTime.now(),
        fechaModificacion: DateTime.now(),
        colorPrimario: '#2E7D32',
        colorSecundario: '#1B5E20',
        bloques: [
          {
            'id': 'header_1',
            'tipo': 'header',
            'orden': 0,
            'activo': true,
            'props': {
              'mostrar_logo': true,
              'mostrar_datos_empresa': true,
              'color_fondo': '#2E7D32',
              'color_texto': '#FFFFFF',
              'padding': 18,
              'border_radius': 12,
            },
          },
          {
            'id': 'cliente_1',
            'tipo': 'cliente',
            'orden': 1,
            'activo': true,
            'props': {
              'titulo': 'PRESUPUESTO PARA:',
              'mostrar_nif': true,
              'mostrar_direccion': true,
              'mostrar_email': true,
              'color_fondo': '#F1F8E9',
              'border_radius': 8,
            },
          },
          {
            'id': 'tabla_1',
            'tipo': 'tabla_lineas',
            'orden': 2,
            'activo': true,
            'props': {
              'mostrar_cantidad': true,
              'mostrar_precio_unitario': true,
              'mostrar_descuento': true,
              'mostrar_iva': true,
              'mostrar_base_imponible': true,
              'color_cabecera': '#1B5E20',
              'color_fila_par': '#FFFFFF',
              'color_fila_impar': '#F9FBE7',
            },
          },
          {
            'id': 'totales_1',
            'tipo': 'totales',
            'orden': 3,
            'activo': true,
            'props': {
              'mostrar_base': true,
              'mostrar_iva': true,
              'mostrar_total': true,
              'alineacion': 'derecha',
              'ancho': 240,
            },
          },
          {
            'id': 'validez_1',
            'tipo': 'texto_libre',
            'orden': 4,
            'activo': true,
            'props': {
              'contenido':
                  'Este presupuesto tiene una validez de 30 días desde su fecha de emisión.',
              'tamano_fuente': 9,
              'color_texto': '#757575',
              'italic': true,
            },
          },
        ],
      );
}



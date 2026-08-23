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

  /// 'clasico' | 'linea' | 'bold' — controla el layout del PDF al previsualizar
  final String estiloLayout;

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
    this.estiloLayout = 'clasico',
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
      estiloLayout: data['estilo_layout'] as String? ?? 'clasico',
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
        'estilo_layout': estiloLayout,
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
    String? estiloLayout,
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
      estiloLayout: estiloLayout ?? this.estiloLayout,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // GALERÍA DE PLANTILLAS PROFESIONALES — 5 diseños listos para usar
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve las 5 plantillas profesionales de la galería.
  /// El usuario elige una y se guarda como copia en su empresa.
  static List<PdfTemplate> galeria(String empresaId) => [
    galeriaFacturaEjecutiva(empresaId),
    galeriaFacturaMinimalista(empresaId),
    galeriaFacturaVerde(empresaId),
    galeriaFacturaCoral(empresaId),
    galeriaFacturaPurpura(empresaId),
    galeriaProformaComercial(empresaId),
    galeriaProformaServicios(empresaId),
    galeriaPresupuestoNaranja(empresaId),
    galeriaRectificativaProfesional(empresaId),
    galeriaFacturaBordeau(empresaId),
  ];

  // ─── Factura #1 — Ejecutiva (Navy + dorado) ───────────────────────────────
  static PdfTemplate galeriaFacturaEjecutiva(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Ejecutiva',
        descripcion: 'Diseño oscuro y elegante para servicios de alto nivel. Cabecera en azul marino con datos de empresa destacados.',
        tipo: TipoDocumentoPdf.factura,
        esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#1A237E', colorSecundario: '#3949AB',
        margenHorizontal: 40, margenVertical: 40,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#1A237E','color_texto':'#FFFFFF','padding':22,'border_radius':0}},
          {'id':'sep_top','tipo':'separador','orden':1,'activo':true,'props':{'color':'#3949AB','grosor':3,'margen_vertical':0}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':true}},
          {'id':'cliente_1','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'FACTURAR A:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#EEF0FA','border_radius':6}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_base_imponible':true,'color_cabecera':'#1A237E','color_fila_par':'#FFFFFF','color_fila_impar':'#F3F4FC'}},
          {'id':'totales_1','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true,'alineacion':'derecha','ancho':240}},
          {'id':'sep_2','tipo':'separador','orden':6,'activo':true,'props':{'color':'#E8EAF6','grosor':1,'margen_vertical':8}},
          {'id':'pago_1','tipo':'forma_pago','orden':7,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#EEF0FA'}},
          {'id':'notas_1','tipo':'notas','orden':8,'activo':true,'props':{'placeholder':'Condiciones de pago y notas adicionales...','tamano_fuente':9,'color_texto':'#546E7A'}},
          {'id':'qr_1','tipo':'qr_verifactu','orden':9,'activo':true,'props':{'tamano':57,'mostrar_etiqueta':true}},
          {'id':'footer_1','tipo':'footer','orden':10,'activo':true,'props':{'contenido':'Gracias por confiar en nosotros — {{empresa_nombre}}','tamano_fuente':8,'color_texto':'#9E9E9E'}},
        ]);

  // ─── Factura #2 — Minimalista (Negro + tinte gris) ───────────────────────
  static PdfTemplate galeriaFacturaMinimalista(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId, estiloLayout: 'linea',
        nombre: 'Minimalista',
        descripcion: 'Diseño limpio y moderno sin cabecera de color. Ideal para startups y profesionales del diseño y tecnología.',
        tipo: TipoDocumentoPdf.factura,
        esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#212121', colorSecundario: '#424242',
        margenHorizontal: 44, margenVertical: 44,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#F7F7F7','color_texto':'#212121','padding':18,'border_radius':8}},
          {'id':'sep_acento','tipo':'separador','orden':1,'activo':true,'props':{'color':'#212121','grosor':2,'margen_vertical':4}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':false}},
          {'id':'sep_2','tipo':'separador','orden':3,'activo':true,'props':{'color':'#EEEEEE','grosor':1,'margen_vertical':6}},
          {'id':'cliente_1','tipo':'cliente','orden':4,'activo':true,'props':{'titulo':'DESTINATARIO:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#FAFAFA','border_radius':4}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':5,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':false,'mostrar_iva':true,'mostrar_base_imponible':false,'color_cabecera':'#212121','color_fila_par':'#FFFFFF','color_fila_impar':'#FAFAFA'}},
          {'id':'totales_1','tipo':'totales','orden':6,'activo':true,'props':{'mostrar_base':true,'mostrar_descuento':false,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true,'alineacion':'derecha','ancho':220}},
          {'id':'pago_1','tipo':'forma_pago','orden':7,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#FAFAFA'}},
          {'id':'notas_1','tipo':'notas','orden':8,'activo':true,'props':{'placeholder':'Observaciones...','tamano_fuente':9,'color_texto':'#9E9E9E'}},
          {'id':'sep_bottom','tipo':'separador','orden':9,'activo':true,'props':{'color':'#212121','grosor':1,'margen_vertical':4}},
          {'id':'qr_1','tipo':'qr_verifactu','orden':10,'activo':true,'props':{'tamano':50,'mostrar_etiqueta':false}},
        ]);

  // ─── Proforma #1 — Comercial (Teal + cyan) ───────────────────────────────
  static PdfTemplate galeriaProformaComercial(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Comercial',
        descripcion: 'Proforma con aspecto de confianza comercial en verde azulado. Perfecta para operaciones de importación/exportación o B2B.',
        tipo: TipoDocumentoPdf.proforma,
        esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#006064', colorSecundario: '#00838F',
        margenHorizontal: 36, margenVertical: 36,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#006064','color_texto':'#FFFFFF','padding':20,'border_radius':10}},
          {'id':'aviso_1','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'FACTURA PROFORMA\nEste documento no tiene validez fiscal ni contable. Su emisión no implica obligación de pago hasta la aceptación formal del pedido.','tamano_fuente':9,'color_texto':'#006064','negrita':false,'italic':true}},
          {'id':'sep_1','tipo':'separador','orden':2,'activo':true,'props':{'color':'#B2EBF2','grosor':1,'margen_vertical':6}},
          {'id':'info_1','tipo':'info_documento','orden':3,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':false}},
          {'id':'cliente_1','tipo':'cliente','orden':4,'activo':true,'props':{'titulo':'OFERTA DIRIGIDA A:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#E0F7FA','border_radius':8}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':5,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_base_imponible':true,'color_cabecera':'#006064','color_fila_par':'#FFFFFF','color_fila_impar':'#E0F7FA'}},
          {'id':'totales_1','tipo':'totales','orden':6,'activo':true,'props':{'mostrar_base':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_irpf':false,'mostrar_total':true,'alineacion':'derecha','ancho':240}},
          {'id':'validez_1','tipo':'texto_libre','orden':7,'activo':true,'props':{'contenido':'Esta oferta tiene una validez de 15 días desde la fecha de emisión. Los precios están sujetos a disponibilidad de stock.','tamano_fuente':9,'color_texto':'#546E7A','negrita':false,'italic':true}},
          {'id':'pago_1','tipo':'forma_pago','orden':8,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#E0F7FA'}},
          {'id':'footer_1','tipo':'footer','orden':9,'activo':true,'props':{'contenido':'PROFORMA — Sin efecto fiscal · Pendiente de confirmación de pedido','tamano_fuente':7,'color_texto':'#90A4AE'}},
        ]);

  // ─── Proforma #2 — Servicios (Gris slate + ámbar) ────────────────────────
  static PdfTemplate galeriaProformaServicios(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Servicios Premium',
        descripcion: 'Proforma elegante para consultoras, agencias y servicios profesionales. Cabecera oscura con acento ámbar.',
        tipo: TipoDocumentoPdf.proforma,
        esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#37474F', colorSecundario: '#546E7A',
        margenHorizontal: 40, margenVertical: 38,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#263238','color_texto':'#FFFFFF','padding':22,'border_radius':0}},
          {'id':'sep_amber','tipo':'separador','orden':1,'activo':true,'props':{'color':'#FFC107','grosor':4,'margen_vertical':0}},
          {'id':'aviso_1','tipo':'texto_libre','orden':2,'activo':true,'props':{'contenido':'PRESUPUESTO / PROFORMA — Documento sin efecto fiscal. Válido como propuesta económica de servicios profesionales.','tamano_fuente':9,'color_texto':'#FF8F00','negrita':false,'italic':false}},
          {'id':'info_1','tipo':'info_documento','orden':3,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':false}},
          {'id':'sep_2','tipo':'separador','orden':4,'activo':true,'props':{'color':'#ECEFF1','grosor':1,'margen_vertical':6}},
          {'id':'cliente_1','tipo':'cliente','orden':5,'activo':true,'props':{'titulo':'PROPUESTA PARA:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#ECEFF1','border_radius':6}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':6,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':false,'mostrar_iva':true,'mostrar_base_imponible':true,'color_cabecera':'#37474F','color_fila_par':'#FFFFFF','color_fila_impar':'#F5F7F8'}},
          {'id':'totales_1','tipo':'totales','orden':7,'activo':true,'props':{'mostrar_base':true,'mostrar_descuento':false,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true,'alineacion':'derecha','ancho':240}},
          {'id':'notas_1','tipo':'notas','orden':8,'activo':true,'props':{'placeholder':'Alcance de los servicios, condiciones y plazos de entrega...','tamano_fuente':9,'color_texto':'#607D8B'}},
          {'id':'validez_1','tipo':'texto_libre','orden':9,'activo':true,'props':{'contenido':'Esta propuesta tiene una validez de 30 días. Una vez aceptada se procederá a formalizar el contrato de servicios.','tamano_fuente':9,'color_texto':'#90A4AE','negrita':false,'italic':true}},
          {'id':'footer_1','tipo':'footer','orden':10,'activo':true,'props':{'contenido':'PROFORMA — Documento de propuesta económica · Sin efectos contables','tamano_fuente':7,'color_texto':'#90A4AE'}},
        ]);

  // ─── Rectificativa #1 — Profesional (Morado profundo) ────────────────────
  static PdfTemplate galeriaRectificativaProfesional(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Profesional',
        descripcion: 'Factura rectificativa en morado profundo. Diseño sobrio que diferencia claramente el documento de corrección de una factura ordinaria.',
        tipo: TipoDocumentoPdf.facturaRectificativa,
        esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#4527A0', colorSecundario: '#311B92',
        margenHorizontal: 38, margenVertical: 38,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#311B92','color_texto':'#FFFFFF','padding':20,'border_radius':0}},
          {'id':'sep_top','tipo':'separador','orden':1,'activo':true,'props':{'color':'#EDE7F6','grosor':3,'margen_vertical':0}},
          {'id':'badge_1','tipo':'texto_libre','orden':2,'activo':true,'props':{'contenido':'FACTURA RECTIFICATIVA\nEste documento corrige y anula parcial o totalmente la factura de referencia indicada a continuación.','tamano_fuente':10,'color_texto':'#4527A0','negrita':true,'italic':false}},
          {'id':'ref_1','tipo':'texto_libre','orden':3,'activo':true,'props':{'contenido':'Rectifica la factura: ____________________   de fecha: ____________________\nMotivo de la rectificación: □ Error en datos  □ Devolución  □ Descuento posterior  □ Otro','tamano_fuente':9,'color_texto':'#5E35B1','negrita':false,'italic':false}},
          {'id':'sep_2','tipo':'separador','orden':4,'activo':true,'props':{'color':'#EDE7F6','grosor':1,'margen_vertical':6}},
          {'id':'info_1','tipo':'info_documento','orden':5,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':false,'mostrar_estado':false}},
          {'id':'cliente_1','tipo':'cliente','orden':6,'activo':true,'props':{'titulo':'RECTIFICACIÓN PARA:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#EDE7F6','border_radius':8}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':7,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_base_imponible':true,'color_cabecera':'#4527A0','color_fila_par':'#FFFFFF','color_fila_impar':'#F3F0FA'}},
          {'id':'totales_1','tipo':'totales','orden':8,'activo':true,'props':{'mostrar_base':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true,'alineacion':'derecha','ancho':240}},
          {'id':'sep_3','tipo':'separador','orden':9,'activo':true,'props':{'color':'#D1C4E9','grosor':1,'margen_vertical':8}},
          {'id':'notas_1','tipo':'notas','orden':10,'activo':true,'props':{'placeholder':'Justificación detallada de la rectificación...','tamano_fuente':9,'color_texto':'#757575'}},
          {'id':'qr_1','tipo':'qr_verifactu','orden':11,'activo':true,'props':{'tamano':57,'mostrar_etiqueta':true}},
          {'id':'footer_1','tipo':'footer','orden':12,'activo':true,'props':{'contenido':'Documento emitido en cumplimiento del Art. 80 de la Ley 37/1992 del IVA','tamano_fuente':7,'color_texto':'#9E9E9E'}},
        ]);

  // ─── Factura #3 — Verde Esmeralda ────────────────────────────────────────
  static PdfTemplate galeriaFacturaVerde(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId, estiloLayout: 'bold',
        nombre: 'Esmeralda',
        descripcion: 'Cabecera verde oscura con separador de acento. Perfecta para negocios de naturaleza, wellness o ecológicos.',
        tipo: TipoDocumentoPdf.factura, esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#1B5E20', colorSecundario: '#2E7D32',
        margenHorizontal: 40, margenVertical: 40,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#1B5E20','color_texto':'#FFFFFF','padding':20,'border_radius':14}},
          {'id':'sep_1','tipo':'separador','orden':1,'activo':true,'props':{'color':'#A5D6A7','grosor':2,'margen_vertical':2}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':true}},
          {'id':'cliente_1','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'PARA:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#E8F5E9','border_radius':10}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':false,'mostrar_iva':true,'mostrar_base_imponible':true,'color_cabecera':'#2E7D32','color_fila_par':'#FFFFFF','color_fila_impar':'#F1F8E9'}},
          {'id':'totales_1','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true,'alineacion':'derecha','ancho':230}},
          {'id':'pago_1','tipo':'forma_pago','orden':6,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#E8F5E9'}},
          {'id':'notas_1','tipo':'notas','orden':7,'activo':true,'props':{'placeholder':'Notas...','tamano_fuente':9,'color_texto':'#558B2F'}},
          {'id':'qr_1','tipo':'qr_verifactu','orden':8,'activo':true,'props':{'tamano':50,'mostrar_etiqueta':true}},
        ]);

  // ─── Factura #4 — Coral / Terracota ──────────────────────────────────────
  static PdfTemplate galeriaFacturaCoral(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Coral',
        descripcion: 'Diseño cálido y cercano en tonos coral y naranja. Ideal para comercios, hostelería y profesionales creativos.',
        tipo: TipoDocumentoPdf.factura, esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#BF360C', colorSecundario: '#D84315',
        margenHorizontal: 38, margenVertical: 38,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#BF360C','color_texto':'#FFFFFF','padding':18,'border_radius':0}},
          {'id':'sep_amber','tipo':'separador','orden':1,'activo':true,'props':{'color':'#FF8A65','grosor':3,'margen_vertical':0}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':true}},
          {'id':'sep_2','tipo':'separador','orden':3,'activo':true,'props':{'color':'#FBE9E7','grosor':1,'margen_vertical':4}},
          {'id':'cliente_1','tipo':'cliente','orden':4,'activo':true,'props':{'titulo':'FACTURAR A:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#FBE9E7','border_radius':6}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':5,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_base_imponible':false,'color_cabecera':'#BF360C','color_fila_par':'#FFFFFF','color_fila_impar':'#FFF8F6'}},
          {'id':'totales_1','tipo':'totales','orden':6,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'alineacion':'derecha','ancho':220}},
          {'id':'pago_1','tipo':'forma_pago','orden':7,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#FBE9E7'}},
          {'id':'footer_1','tipo':'footer','orden':8,'activo':true,'props':{'contenido':'¡Gracias por tu confianza! — {{empresa_nombre}}','tamano_fuente':9,'color_texto':'#BF360C'}},
        ]);

  // ─── Factura #5 — Púrpura Moderno ────────────────────────────────────────
  static PdfTemplate galeriaFacturaPurpura(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId, estiloLayout: 'linea',
        nombre: 'Púrpura',
        descripcion: 'Diseño moderno y atrevido en morado. Para agencias, estudios de diseño y tecnología con identidad visual fuerte.',
        tipo: TipoDocumentoPdf.factura, esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#6A1B9A', colorSecundario: '#4A148C',
        margenHorizontal: 42, margenVertical: 42,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#4A148C','color_texto':'#FFFFFF','padding':24,'border_radius':12}},
          {'id':'info_1','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':true}},
          {'id':'cliente_1','tipo':'cliente','orden':2,'activo':true,'props':{'titulo':'CLIENTE:','mostrar_nif':true,'mostrar_direccion':false,'mostrar_email':true,'color_fondo':'#F3E5F5','border_radius':8}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':false,'mostrar_iva':true,'mostrar_base_imponible':false,'color_cabecera':'#6A1B9A','color_fila_par':'#FFFFFF','color_fila_impar':'#F9F0FD'}},
          {'id':'totales_1','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true,'alineacion':'derecha','ancho':200}},
          {'id':'sep_1','tipo':'separador','orden':5,'activo':true,'props':{'color':'#CE93D8','grosor':1,'margen_vertical':8}},
          {'id':'pago_1','tipo':'forma_pago','orden':6,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#F3E5F5'}},
          {'id':'qr_1','tipo':'qr_verifactu','orden':7,'activo':true,'props':{'tamano':48,'mostrar_etiqueta':false}},
        ]);

  // ─── Presupuesto naranja / ámbar ──────────────────────────────────────────
  static PdfTemplate galeriaPresupuestoNaranja(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId,
        nombre: 'Ámbar Premium',
        descripcion: 'Presupuesto con cabecera naranja oscuro y acento dorado. Transmite profesionalidad y dinamismo.',
        tipo: TipoDocumentoPdf.presupuesto, esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#E65100', colorSecundario: '#BF360C',
        margenHorizontal: 38, margenVertical: 38,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#E65100','color_texto':'#FFFFFF','padding':20,'border_radius':0}},
          {'id':'sep_gold','tipo':'separador','orden':1,'activo':true,'props':{'color':'#FFC107','grosor':4,'margen_vertical':0}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':false}},
          {'id':'cliente_1','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'PRESUPUESTO PARA:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#FFF3E0','border_radius':8}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_base_imponible':true,'color_cabecera':'#E65100','color_fila_par':'#FFFFFF','color_fila_impar':'#FFF8F0'}},
          {'id':'totales_1','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'alineacion':'derecha','ancho':240}},
          {'id':'validez_1','tipo':'texto_libre','orden':6,'activo':true,'props':{'contenido':'Presupuesto válido por 30 días. Precios sujetos a disponibilidad.','tamano_fuente':9,'color_texto':'#E65100','negrita':false,'italic':true}},
          {'id':'footer_1','tipo':'footer','orden':7,'activo':true,'props':{'contenido':'PRESUPUESTO SIN CARÁCTER VINCULANTE · Pendiente de aceptación formal','tamano_fuente':7,'color_texto':'#BDBDBD'}},
        ]);

  // ─── Factura Bordeaux / Vino ──────────────────────────────────────────────
  static PdfTemplate galeriaFacturaBordeau(String empresaId) => PdfTemplate(
        id: '', empresaId: empresaId, estiloLayout: 'bold',
        nombre: 'Burdeos',
        descripcion: 'Diseño sofisticado en vino y granate. Para despachos, notarías, asesorías y profesionales del sector jurídico.',
        tipo: TipoDocumentoPdf.factura, esDefault: false, activa: true,
        fechaCreacion: DateTime.now(), fechaModificacion: DateTime.now(),
        colorPrimario: '#880E4F', colorSecundario: '#6A1B4D',
        margenHorizontal: 44, margenVertical: 44,
        bloques: [
          {'id':'header_1','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#880E4F','color_texto':'#FFFFFF','padding':22,'border_radius':0}},
          {'id':'sep_rosa','tipo':'separador','orden':1,'activo':true,'props':{'color':'#FCE4EC','grosor':3,'margen_vertical':2}},
          {'id':'info_1','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true,'mostrar_estado':true}},
          {'id':'cliente_1','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'EMITIDA A:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#FCE4EC','border_radius':6}},
          {'id':'tabla_1','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_base_imponible':true,'color_cabecera':'#880E4F','color_fila_par':'#FFFFFF','color_fila_impar':'#FFF0F6'}},
          {'id':'totales_1','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_descuento':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true,'alineacion':'derecha','ancho':250}},
          {'id':'pago_1','tipo':'forma_pago','orden':6,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#FCE4EC'}},
          {'id':'notas_1','tipo':'notas','orden':7,'activo':true,'props':{'placeholder':'Observaciones legales...','tamano_fuente':9,'color_texto':'#880E4F'}},
          {'id':'qr_1','tipo':'qr_verifactu','orden':8,'activo':true,'props':{'tamano':55,'mostrar_etiqueta':true}},
          {'id':'footer_1','tipo':'footer','orden':9,'activo':true,'props':{'contenido':'Documento emitido conforme a la normativa vigente de facturación electrónica','tamano_fuente':7,'color_texto':'#CE93D8'}},
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



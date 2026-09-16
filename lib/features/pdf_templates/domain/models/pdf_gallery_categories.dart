import 'pdf_template.dart';

// ──────────────────────────────────────────────────────────────────────────────
// PdfGallery — 90 diseños listos organizados por categoría y tipo de documento
// ──────────────────────────────────────────────────────────────────────────────

class PdfGallery {
  // ── Listas por tipo específico (para sub-filtros en la pantalla) ────────────

  static List<PdfTemplate> facturas(String e) => [
    _d1Corp(e),
    _d2Minimal(e),
    _d3Hero(e),
    _d4Sidebar(e),
    _d5Cards(e),
    _d6Dark(e),
    _d7Exec(e),
    _nazariFactura(e),
    _nazariFacturaOscuro(e),
    _facIndigo(e),
  ];

  static List<PdfTemplate> proformas(String e) => [
    // ── 7 layouts completos (mismos diseños que Facturas, adaptados) ──
    _profD1Corp(e),
    _profD2Minimal(e),
    _profD3Hero(e),
    _profD4Sidebar(e),
    _profD5Cards(e),
    _profD6Dark(e),
    _profD7Exec(e),
    // ── Diseños adicionales basados en clasico/linea ──
    PdfTemplate.galeriaProformaComercial(e),
    PdfTemplate.galeriaProformaServicios(e),
    _profVerde(e),
    _profNaranja(e),
    _profMorada(e),
  ];

  static List<PdfTemplate> rectificativas(String e) => [
    _rectD1Corp(e), _rectD2Minimal(e), _rectD3Hero(e),
    _rectD4Sidebar(e), _rectD5Cards(e), _rectD6Dark(e), _rectD7Exec(e),
    _rectRoja(e),   // bold — estructura diferente
    _rectGris(e),   // linea — estructura diferente
    _rectAzul(e),   // clasico — estructura diferente
  ];

  static List<PdfTemplate> presupuestos(String e) => [
    _presD1Corp(e), _presD2Minimal(e), _presD3Hero(e),
    _presD4Sidebar(e), _presD5Cards(e), _presD6Dark(e), _presD7Exec(e),
    _pPlatino(e),   // linea — estructura diferente
    _pMarino(e), _pJade(e), _pTierra(e), _pVioleta(e),
  ];

  static List<PdfTemplate> albaranes(String e) => [
    _albD1Corp(e), _albD2Minimal(e), _albD3Hero(e),
    _albD4Sidebar(e), _albD5Cards(e), _albD6Dark(e), _albD7Exec(e),
    _aGrafito(e),  // linea — estructura diferente
    _aOceano(e), _aSolar(e), _aRosa(e),
  ];

  static List<PdfTemplate> fichajesTipo(String e) => [
    _ficD1Corp(e), _ficD2Minimal(e), _ficD3Hero(e),
    _ficD4Sidebar(e), _ficD5Cards(e), _ficD6Dark(e), _ficD7Exec(e),
    _fichCorp(e), _fichTech(e), _fichMenta(e), _fichDusk(e),
  ];

  static List<PdfTemplate> horasEmpleadoTipo(String e) => [
    _horD1Corp(e), _horD2Minimal(e), _horD3Hero(e),
    _horD4Sidebar(e), _horD5Cards(e), _horD6Dark(e), _horD7Exec(e),
    _horasSl(e), _horasAtl(e), _horasSun(e), _horasIndigo(e), _horasCoral(e),
  ];

  static List<PdfTemplate> informesTipo(String e) => [
    _infD1Corp(e), _infD2Minimal(e), _infD3Hero(e),
    _infD4Sidebar(e), _infD5Cards(e), _infD6Dark(e), _infD7Exec(e),
    _infLimp(e), _infBosque(e), _infEjec(e), _infIndigo(e), _infTerra(e),
  ];

  // ── Acceso por categoría (agrupa tipos relacionados) ────────────────────────
  static List<PdfTemplate> facturacion(String e) => [
    ...facturas(e),
    ...proformas(e),
    ...rectificativas(e),
  ];

  static List<PdfTemplate> comercial(String e) => [
    ...presupuestos(e),
    ...albaranes(e),
  ];

  static List<PdfTemplate> interno(String e) => [
    ...fichajesTipo(e),
    ...horasEmpleadoTipo(e),
    ...informesTipo(e),
  ];

  // ─────────────────────────────────────────────────────────────────────────────
  // FACTURACIÓN — 1 nuevo (+ 9 existentes arriba)
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _facIndigo(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Índigo',
    descripcion:'Factura clean en índigo. Para consultoras y tecnología con identidad visual moderna.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#3730A3', colorSecundario:'#4338CA',
    margenHorizontal:38, margenVertical:38, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#3730A3','color_texto':'#FFFFFF','padding':14,'border_radius':8}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#EEF2FF','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#3730A3','color_fila_par':'#FFFFFF','color_fila_impar':'#F5F3FF'}},
      {'id':'to','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'p','tipo':'forma_pago','orden':5,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#EEF2FF'}},
      {'id':'q','tipo':'qr_verifactu','orden':6,'activo':true,'props':{'tamano':46}},
    ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // COMERCIAL — Presupuestos (5) + Albaranes (4) = 9 nuevos
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _pMarino(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Marino',
    descripcion:'Presupuesto en azul marino profundo. Serio, profesional y de confianza.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#0D47A1', colorSecundario:'#1565C0',
    margenHorizontal:38, margenVertical:38, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#0D47A1','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'s','tipo':'separador','orden':1,'activo':true,'props':{'color':'#90CAF9','grosor':3,'margen_vertical':0}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'PRESUPUESTO PARA:','mostrar_nif':true,'color_fondo':'#E3F2FD','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#0D47A1','color_fila_par':'#FFFFFF','color_fila_impar':'#F0F7FF'}},
      {'id':'to','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'Presupuesto válido 30 días. Sujeto a disponibilidad.','tamano_fuente':7,'color_texto':'#9E9E9E'}},
    ]);

  static PdfTemplate _pPlatino(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Platino',
    descripcion:'Presupuesto minimalista en gris platino. Elegante y neutro, apto para cualquier sector.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#546E7A', colorSecundario:'#607D8B',
    margenHorizontal:42, margenVertical:42, estiloLayout:'linea', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#546E7A','color_texto':'#FFFFFF','padding':14,'border_radius':4}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#ECEFF1','border_radius':4}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#546E7A','color_fila_par':'#FFFFFF','color_fila_impar':'#F9FAFB'}},
      {'id':'to','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':210}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Documento sin valor contractual hasta su aceptación formal.','tamano_fuente':7,'color_texto':'#90A4AE'}},
    ]);

  static PdfTemplate _pJade(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Jade',
    descripcion:'Presupuesto en verde jade. Para negocios de bienestar, salud, naturales y sostenibles.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#00695C', colorSecundario:'#00796B',
    margenHorizontal:38, margenVertical:38, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#00695C','color_texto':'#FFFFFF','padding':14,'border_radius':10}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'titulo':'OFERTA PARA:','mostrar_nif':true,'color_fondo':'#E0F2F1','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#00695C','color_fila_par':'#FFFFFF','color_fila_impar':'#F0FDF9'}},
      {'id':'to','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Gracias por considerar nuestra propuesta.','tamano_fuente':7,'color_texto':'#009688'}},
    ]);

  static PdfTemplate _pTierra(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Tierra',
    descripcion:'Presupuesto en tonos tierra y marrón cálido. Para arquitectura, interiorismo y construcción.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#5D4037', colorSecundario:'#6D4C41',
    margenHorizontal:40, margenVertical:40, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#5D4037','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'s','tipo':'separador','orden':1,'activo':true,'props':{'color':'#D7CCC8','grosor':2,'margen_vertical':0}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':3,'activo':true,'props':{'mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#EFEBE9','border_radius':4}},
      {'id':'t','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#5D4037','color_fila_par':'#FFFFFF','color_fila_impar':'#FDF6F3'}},
      {'id':'to','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'Presupuesto orientativo. Validez 15 días desde la emisión.','tamano_fuente':7,'color_texto':'#A1887F'}},
    ]);

  static PdfTemplate _pVioleta(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Violeta',
    descripcion:'Presupuesto en violeta y lavanda. Para eventos, decoración y sectores creativos.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#7B1FA2', colorSecundario:'#8E24AA',
    margenHorizontal:38, margenVertical:38, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#7B1FA2','color_texto':'#FFFFFF','padding':14,'border_radius':6}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'titulo':'PROPUESTA PARA:','mostrar_nif':true,'color_fondo':'#F3E5F5','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#7B1FA2','color_fila_par':'#FFFFFF','color_fila_impar':'#FDF6FF'}},
      {'id':'to','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Propuesta válida 30 días. Condiciones sujetas a cambio.','tamano_fuente':7,'color_texto':'#AB47BC'}},
    ]);

  static PdfTemplate _aOceano(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Océano',
    descripcion:'Albarán en azul océano. Para logística, distribución y transporte.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#006064', colorSecundario:'#00838F',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#006064','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'titulo':'ENTREGA A:','mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#E0F7FA','border_radius':4}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':false,'mostrar_iva':false,'color_cabecera':'#006064','color_fila_par':'#FFFFFF','color_fila_impar':'#F0FDFE'}},
      {'id':'f','tipo':'footer','orden':4,'activo':true,'props':{'contenido':'Albarán de entrega. Firmar en caso de conformidad.','tamano_fuente':7,'color_texto':'#9E9E9E'}},
    ]);

  static PdfTemplate _aGrafito(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Grafito',
    descripcion:'Albarán oscuro en grafito. Profesional y de alto contraste para cualquier entrega.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#263238', colorSecundario:'#37474F',
    margenHorizontal:36, margenVertical:36, estiloLayout:'linea', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#263238','color_texto':'#FFFFFF','padding':14,'border_radius':4}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'titulo':'DESTINATARIO:','mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#ECEFF1','border_radius':4}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':false,'mostrar_iva':false,'color_cabecera':'#263238','color_fila_par':'#FFFFFF','color_fila_impar':'#F5F5F5'}},
      {'id':'f','tipo':'footer','orden':4,'activo':true,'props':{'contenido':'Documento de entrega. Conservar como justificante.','tamano_fuente':7,'color_texto':'#78909C'}},
    ]);

  static PdfTemplate _aSolar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Solar',
    descripcion:'Albarán en amarillo solar. Llamativo y fácil de identificar. Perfecto para almacenes.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#F57F17', colorSecundario:'#F9A825',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#F57F17','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'s','tipo':'separador','orden':1,'activo':true,'props':{'color':'#FFE082','grosor':3,'margen_vertical':0}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true}},
      {'id':'c','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'ENTREGA A:','mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#FFFDE7','border_radius':4}},
      {'id':'t','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':false,'mostrar_iva':false,'color_cabecera':'#F57F17','color_fila_par':'#FFFFFF','color_fila_impar':'#FFFFF0'}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Albarán de entrega. Sin valor fiscal.','tamano_fuente':7,'color_texto':'#9E9E9E'}},
    ]);

  static PdfTemplate _aRosa(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Rosa',
    descripcion:'Albarán en rosa coral. Para comercios de moda, belleza y bienestar femenino.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#C2185B', colorSecundario:'#D81B60',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#C2185B','color_texto':'#FFFFFF','padding':14,'border_radius':8}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'titulo':'PARA:','mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#FCE4EC','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':false,'mostrar_iva':false,'color_cabecera':'#C2185B','color_fila_par':'#FFFFFF','color_fila_impar':'#FFF5F8'}},
      {'id':'f','tipo':'footer','orden':4,'activo':true,'props':{'contenido':'¡Gracias por tu compra! — Documento de entrega.','tamano_fuente':7,'color_texto':'#E91E63'}},
    ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // INTERNO / RRHH — 4 Fichajes + 3 Horas + 3 Informes = 10 nuevos
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _fichTech(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Tech Azul',
    descripcion:'Registro de fichajes en azul tecnológico. Para startups y empresas del sector digital.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1565C0', colorSecundario:'#1976D2',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#1565C0','color_texto':'#FFFFFF','padding':14,'border_radius':8}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true,'mostrar_departamento':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#1565C0'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_ordinarias':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Registro de asistencia — Uso interno','tamano_fuente':7,'color_texto':'#90A4AE'}},
    ]);

  static PdfTemplate _fichCorp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Corporativo',
    descripcion:'Fichaje oscuro y formal. Estilo corporativo para grandes empresas y organizaciones.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#212121', colorSecundario:'#424242',
    margenHorizontal:36, margenVertical:36, estiloLayout:'linea', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#212121','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true,'mostrar_departamento':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#212121'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_ordinarias':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'CONFIDENCIAL — Registro de presencia personal','tamano_fuente':7,'color_texto':'#757575'}},
    ]);

  static PdfTemplate _fichMenta(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Menta',
    descripcion:'Fichaje en verde menta fresco. Para clínicas, centros de salud y bienestar.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#00897B', colorSecundario:'#00ACC1',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#00897B','color_texto':'#FFFFFF','padding':14,'border_radius':10}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#00897B'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Registro horario — uso interno del centro','tamano_fuente':7,'color_texto':'#80CBC4'}},
    ]);

  static PdfTemplate _fichDusk(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dusk',
    descripcion:'Fichaje en naranja crepúsculo. Cálido y llamativo, para comercios y hostelería.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#E64A19', colorSecundario:'#F4511E',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#E64A19','color_texto':'#FFFFFF','padding':14,'border_radius':6}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#E64A19'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Control de presencia — uso interno','tamano_fuente':7,'color_texto':'#FFAB91'}},
    ]);

  static PdfTemplate _horasAtl(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Atlántico',
    descripcion:'Reporte de horas en azul atlántico. Limpio y profesional para cualquier empresa.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#0277BD', colorSecundario:'#0288D1',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#0277BD','color_texto':'#FFFFFF','padding':14,'border_radius':6}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true,'mostrar_departamento':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#0277BD'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_ordinarias':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Informe de horas — Documento interno','tamano_fuente':7,'color_texto':'#81D4FA'}},
    ]);

  static PdfTemplate _horasSun(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sunrise',
    descripcion:'Reporte de horas en tonos cálidos al amanecer. Motivador y positivo.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#F9A825', colorSecundario:'#FB8C00',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#F9A825','color_texto':'#FFFFFF','padding':14,'border_radius':8}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#F57F17'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_ordinarias':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Reporte de horas trabajadas — Uso interno','tamano_fuente':7,'color_texto':'#FFD54F'}},
    ]);

  static PdfTemplate _horasSl(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Slate',
    descripcion:'Reporte de horas en gris pizarra. Neutro y elegante para gestión de RRHH.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#455A64', colorSecundario:'#546E7A',
    margenHorizontal:38, margenVertical:38, estiloLayout:'linea', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#455A64','color_texto':'#FFFFFF','padding':14,'border_radius':4}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true,'mostrar_departamento':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#455A64'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_ordinarias':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Control horario — Documento interno de RRHH','tamano_fuente':7,'color_texto':'#90A4AE'}},
    ]);

  static PdfTemplate _infEjec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Ejecutivo',
    descripcion:'Informe ejecutivo en azul oscuro y dorado. Para dirección, juntas y alta gerencia.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1A237E', colorSecundario:'#283593',
    margenHorizontal:42, margenVertical:42, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#1A237E','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'s1','tipo':'separador','orden':1,'activo':true,'props':{'color':'#FFC107','grosor':2,'margen_vertical':0}},
      {'id':'ti','tipo':'texto_libre','orden':2,'activo':true,'props':{'contenido':'INFORME EJECUTIVO\nCLASIFICACIÓN: CONFIDENCIAL','tamano_fuente':13,'color_texto':'#1A237E','negrita':true}},
      {'id':'i','tipo':'info_documento','orden':3,'activo':true,'props':{'mostrar_fecha_emision':true}},
      {'id':'s2','tipo':'separador','orden':4,'activo':true,'props':{'color':'#C5CAE9','grosor':1,'margen_vertical':6}},
      {'id':'c','tipo':'texto_libre','orden':5,'activo':true,'props':{'contenido':'Resumen ejecutivo:\n\nDescriba aquí los puntos clave del informe...','tamano_fuente':10,'color_texto':'#212121'}},
      {'id':'n','tipo':'notas','orden':6,'activo':true,'props':{'placeholder':'Conclusiones y recomendaciones...','tamano_fuente':9,'color_texto':'#546E7A'}},
      {'id':'f','tipo':'footer','orden':7,'activo':true,'props':{'contenido':'CONFIDENCIAL — Solo para distribución interna autorizada','tamano_fuente':7,'color_texto':'#9FA8DA'}},
    ]);

  static PdfTemplate _infLimp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Limpio',
    descripcion:'Informe minimalista en blanco y gris. Máxima legibilidad para cualquier departamento.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#616161', colorSecundario:'#757575',
    margenHorizontal:44, margenVertical:44, estiloLayout:'linea', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#616161','color_texto':'#FFFFFF','padding':14,'border_radius':4}},
      {'id':'ti','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'INFORME INTERNO','tamano_fuente':14,'color_texto':'#424242','negrita':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true}},
      {'id':'s','tipo':'separador','orden':3,'activo':true,'props':{'color':'#E0E0E0','grosor':1,'margen_vertical':8}},
      {'id':'c','tipo':'texto_libre','orden':4,'activo':true,'props':{'contenido':'Contenido del informe:\n\n...','tamano_fuente':10,'color_texto':'#424242'}},
      {'id':'n','tipo':'notas','orden':5,'activo':true,'props':{'tamano_fuente':9,'color_texto':'#757575'}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'Documento de uso interno — Prohibida su distribución externa','tamano_fuente':7,'color_texto':'#BDBDBD'}},
    ]);

  static PdfTemplate _infIndigo(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Índigo Corp',
    descripcion:'Informe corporativo en índigo y lavanda. Para recursos humanos y departamentos técnicos.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#4527A0', colorSecundario:'#512DA8',
    margenHorizontal:40, margenVertical:40, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#4527A0','color_texto':'#FFFFFF','padding':14,'border_radius':6}},
      {'id':'ti','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'INFORME INTERNO CONFIDENCIAL','tamano_fuente':12,'color_texto':'#4527A0','negrita':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true}},
      {'id':'s','tipo':'separador','orden':3,'activo':true,'props':{'color':'#D1C4E9','grosor':1,'margen_vertical':8}},
      {'id':'c','tipo':'texto_libre','orden':4,'activo':true,'props':{'contenido':'Objeto del informe:\n\nDescripción detallada del asunto...','tamano_fuente':10,'color_texto':'#212121'}},
      {'id':'n','tipo':'notas','orden':5,'activo':true,'props':{'placeholder':'Observaciones adicionales...','tamano_fuente':9,'color_texto':'#673AB7'}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'USO INTERNO — Documento de circulación restringida','tamano_fuente':7,'color_texto':'#B39DDB'}},
    ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // PROFORMAS — 3 nuevos
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _profVerde(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Proforma Jade',
    descripcion:'Factura proforma en verde jade. Para presupuestos previos en negocios de bienestar.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#00695C', colorSecundario:'#00796B',
    margenHorizontal:38, margenVertical:38, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#00695C','color_texto':'#FFFFFF','padding':14,'border_radius':8}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'titulo':'PROFORMA PARA:','mostrar_nif':true,'color_fondo':'#E0F2F1','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#00695C','color_fila_par':'#FFFFFF','color_fila_impar':'#F0FDF9'}},
      {'id':'to','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'DOCUMENTO PROFORMA SIN VALIDEZ FISCAL — Sujeto a aceptación formal','tamano_fuente':7,'color_texto':'#009688'}},
    ]);

  static PdfTemplate _profNaranja(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Proforma Solar',
    descripcion:'Proforma en naranja solar. Dinámica y clara para comercios y servicios con estilo.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#E65100', colorSecundario:'#BF360C',
    margenHorizontal:38, margenVertical:38, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#E65100','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'s','tipo':'separador','orden':1,'activo':true,'props':{'color':'#FFC107','grosor':3,'margen_vertical':0}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':3,'activo':true,'props':{'titulo':'PROFORMA PARA:','mostrar_nif':true,'color_fondo':'#FBE9E7','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#E65100','color_fila_par':'#FFFFFF','color_fila_impar':'#FFF8F6'}},
      {'id':'to','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'PROFORMA — No constituye factura. Sujeto a confirmación del pedido.','tamano_fuente':7,'color_texto':'#BF360C'}},
    ]);

  static PdfTemplate _profMorada(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Proforma Lila',
    descripcion:'Proforma en lila y violeta. Para agencias creativas y servicios digitales.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#6A1B9A', colorSecundario:'#7B1FA2',
    margenHorizontal:40, margenVertical:40, estiloLayout:'linea', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#6A1B9A','color_texto':'#FFFFFF','padding':14,'border_radius':10}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'titulo':'ESTIMADO PARA:','mostrar_nif':true,'color_fondo':'#F3E5F5','border_radius':8}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#6A1B9A','color_fila_par':'#FFFFFF','color_fila_impar':'#FDF6FF'}},
      {'id':'to','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Proforma orientativa. Sin efecto fiscal hasta emisión de factura oficial.','tamano_fuente':7,'color_texto':'#AB47BC'}},
    ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // RECTIFICATIVAS — 3 nuevas
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _rectAzul(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Rectificativa Azul',
    descripcion:'Factura rectificativa en azul marino. Formal y clara para correcciones.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#0D47A1', colorSecundario:'#1565C0',
    margenHorizontal:40, margenVertical:40, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#0D47A1','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'s','tipo':'separador','orden':1,'activo':true,'props':{'color':'#EF5350','grosor':3,'margen_vertical':0}},
      {'id':'ti','tipo':'texto_libre','orden':2,'activo':true,'props':{'contenido':'FACTURA RECTIFICATIVA\nDocumento emitido conforme al Art. 15 del R.D. 1619/2012','tamano_fuente':10,'color_texto':'#0D47A1','negrita':true}},
      {'id':'i','tipo':'info_documento','orden':3,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':4,'activo':true,'props':{'mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#E3F2FD','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':5,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#0D47A1','color_fila_par':'#FFFFFF','color_fila_impar':'#F0F7FF'}},
      {'id':'to','tipo':'totales','orden':6,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':230}},
      {'id':'q','tipo':'qr_verifactu','orden':7,'activo':true,'props':{'tamano':46}},
    ]);

  static PdfTemplate _rectRoja(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Rectificativa Roja',
    descripcion:'Rectificativa en rojo granada. Alta visibilidad para gestión de devoluciones.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#B71C1C', colorSecundario:'#C62828',
    margenHorizontal:40, margenVertical:40, estiloLayout:'bold', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#B71C1C','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'ti','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'FACTURA RECTIFICATIVA','tamano_fuente':12,'color_texto':'#B71C1C','negrita':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true}},
      {'id':'c','tipo':'cliente','orden':3,'activo':true,'props':{'mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#FFEBEE','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#B71C1C','color_fila_par':'#FFFFFF','color_fila_impar':'#FFF5F5'}},
      {'id':'to','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':230}},
      {'id':'q','tipo':'qr_verifactu','orden':6,'activo':true,'props':{'tamano':46}},
    ]);

  static PdfTemplate _rectGris(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Rectificativa Gris',
    descripcion:'Rectificativa minimalista en gris. Neutra y profesional para cualquier corrección.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#37474F', colorSecundario:'#455A64',
    margenHorizontal:42, margenVertical:42, estiloLayout:'linea', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#37474F','color_texto':'#FFFFFF','padding':14,'border_radius':4}},
      {'id':'ti','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'FACTURA RECTIFICATIVA','tamano_fuente':11,'color_texto':'#37474F','negrita':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true}},
      {'id':'c','tipo':'cliente','orden':3,'activo':true,'props':{'mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'#ECEFF1','border_radius':4}},
      {'id':'t','tipo':'tabla_lineas','orden':4,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#37474F','color_fila_par':'#FFFFFF','color_fila_impar':'#F5F5F5'}},
      {'id':'to','tipo':'totales','orden':5,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':220}},
      {'id':'q','tipo':'qr_verifactu','orden':6,'activo':true,'props':{'tamano':46}},
    ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // HORAS EMPLEADO — 2 nuevos
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _horasIndigo(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Horas Índigo',
    descripcion:'Reporte de horas en índigo. Moderno y preciso para empresas tecnológicas.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#3730A3', colorSecundario:'#4338CA',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#3730A3','color_texto':'#FFFFFF','padding':14,'border_radius':8}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true,'mostrar_departamento':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#3730A3'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_ordinarias':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Reporte de horas — Documento interno de RRHH','tamano_fuente':7,'color_texto':'#A5B4FC'}},
    ]);

  static PdfTemplate _horasCoral(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Horas Coral',
    descripcion:'Reporte de horas en coral. Cálido y motivador para equipos de ventas y comerciales.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#BF360C', colorSecundario:'#D84315',
    margenHorizontal:36, margenVertical:36, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#BF360C','color_texto':'#FFFFFF','padding':14,'border_radius':0}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{'mostrar_cargo':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'t','tipo':'tabla_fichajes','orden':3,'activo':true,'props':{'mostrar_entrada':true,'mostrar_salida':true,'mostrar_duracion':true,'color_cabecera':'#BF360C'}},
      {'id':'r','tipo':'resumen_horas','orden':4,'activo':true,'props':{'mostrar_total':true,'mostrar_ordinarias':true,'mostrar_extra':true}},
      {'id':'f','tipo':'footer','orden':5,'activo':true,'props':{'contenido':'Control horario — Uso interno RRHH','tamano_fuente':7,'color_texto':'#FF8A65'}},
    ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // INFORMES INTERNOS — 2 nuevos
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _infTerra(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Informe Terracota',
    descripcion:'Informe interno en terracota y adobe. Para RRHH, gestión de equipos y formación.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#8D3B2B', colorSecundario:'#A04430',
    margenHorizontal:40, margenVertical:40, bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#8D3B2B','color_texto':'#FFFFFF','padding':14,'border_radius':4}},
      {'id':'ti','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'INFORME INTERNO','tamano_fuente':13,'color_texto':'#8D3B2B','negrita':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true}},
      {'id':'s','tipo':'separador','orden':3,'activo':true,'props':{'color':'#D7C1B0','grosor':1,'margen_vertical':6}},
      {'id':'c','tipo':'texto_libre','orden':4,'activo':true,'props':{'contenido':'Resumen:\n\n...','tamano_fuente':10,'color_texto':'#3E2723'}},
      {'id':'n','tipo':'notas','orden':5,'activo':true,'props':{'tamano_fuente':9,'color_texto':'#795548'}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'DOCUMENTO INTERNO — Uso exclusivo del departamento','tamano_fuente':7,'color_texto':'#BCAAA4'}},
    ]);

  static PdfTemplate _infBosque(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Informe Bosque',
    descripcion:'Informe en verde bosque oscuro. Para sostenibilidad, medioambiente y RSC.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1B5E20', colorSecundario:'#2E7D32',
    margenHorizontal:42, margenVertical:42, estiloLayout:'linea', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'color_fondo':'#1B5E20','color_texto':'#FFFFFF','padding':14,'border_radius':6}},
      {'id':'ti','tipo':'texto_libre','orden':1,'activo':true,'props':{'contenido':'INFORME INTERNO','tamano_fuente':12,'color_texto':'#1B5E20','negrita':true}},
      {'id':'i','tipo':'info_documento','orden':2,'activo':true,'props':{'mostrar_fecha_emision':true}},
      {'id':'s','tipo':'separador','orden':3,'activo':true,'props':{'color':'#A5D6A7','grosor':1,'margen_vertical':8}},
      {'id':'c','tipo':'texto_libre','orden':4,'activo':true,'props':{'contenido':'Contenido del informe:\n\n...','tamano_fuente':10,'color_texto':'#1B5E20'}},
      {'id':'n','tipo':'notas','orden':5,'activo':true,'props':{'tamano_fuente':9,'color_texto':'#388E3C'}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'CONFIDENCIAL — Circulación interna restringida','tamano_fuente':7,'color_texto':'#A5D6A7'}},
    ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // 7 DISEÑOS — factudiseño.html
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _d1Corp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Clásico Corporativo',
    descripcion:'Banda azul marino en cabecera, tabla formal con filas alternas, total en banda de color. Estilo corporativo clásico para cualquier sector.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1B2A4A', colorSecundario:'#1B2A4A',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d1_corp', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'color_fondo':'#1B2A4A','color_texto':'#FFFFFF'}},
      {'id':'c','tipo':'cliente','orden':1,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':2,'activo':true,'props':{'color_cabecera':'#1B2A4A'}},
      {'id':'to','tipo':'totales','orden':3,'activo':true,'props':{}},
      {'id':'f','tipo':'footer','orden':4,'activo':true,'props':{}},
    ]);

  static PdfTemplate _d2Minimal(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Minimalista',
    descripcion:'Todo espacio blanco, sin colores. Número de factura grande en tipografía fina. El texto manda. Ideal para agencias, diseñadores y consultoras.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#222222', colorSecundario:'#888888',
    margenHorizontal:64, margenVertical:60, estiloLayout:'d2_minimal', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _d3Hero(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Moderno Hero',
    descripcion:'Cabecera hero con degradado morado, total destacado y pills de meta. Cuerpo limpio con tarjetas. Para marcas con identidad visual fuerte.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#7C6CF0', colorSecundario:'#5B4FD4',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d3_hero', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'color_fondo':'#7C6CF0'}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _d4Sidebar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sidebar Dividido',
    descripcion:'Panel lateral oscuro con todos los meta-datos del documento y total destacado en lila. Cuerpo blanco con tabla limpia. Sofisticado y único.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1a1a1a', colorSecundario:'#8B85C4',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d4_sidebar', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _d5Cards(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Tarjetas por línea',
    descripcion:'Cada concepto es una tarjeta individual con icono y descripción. Sin tabla tradicional. Total muy visible en la parte superior. Muy visual y moderno.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#3E9C63', colorSecundario:'#2D7A4E',
    margenHorizontal:44, margenVertical:40, estiloLayout:'d5_cards', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _d6Dark(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dark Mode',
    descripcion:'Fondo completamente oscuro (#0F0F13), tarjetas de datos en gris oscuro y acento lila para el total. Para marcas premium y tecnológicas.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#A79BFF', colorSecundario:'#7C6CF0',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d6_dark', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _d7Exec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Compacto Ejecutivo',
    descripcion:'Formato compacto con cuadrícula de bordes visibles, sello PAGADO diagonal y totales en tabla. Estilo monospace ejecutivo para despachos y servicios formales.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#3E9C63', colorSecundario:'#1a1a1a',
    margenHorizontal:32, margenVertical:32, estiloLayout:'d7_exec', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // ESTILO NAZARI — paper limpio sin cabecera de color (nueva colección)
  // ─────────────────────────────────────────────────────────────────────────────

  static PdfTemplate _nazariFactura(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Nazarí Índigo',
    descripcion:'Factura paper-clean en índigo. Sin cabecera de color, estilo editorial: badge de tipo, tabla con bordes finos, totales alineados, nota legal con línea punteada.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#8B85C4', colorSecundario:'#8B85C4',
    margenHorizontal:52, margenVertical:48, estiloLayout:'nazari', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#8B85C4','color_texto':'#FFFFFF','padding':16,'border_radius':9}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'rgba(139,133,196,0.08)','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#8B85C4','color_fila_par':'#FFFFFF','color_fila_impar':'#FAFAFA'}},
      {'id':'to','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':240}},
      {'id':'p','tipo':'forma_pago','orden':5,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'Documento emitido conforme al Real Decreto 1619/2012.','tamano_fuente':7,'color_texto':'#A8A8AE'}},
    ]);

  static PdfTemplate _nazariFacturaOscuro(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Nazarí Terracota',
    descripcion:'Factura paper-clean en terracota. Estilo editorial sobrio y cálido, sin cabecera de color dominante. Badge discreto y tabla con jerarquía tipográfica.',
    tipo:TipoDocumentoPdf.factura, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#C08871', colorSecundario:'#C08871',
    margenHorizontal:52, margenVertical:48, estiloLayout:'nazari', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{'mostrar_logo':true,'mostrar_datos_empresa':true,'color_fondo':'#C08871','color_texto':'#FFFFFF','padding':16,'border_radius':9}},
      {'id':'i','tipo':'info_documento','orden':1,'activo':true,'props':{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}},
      {'id':'c','tipo':'cliente','orden':2,'activo':true,'props':{'mostrar_nif':true,'mostrar_direccion':true,'color_fondo':'rgba(192,136,113,0.08)','border_radius':6}},
      {'id':'t','tipo':'tabla_lineas','orden':3,'activo':true,'props':{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#C08871','color_fila_par':'#FFFFFF','color_fila_impar':'#FAFAF9'}},
      {'id':'to','tipo':'totales','orden':4,'activo':true,'props':{'mostrar_base':true,'mostrar_iva':true,'mostrar_total':true,'ancho':240}},
      {'id':'p','tipo':'forma_pago','orden':5,'activo':true,'props':{'mostrar_metodo':true,'mostrar_iban':true}},
      {'id':'f','tipo':'footer','orden':6,'activo':true,'props':{'contenido':'Documento emitido conforme al Real Decreto 1619/2012.','tamano_fuente':7,'color_texto':'#A8A8AE'}},
    ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // D1–D7 PARA FACTURAS RECTIFICATIVAS
  // Mismos diseños que las facturas pero con tipo=facturaRectificativa y acento rojo.
  // ═══════════════════════════════════════════════════════════════════════════

  static PdfTemplate _rectD1Corp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Corporativa Rect.',
    descripcion:'Banda de cabecera oscura con acento rojo. Diseño corporativo para rectificativas formales.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#B71C1C', colorSecundario:'#7F0000',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d1_corp', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _rectD2Minimal(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Minimalista Rect.',
    descripcion:'Diseño en blanco y negro con tipografía limpia. Ideal para correcciones discretas.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#212121', colorSecundario:'#424242',
    margenHorizontal:64, margenVertical:60, estiloLayout:'d2_minimal', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _rectD3Hero(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Hero Rect.',
    descripcion:'Cabecera hero con importe total prominente y acento rojo. Rectificativa con impacto visual.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#C62828', colorSecundario:'#B71C1C',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d3_hero', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _rectD4Sidebar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sidebar Rect.',
    descripcion:'Sidebar oscuro con acento rojizo. Diseño moderno que separa datos y conceptos.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#4A148C', colorSecundario:'#311B92',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d4_sidebar', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _rectD5Cards(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Cards Rect.',
    descripcion:'Cada línea como tarjeta individual. Muy claro para ver exactamente qué se rectifica.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#B71C1C', colorSecundario:'#7F0000',
    margenHorizontal:44, margenVertical:40, estiloLayout:'d5_cards', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _rectD6Dark(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dark Rect.',
    descripcion:'Diseño oscuro premium con acento rojo. Para marcas que quieren rectificativas con carácter.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#EF5350', colorSecundario:'#B71C1C',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d6_dark', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _rectD7Exec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Ejecutivo Rect.',
    descripcion:'Tabla compacta tipo talonario. Formato clásico ideal para despachos y asesorías.',
    tipo:TipoDocumentoPdf.facturaRectificativa, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#212121', colorSecundario:'#37474F',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d7_exec', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // D1–D7 PARA PROFORMAS
  // Mismos diseños que las facturas pero con tipo=proforma y tono naranja/teal.
  // ═══════════════════════════════════════════════════════════════════════════

  static PdfTemplate _profD1Corp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Corporativa Prof.',
    descripcion:'Banda de cabecera en naranja oscuro. Proforma corporativa para operaciones B2B.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#BF360C', colorSecundario:'#E64A19',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d1_corp', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _profD2Minimal(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Minimalista Prof.',
    descripcion:'Proforma en blanco y negro. Sin distracciones, solo los datos que importan.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#263238', colorSecundario:'#37474F',
    margenHorizontal:64, margenVertical:60, estiloLayout:'d2_minimal', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _profD3Hero(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Hero Prof.',
    descripcion:'Cabecera hero con importe total destacado. Proforma de alto impacto para propuestas comerciales.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#E65100', colorSecundario:'#BF360C',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d3_hero', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _profD4Sidebar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sidebar Prof.',
    descripcion:'Sidebar oscuro con acento ámbar. Diseño diferenciador para agencias y consultoras.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#E65100', colorSecundario:'#BF360C',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d4_sidebar', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _profD5Cards(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Cards Prof.',
    descripcion:'Cada servicio como tarjeta individual. Perfecto para propuestas de servicios detalladas.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#F57F17', colorSecundario:'#E65100',
    margenHorizontal:44, margenVertical:40, estiloLayout:'d5_cards', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _profD6Dark(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dark Prof.',
    descripcion:'Fondo oscuro con acento ámbar. Proforma de lujo para marcas premium y tecnológicas.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#FFC107', colorSecundario:'#FF8F00',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d6_dark', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _profD7Exec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Ejecutivo Prof.',
    descripcion:'Tabla ejecutiva compacta con sello visual. Proforma formal para despachos y notarías.',
    tipo:TipoDocumentoPdf.proforma, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#4E342E', colorSecundario:'#3E2723',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d7_exec', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // D1–D7 PARA PRESUPUESTOS
  // ═══════════════════════════════════════════════════════════════════════════
  static PdfTemplate _presD1Corp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Corporativo Pres.',
    descripcion:'Cabecera en verde bosque con datos de empresa. Presupuesto formal para operaciones B2B.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#2E7D32', colorSecundario:'#1B5E20',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d1_corp', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _presD2Minimal(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Minimalista Pres.',
    descripcion:'Presupuesto en blanco y negro. Sin distracciones, enfocado en el importe y conceptos.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1B5E20', colorSecundario:'#2E7D32',
    margenHorizontal:64, margenVertical:60, estiloLayout:'d2_minimal', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _presD3Hero(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Hero Pres.',
    descripcion:'Importe total prominente en la cabecera. Ideal para propuestas de alto valor.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#2E7D32', colorSecundario:'#1B5E20',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d3_hero', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _presD4Sidebar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sidebar Pres.',
    descripcion:'Sidebar oscuro con datos del cliente y total destacado. Diseño único para consultoras.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1B5E20', colorSecundario:'#2E7D32',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d4_sidebar', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _presD5Cards(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Cards Pres.',
    descripcion:'Cada concepto como tarjeta individual. Muy visual para propuestas de servicios.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#388E3C', colorSecundario:'#2E7D32',
    margenHorizontal:44, margenVertical:40, estiloLayout:'d5_cards', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _presD6Dark(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dark Pres.',
    descripcion:'Fondo oscuro con acento verde. Presupuesto premium para marcas tecnológicas.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#69F0AE', colorSecundario:'#00E676',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d6_dark', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _presD7Exec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Ejecutivo Pres.',
    descripcion:'Tabla compacta tipo talonario con sello. Presupuesto clásico para despachos.',
    tipo:TipoDocumentoPdf.presupuesto, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#33691E', colorSecundario:'#558B2F',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d7_exec', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // D1–D7 PARA ALBARANES
  // ═══════════════════════════════════════════════════════════════════════════
  static PdfTemplate _albD1Corp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Corporativo Alb.',
    descripcion:'Cabecera en verde con detalle de entrega. Albarán formal para operaciones logísticas.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#00695C', colorSecundario:'#004D40',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d1_corp', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _albD2Minimal(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Minimalista Alb.',
    descripcion:'Albarán limpio y sin adornos. Centrado en los artículos entregados.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#37474F', colorSecundario:'#455A64',
    margenHorizontal:64, margenVertical:60, estiloLayout:'d2_minimal', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _albD3Hero(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Hero Alb.',
    descripcion:'Cabecera hero con nombre del cliente destacado. Albarán con impacto visual.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#00838F', colorSecundario:'#006064',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d3_hero', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _albD4Sidebar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sidebar Alb.',
    descripcion:'Sidebar con datos del destinatario. Diseño moderno para entregas de productos.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#004D40', colorSecundario:'#00695C',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d4_sidebar', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _albD5Cards(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Cards Alb.',
    descripcion:'Cada artículo como tarjeta. Muy visual para albaranes con pocos conceptos.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#00796B', colorSecundario:'#004D40',
    margenHorizontal:44, margenVertical:40, estiloLayout:'d5_cards', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _albD6Dark(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dark Alb.',
    descripcion:'Fondo oscuro con acento turquesa. Para marcas premium con entregas de lujo.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#64FFDA', colorSecundario:'#1DE9B6',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d6_dark', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _albD7Exec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Ejecutivo Alb.',
    descripcion:'Tabla compacta con espacio para firmas. Albarán clásico con campo de conformidad.',
    tipo:TipoDocumentoPdf.albaran, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#212121', colorSecundario:'#424242',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d7_exec', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_lineas','orden':1,'activo':true,'props':{}},
      {'id':'to','tipo':'totales','orden':2,'activo':true,'props':{}},
    ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // D1–D7 PARA FICHAJES
  // ═══════════════════════════════════════════════════════════════════════════
  static PdfTemplate _ficD1Corp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Corporativo Fich.',
    descripcion:'Cabecera con franja de color y tabla de registros. Formal para informes de asistencia.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1565C0', colorSecundario:'#0D47A1',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d1_corp', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':1,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _ficD2Minimal(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Minimalista Fich.',
    descripcion:'Tipografía limpia sin cabecera de color. Informe de fichajes discreto y profesional.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#212121', colorSecundario:'#424242',
    margenHorizontal:64, margenVertical:60, estiloLayout:'d2_minimal', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':1,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _ficD3Hero(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Hero Fich.',
    descripcion:'Total de horas destacado en cabecera hero. Impactante para resúmenes mensuales.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#0277BD', colorSecundario:'#01579B',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d3_hero', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':1,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _ficD4Sidebar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sidebar Fich.',
    descripcion:'Sidebar con datos del empleado. Diseño moderno para informes de RRHH.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1A237E', colorSecundario:'#283593',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d4_sidebar', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':1,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _ficD5Cards(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Cards Fich.',
    descripcion:'Cada semana como tarjeta. Visual y organizado para seguimiento semanal.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1976D2', colorSecundario:'#1565C0',
    margenHorizontal:44, margenVertical:40, estiloLayout:'d5_cards', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':1,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _ficD6Dark(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dark Fich.',
    descripcion:'Fondo oscuro con acento azul eléctrico. Para empresas tech con identidad visual fuerte.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#448AFF', colorSecundario:'#2979FF',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d6_dark', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':1,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _ficD7Exec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Ejecutivo Fich.',
    descripcion:'Tabla compacta con campo de firma. Informe de fichajes para firma del empleado.',
    tipo:TipoDocumentoPdf.fichajes, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#263238', colorSecundario:'#37474F',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d7_exec', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':1,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':2,'activo':true,'props':{}},
    ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // D1–D7 PARA HORAS EMPLEADO
  // ═══════════════════════════════════════════════════════════════════════════
  static PdfTemplate _horD1Corp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Corporativo Horas',
    descripcion:'Cabecera con franja y KPIs de horas. Formal para reportes de productividad.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#6A1B9A', colorSecundario:'#4A148C',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d1_corp', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':2,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':3,'activo':true,'props':{}},
    ]);

  static PdfTemplate _horD2Minimal(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Minimalista Horas',
    descripcion:'Reporte de horas limpio y sin adornos. Datos precisos para auditorías.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#4A148C', colorSecundario:'#6A1B9A',
    margenHorizontal:64, margenVertical:60, estiloLayout:'d2_minimal', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':2,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':3,'activo':true,'props':{}},
    ]);

  static PdfTemplate _horD3Hero(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Hero Horas',
    descripcion:'Total de horas trabajadas en hero. Ideal para resúmenes anuales o de proyecto.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#7B1FA2', colorSecundario:'#4A148C',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d3_hero', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':2,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':3,'activo':true,'props':{}},
    ]);

  static PdfTemplate _horD4Sidebar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sidebar Horas',
    descripcion:'Sidebar con perfil del empleado. Diseño moderno para gestión de RRHH.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#4527A0', colorSecundario:'#311B92',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d4_sidebar', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':2,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':3,'activo':true,'props':{}},
    ]);

  static PdfTemplate _horD5Cards(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Cards Horas',
    descripcion:'Días como tarjetas individuales. Muy visual para revisiones de períodos cortos.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#8E24AA', colorSecundario:'#6A1B9A',
    margenHorizontal:44, margenVertical:40, estiloLayout:'d5_cards', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':2,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':3,'activo':true,'props':{}},
    ]);

  static PdfTemplate _horD6Dark(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dark Horas',
    descripcion:'Fondo oscuro con acento lila. Para empresas tech que quieren reportes con carácter.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#CE93D8', colorSecundario:'#BA68C8',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d6_dark', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':2,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':3,'activo':true,'props':{}},
    ]);

  static PdfTemplate _horD7Exec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Ejecutivo Horas',
    descripcion:'Tabla ejecutiva con campo de aprobación. Formal para gestión laboral con firma.',
    tipo:TipoDocumentoPdf.horasEmpleado, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#37474F', colorSecundario:'#263238',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d7_exec', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'e','tipo':'info_empleado','orden':1,'activo':true,'props':{}},
      {'id':'t','tipo':'tabla_fichajes','orden':2,'activo':true,'props':{}},
      {'id':'r','tipo':'resumen_horas','orden':3,'activo':true,'props':{}},
    ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // D1–D7 PARA INFORME INTERNO
  // ═══════════════════════════════════════════════════════════════════════════
  static PdfTemplate _infD1Corp(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Corporativo Inf.',
    descripcion:'Cabecera con franja oscura y marca de empresa. Informe interno para alta dirección.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#212121', colorSecundario:'#424242',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d1_corp', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'c','tipo':'texto_libre','orden':1,'activo':true,'props':{}},
      {'id':'n','tipo':'notas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _infD2Minimal(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Minimalista Inf.',
    descripcion:'Tipografía limpia con línea de acento. Informe interno sobrio y sin distracciones.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#37474F', colorSecundario:'#455A64',
    margenHorizontal:64, margenVertical:60, estiloLayout:'d2_minimal', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'c','tipo':'texto_libre','orden':1,'activo':true,'props':{}},
      {'id':'n','tipo':'notas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _infD3Hero(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Hero Inf.',
    descripcion:'Cabecera hero con título prominente. Informe de impacto para presentaciones.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#263238', colorSecundario:'#37474F',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d3_hero', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'c','tipo':'texto_libre','orden':1,'activo':true,'props':{}},
      {'id':'n','tipo':'notas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _infD4Sidebar(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Sidebar Inf.',
    descripcion:'Sidebar oscuro con clasificación del informe. Diseño moderno para informes ejecutivos.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#1A237E', colorSecundario:'#283593',
    margenHorizontal:0, margenVertical:0, estiloLayout:'d4_sidebar', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'c','tipo':'texto_libre','orden':1,'activo':true,'props':{}},
      {'id':'n','tipo':'notas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _infD5Cards(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Cards Inf.',
    descripcion:'Secciones como tarjetas individuales. Ideal para informes con puntos clave separados.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#546E7A', colorSecundario:'#455A64',
    margenHorizontal:44, margenVertical:40, estiloLayout:'d5_cards', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'c','tipo':'texto_libre','orden':1,'activo':true,'props':{}},
      {'id':'n','tipo':'notas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _infD6Dark(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Dark Inf.',
    descripcion:'Fondo oscuro con acento gris azulado. Informe confidencial con carácter premium.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#90A4AE', colorSecundario:'#78909C',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d6_dark', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'c','tipo':'texto_libre','orden':1,'activo':true,'props':{}},
      {'id':'n','tipo':'notas','orden':2,'activo':true,'props':{}},
    ]);

  static PdfTemplate _infD7Exec(String e) => PdfTemplate(
    id:'', empresaId:e, nombre:'Ejecutivo Inf.',
    descripcion:'Tabla ejecutiva compacta con campo de elaborado por. Informe clásico con firma.',
    tipo:TipoDocumentoPdf.informeInterno, esDefault:false, activa:true,
    fechaCreacion:DateTime.now(), fechaModificacion:DateTime.now(),
    colorPrimario:'#424242', colorSecundario:'#212121',
    margenHorizontal:48, margenVertical:48, estiloLayout:'d7_exec', bloques:[
      {'id':'h','tipo':'header','orden':0,'activo':true,'props':{}},
      {'id':'c','tipo':'texto_libre','orden':1,'activo':true,'props':{}},
      {'id':'n','tipo':'notas','orden':2,'activo':true,'props':{}},
    ]);
}

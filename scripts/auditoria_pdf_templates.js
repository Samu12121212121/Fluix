// Auditoria del modulo de Plantillas PDF - Fluix
const { PDFDocument, rgb, StandardFonts } = require('../functions/node_modules/pdf-lib');
const fs = require('fs');
const path = require('path');

const FECHA = '16 de septiembre de 2026';
const OUT = path.join(__dirname, 'Auditoria_PlantillasPDF_Fluix_2026.pdf');

const AZUL    = rgb(0.08, 0.39, 0.75);
const AZUL_OS = rgb(0.05, 0.28, 0.56);
const ROJO    = rgb(0.82, 0.18, 0.18);
const VERDE   = rgb(0.09, 0.70, 0.38);
const NARANJA = rgb(0.90, 0.45, 0.05);
const GRIS    = rgb(0.46, 0.49, 0.53);
const GRIS_CL = rgb(0.94, 0.95, 0.97);
const NEGRO   = rgb(0.07, 0.08, 0.10);
const BLANCO  = rgb(1, 1, 1);

// Strip non-ASCII to avoid WinAnsi encoding errors
function safe(s) {
  return String(s)
    .replace(/→/g, '=>')
    .replace(/←/g, '<=')
    .replace(/•/g, '-')
    .replace(/[^\x00-\x7F]/g, c => {
      const map = {
        'á':'a','é':'e','í':'i','ó':'o','ú':'u',
        'Á':'A','É':'E','Í':'I','Ó':'O','Ú':'U',
        'ü':'u','Ü':'U','ñ':'n','Ñ':'N',
        'à':'a','è':'e','ò':'o','â':'a','ê':'e',
        '–':'-','—':'--','“':'"','”':'"',
        '‘':"'",' ’':"'",'¿':'?','¡':'!',
        '€':'EUR','©':'(c)','®':'(R)','°':'deg',
        'ç':'c','Ç':'C',
      };
      return map[c] || '?';
    });
}

async function run() {
  const doc = await PDFDocument.create();
  const hv  = await doc.embedFont(StandardFonts.Helvetica);
  const hvB = await doc.embedFont(StandardFonts.HelveticaBold);
  const hvI = await doc.embedFont(StandardFonts.HelveticaOblique);

  const W = 595.28, H = 841.89;
  const ML = 48, MR = W - 48, CW = MR - ML;

  let pg, y;

  function newPage() {
    pg = doc.addPage([W, H]);
    y = H - 48;
    pg.drawLine({ start:{x:ML,y:36}, end:{x:MR,y:36}, thickness:0.5, color:GRIS });
    pg.drawText(safe('Auditoria Plantillas PDF - Fluix | Confidencial | ' + FECHA),
      { x:ML, y:22, size:7, font:hv, color:GRIS });
  }

  function checkY(need) {
    if (y - (need||60) < 60) newPage();
  }

  function txt(text, opts) {
    const {x=ML, size=10, font=hv, color=NEGRO, maxWidth=CW} = opts||{};
    const s = safe(text);
    const words = s.split(' ');
    let line = '';
    const lines = [];
    for (const w of words) {
      const test = line ? line+' '+w : w;
      try {
        if (font.widthOfTextAtSize(test, size) > maxWidth && line) {
          lines.push(line); line = w;
        } else line = test;
      } catch(_) { line = test; }
    }
    if (line) lines.push(line);
    for (const l of lines) {
      checkY(size + 6);
      pg.drawText(l, { x, y, size, font, color });
      y -= size + 4;
    }
  }

  function h1(text) {
    checkY(44);
    y -= 8;
    pg.drawRectangle({ x:ML, y:y-2, width:CW, height:24, color:AZUL });
    pg.drawText(safe(text), { x:ML+8, y:y+4, size:13, font:hvB, color:BLANCO });
    y -= 30;
  }

  function h2(text) {
    checkY(34);
    y -= 4;
    pg.drawLine({ start:{x:ML,y:y+2}, end:{x:MR,y:y+2}, thickness:1, color:AZUL });
    pg.drawText(safe(text), { x:ML, y:y-12, size:11, font:hvB, color:AZUL_OS });
    y -= 22;
  }

  function bul(text, level) {
    const indent = ML + (level||0)*14;
    checkY(14);
    pg.drawText('-', { x:indent, y, size:10, font:hvB, color:AZUL });
    txt(text, { x:indent+10, size:9.5, maxWidth:CW - (indent-ML) - 10 });
  }

  function tblHead(cols) {
    checkY(22);
    let cx = ML;
    pg.drawRectangle({ x:ML, y:y-4, width:CW, height:18, color:AZUL_OS });
    for (const [lbl, w] of cols) {
      pg.drawText(safe(lbl), { x:cx+4, y:y+2, size:8, font:hvB, color:BLANCO });
      cx += w;
    }
    y -= 18;
  }

  function tblRow(cells, cols, shade) {
    checkY(18);
    let cx = ML;
    if (shade) pg.drawRectangle({ x:ML, y:y-4, width:CW, height:16, color:GRIS_CL });
    for (let i=0; i<cells.length; i++) {
      const w = cols[i][1];
      const s = safe(String(cells[i]));
      const cap = s.length > 55 ? s.substring(0,52)+'...' : s;
      pg.drawText(cap, { x:cx+4, y, size:8, font:hv, color:NEGRO });
      cx += w;
    }
    y -= 16;
  }

  function statusPill(status, x, yy) {
    const c = status==='Correcto' ? VERDE
            : status==='Parcial'  ? NARANJA
            : status==='Riesgo'   ? ROJO
            : GRIS;
    const sw = hvB.widthOfTextAtSize(safe(status), 7) + 10;
    pg.drawRectangle({ x, y:yy-3, width:sw, height:13, color:c, borderRadius:3 });
    pg.drawText(safe(status), { x:x+5, y:yy, size:7, font:hvB, color:BLANCO });
  }

  // ──────────────────────────────────────────────
  // PORTADA
  // ──────────────────────────────────────────────
  pg = doc.addPage([W, H]);
  y  = H;

  pg.drawRectangle({ x:0, y:H-180, width:W, height:180, color:AZUL });
  pg.drawRectangle({ x:0, y:H-183, width:W, height:4,   color:NARANJA });

  pg.drawText('AUDITORIA TECNICA', { x:ML, y:H-75, size:28, font:hvB, color:BLANCO });
  pg.drawText('Modulo de Plantillas PDF', { x:ML, y:H-112, size:18, font:hv, color:rgb(0.8,0.88,1) });
  pg.drawText('Fluix Business Platform', { x:ML, y:H-138, size:13, font:hvI, color:rgb(0.75,0.82,0.95) });

  const mY = H - 240;
  pg.drawRectangle({ x:ML, y:mY-62, width:CW, height:90, color:GRIS_CL, borderRadius:8 });
  pg.drawText('Fecha de auditoria', { x:ML+16, y:mY-10, size:9, font:hvB, color:GRIS });
  pg.drawText(safe(FECHA),          { x:ML+16, y:mY-24, size:11, font:hvB, color:NEGRO });
  pg.drawText('Alcance', { x:ML+16, y:mY-44, size:9, font:hvB, color:GRIS });
  pg.drawText('Flutter/Dart - Firebase/Firestore - Cloud Functions - Storage',
    { x:ML+16, y:mY-58, size:10, font:hv, color:NEGRO });

  const rY = mY - 110;
  pg.drawRectangle({ x:ML, y:rY-92, width:CW, height:102, color:rgb(0.99,0.96,0.96), borderRadius:8 });
  pg.drawLine({ start:{x:ML,y:rY-92}, end:{x:ML,y:rY+10}, thickness:5, color:ROJO });
  pg.drawText('RESUMEN EJECUTIVO', { x:ML+14, y:rY-8, size:10, font:hvB, color:ROJO });
  pg.drawText('El modulo de Plantillas PDF de Fluix NO garantiza que la plantilla seleccionada',
    { x:ML+14, y:rY-25, size:9.5, font:hv, color:NEGRO });
  pg.drawText('por una empresa se aplique al documento final generado.',
    { x:ML+14, y:rY-39, size:9.5, font:hv, color:NEGRO });
  pg.drawText('El motor dinamico (PdfRenderer) esta roto: PdfBlockRegistry nunca se inicializa.',
    { x:ML+14, y:rY-53, size:9.5, font:hv, color:NEGRO });
  pg.drawText('Los tickets y facturas TPV ignoran completamente las plantillas.',
    { x:ML+14, y:rY-67, size:9.5, font:hv, color:NEGRO });
  pg.drawText('Veredicto: RIESGO ALTO - No apto para produccion sin correcciones.',
    { x:ML+14, y:rY-83, size:9.5, font:hvB, color:ROJO });

  pg.drawLine({ start:{x:ML,y:36}, end:{x:MR,y:36}, thickness:0.5, color:GRIS });
  pg.drawText('CONFIDENCIAL | ' + FECHA + ' | Generado por Claude Code',
    { x:ML, y:22, size:7, font:hv, color:GRIS });

  // ──────────────────────────────────────────────
  // SEC 1 — INVENTARIO
  // ──────────────────────────────────────────────
  newPage();
  h1('1. INVENTARIO DE PLANTILLAS');

  h2('1.1 Plantillas definidas en codigo');
  txt('19 plantillas estaticas embebidas en:');
  txt('lib/features/pdf_templates/domain/models/pdf_template.dart', { font:hvB });
  y -= 6;

  const iC = [['Tipo de documento',160],['Default',60],['Galeria',60],['Total',50],['Estado',80]];
  tblHead(iC);
  [['Factura','1','6','7','Activa'],
   ['Factura Rectificativa','1','1','2','Activa'],
   ['Proforma','1','2','3','Activa'],
   ['Presupuesto','1','1','2','Activa'],
   ['Albaran','1','0','1','Activa'],
   ['Fichajes','1','0','1','Activa'],
   ['Horas Empleado','1','0','1','Activa'],
   ['Informe Interno','1','0','1','Activa'],
  ].forEach((r,i) => tblRow(r,iC,i%2===0));
  y -= 8;

  h2('1.2 Colecciones Firestore (dos sistemas incompatibles)');
  bul('NUEVO: coleccion raiz pdf_templates (campo empresa_id para filtrar)');
  bul('ANTIGUO: empresas/{id}/pdf_templates (subcol - sin reglas Firestore activas)');
  bul('CONFIG asignacion (legado): empresas/{id}/pdf_config/config');
  bul('SISTEMA GLOBAL (legado): pdf_template_system - sin reglas definidas');

  h2('1.3 Plantilla por defecto');
  txt('getPlantillaDefault() busca en pdf_templates donde es_default=true AND tipo=X.');
  txt('Si no existe, devuelve null y se usan colores hardcodeados #1565C0.');

  // ──────────────────────────────────────────────
  // SEC 2 — FUNCIONAMIENTO
  // ──────────────────────────────────────────────
  h1('2. FLUJO DE GENERACION - COMO FUNCIONA REALMENTE');

  h2('2.1 Flujo UI (seleccion y gestion de plantillas)');
  bul('PdfTemplatesListScreen => PdfTemplateService.watchTodasPlantillas()');
  bul('Lee coleccion raiz pdf_templates where empresa_id == X');
  bul('"Usar plantilla galeria" => crearPlantilla() => guarda en pdf_templates (raiz)');
  bul('"Marcar como default" => establecerComoDefault() => actualiza campo es_default');
  bul('Preview: PdfService.generarPreviewBytes() => PDF de muestra con datos ficticios');
  y -= 6;

  h2('2.2 Flujo generacion factura REAL (produccion)');
  bul('generarFacturaPdfConDatos(factura, empresaId)  [pdf_service.dart:933]');
  bul('=> uiTplSvc.getPlantillaDefault(empresaId, tipo)  [extrae SOLO 2 colores]', 1);
  bul('=> _generarPdfBytes() con layout 100% HARDCODEADO  [pdf_service.dart:208]', 1);
  bul('=> PDF con diseno fijo; colores del template si existen, sino #1565C0', 1);
  y -= 6;

  h2('2.3 Motor dinamico (definido pero no funcional)');
  bul('generarFacturaPdfDinamico() - NO se invoca desde la UI');
  bul('=> PdfTemplateService (VIEJO) => lee empresas/{id}/pdf_config + subcol', 1);
  bul('=> PdfRenderer.render() => PdfBlockRegistry VACIO (initialize() no se llama)', 1);
  bul('=> Todos los bloques: texto "Bloque no disponible"', 1);
  bul('=> catch => fallback a generarFacturaPdfConDatos()', 1);

  // ──────────────────────────────────────────────
  // SEC 3 — ANALISIS POR DOCUMENTO
  // ──────────────────────────────────────────────
  newPage();
  h1('3. ANALISIS POR TIPO DE DOCUMENTO');

  const dC = [['Documento',130],['Generador',155],['Usa plantilla',80],['Tipo de fallo',130]];
  tblHead(dC);
  [['Factura','generarFacturaPdfConDatos()','Solo 2 colores','Layout hardcodeado'],
   ['Fact. rectificativa','generarFacturaPdfConDatos()','No','Color #D32F2F fijo'],
   ['Proforma','generarFacturaPdfConDatos()','Solo 2 colores','Layout hardcodeado'],
   ['Presupuesto','Sin generador propio','No','No implementado'],
   ['Ticket TPV','TpvDocumentRenderer','No','_obtenerPlantilla no invocada'],
   ['Fact. simplif. TPV','TpvDocumentRenderer','No','_obtenerPlantilla no invocada'],
   ['Fact. completa TPV','TpvDocumentRenderer','No','_obtenerPlantilla no invocada'],
   ['Nomina','nomina_pdf_service.dart','No','Servicio autonomo'],
   ['Finiquito','finiquito_pdf_service.dart','No','Servicio autonomo'],
   ['Modelo 111','modelo111_pdf_service.dart','No','Servicio autonomo'],
   ['Inf. fichajes','generarPreviewBytes()','Solo preview','Sin generacion real'],
  ].forEach((r,i) => tblRow(r,dC,i%2===0));
  y -= 10;

  h2('3.1 Problemas criticos localizados');
  txt('lib/services/pdf_service.dart lineas 950-965:');
  bul('getPlantillaDefault() extrae SOLO colorPrimario y colorSecundario.', 1);
  bul('Bloques, margenes, tipografia y estructura se descartan completamente.', 1);
  y -= 4;
  txt('lib/services/tpv/tpv_document_renderer.dart lineas 658-682:');
  bul('_obtenerPlantilla() definida pero NUNCA invocada en renderizarDocumento().', 1);
  bul('IDs de plantilla guardados en config pero nunca leidos al generar PDF.', 1);
  y -= 4;
  txt('lib/services/pdf/pdf_block_registry.dart linea 22:');
  bul('initialize() existe pero nunca se llama.', 1);
  bul('PdfRenderer trabaja con registry vacio => todos los bloques fallan.', 1);

  // ──────────────────────────────────────────────
  // SEC 4 — FALLBACKS
  // ──────────────────────────────────────────────
  h1('4. FALLBACKS Y MANEJO DE ERRORES');

  const fC = [['Escenario',190],['Comportamiento',185],['Visible para usuario',120]];
  tblHead(fC);
  [['Sin plantilla default','Colores hardcodeados #1565C0','No - silencioso'],
   ['Plantilla eliminada','getPlantillaDefault() => null => colores default','No - silencioso'],
   ['Plantilla desactivada','No filtrada correctamente','No - silencioso'],
   ['Error red Firestore','catch silencioso => colores default','No - silencioso'],
   ['Motor dinamico falla','catch => fallback a legacy','No - silencioso'],
   ['PdfBlockRegistry vacio','Texto "Bloque no disponible" en PDF','Solo si se usa el motor'],
  ].forEach((r,i) => tblRow(r,fC,i%2===0));

  // ──────────────────────────────────────────────
  // SEC 5 — MULTIEMPRESA
  // ──────────────────────────────────────────────
  newPage();
  h1('5. SEGURIDAD MULTIEMPRESA');

  h2('5.1 Reglas Firestore para pdf_templates (firestore.rules:1463-1503)');
  const sC = [['Operacion',100],['Valida empresa_id',130],['Estado',75],['Riesgo',190]];
  tblHead(sC);
  [['get','Si (resource.data)','Correcto','Sin riesgo'],
   ['create','Si (request.resource.data)','Correcto','Sin riesgo'],
   ['update','Si (resource.data)','Correcto','Sin riesgo'],
   ['delete','Si (resource.data)','Correcto','Sin riesgo'],
   ['list','NO valida empresa_id','Riesgo','Admin puede listar plantillas ajenas'],
  ].forEach((r,i) => tblRow(r,sC,i%2===0));
  y -= 8;
  txt('El cliente Flutter filtra por empresa_id, pero Firestore no lo impone en la regla list.');
  txt('Un admin autenticado malicioso podria omitir el filtro y listar plantillas de otras empresas.');
  y -= 6;

  h2('5.2 Subcol antigua: empresas/{id}/pdf_templates');
  bul('Sin reglas Firestore especificas => cae en catch-all: allow read, write: if false');
  bul('El servicio antiguo (lib/services/pdf/pdf_template_service.dart) siempre falla');
  y -= 6;

  h2('5.3 Coleccion pdf_template_system');
  bul('Referenciada en getSystemTemplate() del servicio antiguo');
  bul('Sin reglas => catch-all la deniega => codigo muerto en la practica');

  // ──────────────────────────────────────────────
  // SEC 6 — TRAZABILIDAD
  // ──────────────────────────────────────────────
  h1('6. TRAZABILIDAD Y VERSIONADO');

  bul('No existe versionado. actualizarPlantilla() sobreescribe sin historial.');
  bul('Los documentos en empresas/{id}/facturas NO almacenan el ID de plantilla usada.');
  bul('No hay registro de que plantilla genero cada PDF.');
  bul('Los PDFs generados no se almacenan en Firebase Storage por defecto.');
  bul('Si cambia la plantilla, no se puede reproducir el PDF original.');
  bul('Riesgo legal: en auditorias fiscales no se puede re-generar la factura con su diseno original.');

  // ──────────────────────────────────────────────
  // SEC 7 — TABLA DE FIABILIDAD
  // ──────────────────────────────────────────────
  newPage();
  h1('7. TABLA DE FIABILIDAD');

  // Headers manuales para tabla con pills
  checkY(22);
  pg.drawRectangle({ x:ML, y:y-4, width:CW, height:18, color:AZUL_OS });
  pg.drawText('Area',           { x:ML+4,    y:y+2, size:8, font:hvB, color:BLANCO });
  pg.drawText('Estado',         { x:ML+134,  y:y+2, size:8, font:hvB, color:BLANCO });
  pg.drawText('Problema encontrado', { x:ML+226, y:y+2, size:8, font:hvB, color:BLANCO });
  y -= 18;

  const filas = [
    ['Seleccion',      'Parcial',          'UI funciona; solo 2 colores llegan al PDF real'],
    ['Persistencia',   'Riesgo',           'Dos colecciones incompatibles; antigua bloqueada'],
    ['Generacion PDF', 'Riesgo',           'Motor dinamico roto (PdfBlockRegistry vacio)'],
    ['Facturas',       'Parcial',          'Solo 2 colores; layout hardcodeado siempre'],
    ['Rectificativas', 'No implementado',  'Color #D32F2F fijo, ignora cualquier plantilla'],
    ['Tickets TPV',    'No implementado',  '_obtenerPlantilla() definida pero nunca invocada'],
    ['Presupuestos',   'No implementado',  'Sin generador PDF propio con soporte plantillas'],
    ['Multiempresa',   'Parcial',          'list sin validar empresa_id; get/write correctos'],
    ['Versionado',     'No implementado',  'Sin historial ni referencia en documentos'],
    ['Errores/Fallbacks','Riesgo',         'Todos los errores son silenciosos al usuario'],
    ['Seguridad',      'Parcial',          'pdf_template_system sin reglas; list sin validar'],
  ];

  filas.forEach((r, i) => {
    checkY(22);
    if (i%2===0) pg.drawRectangle({ x:ML, y:y-4, width:CW, height:18, color:GRIS_CL });
    pg.drawText(safe(r[0]), { x:ML+4, y, size:9, font:hv, color:NEGRO });
    statusPill(r[1], ML+132, y);
    const s = safe(r[2]);
    pg.drawText(s.length>62 ? s.substring(0,59)+'...' : s,
      { x:ML+226, y, size:8, font:hv, color:NEGRO });
    y -= 18;
  });

  // ──────────────────────────────────────────────
  // SEC 8 — RIESGOS CRITICOS
  // ──────────────────────────────────────────────
  y -= 16;
  h1('8. RIESGOS CRITICOS');

  function riskBox(num, title, loc, lines, sev) {
    const boxH = 22 + lines.length * 13 + 20;
    checkY(boxH + 16);
    const c = sev==='CRITICO' ? ROJO : sev==='ALTO' ? NARANJA : GRIS;
    pg.drawRectangle({ x:ML, y:y-boxH, width:CW, height:boxH+10, color:rgb(0.98,0.98,1), borderRadius:6 });
    pg.drawLine({ start:{x:ML,y:y-boxH}, end:{x:ML,y:y+10}, thickness:5, color:c });
    const sw = hvB.widthOfTextAtSize(safe(sev), 8)+10;
    pg.drawRectangle({ x:ML+10, y:y-1, width:sw, height:14, color:c, borderRadius:3 });
    pg.drawText(safe(sev), { x:ML+15, y:y+1, size:8, font:hvB, color:BLANCO });
    pg.drawText('RIESGO '+num, { x:ML+sw+18, y:y+1, size:9, font:hvB, color:NEGRO });
    pg.drawText(safe(title), { x:ML+12, y:y-16, size:10, font:hvB, color:NEGRO });
    pg.drawText(safe('Archivo: '+loc), { x:ML+12, y:y-30, size:8, font:hvI, color:GRIS });
    let ly = y - 44;
    for (const l of lines) {
      pg.drawText(safe(l), { x:ML+12, y:ly, size:9, font:hv, color:NEGRO });
      ly -= 13;
    }
    y -= boxH + 20;
  }

  riskBox('1',
    'Motor dinamico completamente roto',
    'lib/services/pdf/pdf_block_registry.dart:22 | pdf_renderer.dart:10',
    ['PdfBlockRegistry.initialize() nunca se llama en ningun punto del ciclo de vida.',
     'PdfRenderer.render() falla en todos los bloques: "Bloque no disponible".',
     'El sistema de renderizado dinamico es completamente inoperativo.'],
    'CRITICO');

  riskBox('2',
    'Plantillas no aplican layout, solo 2 colores',
    'lib/services/pdf_service.dart:950-965 | _generarPdfBytes:208',
    ['generarFacturaPdfConDatos() extrae SOLO colorPrimario y colorSecundario.',
     'Bloques, margenes, tipografia y estructura configurados en la plantilla se descartan.',
     'El PDF siempre usa el mismo layout hardcodeado independientemente del template.'],
    'CRITICO');

  riskBox('3',
    'TPV ignora completamente las plantillas',
    'lib/services/tpv/tpv_document_renderer.dart:658',
    ['_obtenerPlantilla() esta definida pero NUNCA se invoca en renderizarDocumento().',
     'Los IDs de plantilla (plantillaIdFactura, plantillaIdTicket) se guardan en config',
     'pero nunca se leen al generar el PDF del pedido TPV.'],
    'CRITICO');

  riskBox('4',
    'Regla list sin validar empresa_id en Firestore',
    'firestore.rules:1465-1471',
    ['La regla list de /pdf_templates no valida resource.data.empresa_id.',
     'Un admin autenticado podria listar plantillas de otras empresas omitiendo el filtro.'],
    'ALTO');

  riskBox('5',
    'Dos sistemas de plantillas incompatibles coexisten',
    'lib/domain/modelos/pdf_template.dart vs lib/features/pdf_templates/domain/models/',
    ['Dos modelos PdfTemplate con schemas distintos, dos servicios que leen colecciones distintas.',
     'La coleccion antigua (subcol) esta bloqueada por el catch-all de reglas Firestore.',
     'Codigo fragmentado, duplicado y propenso a regresiones.'],
    'ALTO');

  // ──────────────────────────────────────────────
  // SEC 9 — CONCLUSION
  // ──────────────────────────────────────────────
  newPage();
  h1('9. CONCLUSION FINAL');

  // Caja veredicto
  checkY(90);
  pg.drawRectangle({ x:ML, y:y-72, width:CW, height:82, color:rgb(1,0.95,0.95), borderRadius:8 });
  pg.drawLine({ start:{x:ML,y:y-72}, end:{x:ML,y:y+10}, thickness:6, color:ROJO });
  pg.drawText('VEREDICTO', { x:ML+14, y:y-8, size:11, font:hvB, color:ROJO });
  pg.drawText('NO - En el estado actual, seleccionar una plantilla NO garantiza',
    { x:ML+14, y:y-25, size:10, font:hv, color:NEGRO });
  pg.drawText('que los documentos se generen con ella. El sistema es decorativo,',
    { x:ML+14, y:y-39, size:10, font:hv, color:NEGRO });
  pg.drawText('no funcional. Solo se aplican 2 colores del template seleccionado.',
    { x:ML+14, y:y-53, size:10, font:hv, color:NEGRO });
  pg.drawText('Ningun otro aspecto del diseno configurable llega al documento final.',
    { x:ML+14, y:y-67, size:10, font:hvB, color:ROJO });
  y -= 90;

  h2('9.1 Lo que SI funciona');
  bul('La UI de gestion (listado, creacion, edicion, galeria) funciona correctamente');
  bul('Las previsualizaciones en tarjetas son fieles a la plantilla seleccionada');
  bul('El aislamiento por empresa en operaciones individuales (get/write) es correcto');
  bul('Los colores primario y secundario del template default si llegan a facturas');
  y -= 8;

  h2('9.2 Lo que NO funciona');
  bul('El motor dinamico PdfRenderer esta roto (PdfBlockRegistry sin inicializar)');
  bul('El layout/bloques del template nunca se aplican en documentos reales');
  bul('Los tickets y facturas TPV ignoran completamente las plantillas configuradas');
  bul('Las rectificativas, presupuestos, nominas y finiquitos no soportan plantillas');
  bul('No existe versionado ni trazabilidad de plantilla-documento');

  // ──────────────────────────────────────────────
  // SEC 10 — RECOMENDACIONES
  // ──────────────────────────────────────────────
  h1('10. RECOMENDACIONES DE CORRECCION');

  h2('Prioridad INMEDIATA (antes de produccion)');
  bul('R1: Llamar PdfBlockRegistry.initialize() en main.dart o en PdfRenderer constructor');
  bul('    Archivo: lib/services/pdf/pdf_block_registry.dart:22', 1);
  bul('R2: Conectar _obtenerPlantilla() en TpvDocumentRenderer.renderizarDocumento()');
  bul('    Aplicar colores y bloques del template al PDF A4 del TPV', 1);
  bul('R3: Decidir arquitectura unica: eliminar sistema antiguo o migrar al nuevo');
  bul('    Borrar lib/services/pdf/pdf_template_service.dart (servicio legado)', 1);
  bul('    Borrar lib/domain/modelos/pdf_template.dart (modelo legado)', 1);
  y -= 6;

  h2('Prioridad ALTA (sprint siguiente)');
  bul('R4: Refactorizar generarFacturaPdfConDatos() para respetar bloques del template');
  bul('    Sustituir layout hardcodeado por motor de bloques dinamico', 1);
  bul('R5: Fijar regla Firestore list para pdf_templates con validacion de empresa_id');
  bul('R6: Implementar generador PDF para presupuestos y albaranes con soporte plantillas');
  y -= 6;

  h2('Prioridad MEDIA (Q4 2026)');
  bul('R7: Implementar versionado de plantillas (historial de revisiones)');
  bul('R8: Guardar referencia de plantillaId en cada documento generado en Firestore');
  bul('R9: Almacenar PDFs en Firebase Storage para garantizar reproducibilidad legal');
  bul('R10: Extender soporte de plantillas a nominas, finiquitos y modelos fiscales');

  // firma
  y -= 20;
  checkY(30);
  pg.drawLine({ start:{x:ML,y:y}, end:{x:MR,y:y}, thickness:1, color:AZUL });
  y -= 14;
  pg.drawText('Auditoria generada el ' + FECHA + ' por Claude Code | Anthropic',
    { x:ML, y, size:8, font:hvI, color:GRIS });
  y -= 12;
  pg.drawText('Alcance: codigo fuente local. No incluye inspeccion de datos en produccion Firestore.',
    { x:ML, y, size:8, font:hv, color:GRIS });

  // ──────────────────────────────────────────────
  const bytes = await doc.save();
  fs.writeFileSync(OUT, bytes);
  console.log('PDF generado: ' + OUT);
}

run().catch(err => { console.error(err); process.exit(1); });

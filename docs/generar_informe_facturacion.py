# -*- coding: utf-8 -*-
"""
Genera el informe PDF: Situación legal del módulo de facturación — Fluix/PlaneaG
Ejecutar: python docs/generar_informe_facturacion.py
Salida:   docs/informe_facturacion_legal.pdf
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm
from reportlab.lib.colors import (
    HexColor, white, black, Color
)
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, KeepTogether, PageBreak
)
from reportlab.platypus.flowables import BalancedColumns
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT, TA_JUSTIFY
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import os, sys

# ── COLORES CORPORATIVOS ────────────────────────────────────────────────────
C_AZUL         = HexColor('#1565C0')
C_AZUL_OSC     = HexColor('#0D47A1')
C_AZUL_CLARO   = HexColor('#E3F2FD')
C_VERDE        = HexColor('#2E7D32')
C_VERDE_CLARO  = HexColor('#E8F5E9')
C_ROJO         = HexColor('#C62828')
C_ROJO_CLARO   = HexColor('#FFEBEE')
C_NARANJA      = HexColor('#E65100')
C_NARANJA_CLARO= HexColor('#FFF3E0')
C_GRIS         = HexColor('#455A64')
C_GRIS_CLARO   = HexColor('#ECEFF1')
C_GRIS_MUY_CLARO = HexColor('#F5F7FA')
C_AMARILLO_CLARO = HexColor('#FFFDE7')
C_TEXTO        = HexColor('#212121')

W = A4[0]

# ── ESTILOS ─────────────────────────────────────────────────────────────────
SS = getSampleStyleSheet()

def estilo(name, parent='Normal', **kw):
    s = ParagraphStyle(name, parent=SS[parent], **kw)
    return s

TITULO_PORTADA = estilo('TituloPortada', fontSize=28, textColor=white,
                         fontName='Helvetica-Bold', leading=34, alignment=TA_CENTER)
SUBTITULO_PORTADA = estilo('SubtituloPortada', fontSize=14, textColor=HexColor('#BBDEFB'),
                            fontName='Helvetica', leading=20, alignment=TA_CENTER)
SUBTITULO2_PORTADA = estilo('Subtitulo2Portada', fontSize=11, textColor=HexColor('#90CAF9'),
                             fontName='Helvetica', leading=16, alignment=TA_CENTER)

H1 = estilo('H1', fontSize=17, textColor=C_AZUL_OSC, fontName='Helvetica-Bold',
            leading=22, spaceBefore=18, spaceAfter=8,
            borderPad=6)
H2 = estilo('H2', fontSize=13, textColor=C_AZUL, fontName='Helvetica-Bold',
            leading=17, spaceBefore=14, spaceAfter=5)
H3 = estilo('H3', fontSize=11, textColor=C_GRIS, fontName='Helvetica-Bold',
            leading=14, spaceBefore=10, spaceAfter=4)

BODY = estilo('Body', fontSize=9.5, textColor=C_TEXTO, fontName='Helvetica',
              leading=14, spaceAfter=5)
BODY_J = estilo('BodyJ', fontSize=9.5, textColor=C_TEXTO, fontName='Helvetica',
                leading=14, spaceAfter=5, alignment=TA_JUSTIFY)
SMALL = estilo('Small', fontSize=8, textColor=C_GRIS, fontName='Helvetica',
               leading=11, spaceAfter=3)
CODE = estilo('Code', fontSize=8, textColor=HexColor('#1A237E'), fontName='Courier',
              leading=12, backColor=HexColor('#EEF2FF'), borderPad=3,
              leftIndent=8, rightIndent=8, spaceAfter=4)
BULLET = estilo('Bullet', fontSize=9.5, textColor=C_TEXTO, fontName='Helvetica',
                leading=14, leftIndent=12, spaceAfter=3,
                bulletIndent=4, bulletFontName='Helvetica', bulletFontSize=9.5)
NOTA  = estilo('Nota', fontSize=8.5, textColor=HexColor('#37474F'), fontName='Helvetica-Oblique',
               leading=12, leftIndent=8, spaceAfter=3)

CRITICO_LBL = estilo('CriticoLbl', fontSize=9, textColor=C_ROJO, fontName='Helvetica-Bold',
                     leading=12)
MEDIO_LBL   = estilo('MedioLbl', fontSize=9, textColor=C_NARANJA, fontName='Helvetica-Bold',
                     leading=12)
BAJO_LBL    = estilo('BajoLbl', fontSize=9, textColor=C_VERDE, fontName='Helvetica-Bold',
                     leading=12)
OK_LBL      = estilo('OkLbl', fontSize=9, textColor=C_VERDE, fontName='Helvetica-Bold',
                     leading=12)

def p(text, style=BODY):
    return Paragraph(text, style)

def pb(text):
    return Paragraph(f'• {text}', BULLET)

def sp(n=8):
    return Spacer(1, n)

def hr(color=C_GRIS_CLARO, thickness=0.5):
    return HRFlowable(width='100%', thickness=thickness, color=color,
                      spaceAfter=4, spaceBefore=4)

def tabla_simple(data, col_widths, style_extra=None):
    ts = TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_AZUL_OSC),
        ('TEXTCOLOR',  (0,0), (-1,0), white),
        ('FONTNAME',   (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE',   (0,0), (-1,0), 8.5),
        ('ALIGN',      (0,0), (-1,0), 'CENTER'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [white, C_GRIS_MUY_CLARO]),
        ('FONTNAME',   (0,1), (-1,-1), 'Helvetica'),
        ('FONTSIZE',   (0,1), (-1,-1), 8),
        ('TEXTCOLOR',  (0,1), (-1,-1), C_TEXTO),
        ('GRID',       (0,0), (-1,-1), 0.3, C_GRIS_CLARO),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
        ('VALIGN',     (0,0), (-1,-1), 'MIDDLE'),
    ])
    if style_extra:
        ts.add(*style_extra) if isinstance(style_extra[0], str) else [ts.add(*s) for s in style_extra]
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(ts)
    return t

def caja_coloreada(items_paragraphs, bg_color, border_color, title=None, title_color=None):
    """Caja coloreada con lista de párrafos dentro."""
    inner = []
    if title:
        tc = title_color or border_color
        inner.append(Paragraph(f'<b><font color="#{tc.hexval()}">{title}</font></b>', H3))
    inner.extend(items_paragraphs)
    data = [[inner]]
    ts = TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), bg_color),
        ('BOX',        (0,0), (-1,-1), 1.2, border_color),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('VALIGN',     (0,0), (-1,-1), 'TOP'),
    ])
    t = Table(data, colWidths=[W - 4*cm])
    t.setStyle(ts)
    return t

# ── HEADER / FOOTER ──────────────────────────────────────────────────────────
def _header_footer(canvas, doc):
    canvas.saveState()
    # Footer
    canvas.setFillColor(C_GRIS)
    canvas.setFont('Helvetica', 7.5)
    canvas.drawString(2*cm, 1.2*cm,
        'Fluix/PlaneaG — Informe de cumplimiento normativo facturación — Confidencial')
    canvas.drawRightString(A4[0]-2*cm, 1.2*cm, f'Página {doc.page}')
    canvas.setStrokeColor(C_GRIS_CLARO)
    canvas.setLineWidth(0.4)
    canvas.line(2*cm, 1.6*cm, A4[0]-2*cm, 1.6*cm)
    # Header (desde pág 2)
    if doc.page > 1:
        canvas.setFillColor(C_AZUL)
        canvas.setFont('Helvetica-Bold', 8)
        canvas.drawString(2*cm, A4[1]-1.4*cm,
            'Módulo de Facturación · Situación Legal y Operativa')
        canvas.setStrokeColor(C_AZUL_CLARO)
        canvas.setLineWidth(0.6)
        canvas.line(2*cm, A4[1]-1.7*cm, A4[0]-2*cm, A4[1]-1.7*cm)
    canvas.restoreState()

# ── PORTADA ──────────────────────────────────────────────────────────────────
def portada():
    items = []
    # Fondo azul simulado con tabla
    portada_data = [[
        Paragraph('<b>FLUIX / PLANEAG</b>', SUBTITULO_PORTADA),
    ],[
        Paragraph(
            'Módulo de Facturación<br/>Situación Legal y Operativa',
            TITULO_PORTADA,
        ),
    ],[
        Paragraph(
            'Alcance: Facturación · TPV · Contabilidad · Modelos Fiscales · Verifactu',
            SUBTITULO2_PORTADA,
        ),
    ],[
        Paragraph(
            'Octubre 2026 · Versión 1.0 · Uso interno — Confidencial',
            SUBTITULO2_PORTADA,
        ),
    ]]
    ts = TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), C_AZUL_OSC),
        ('TOPPADDING', (0,0), (-1,-1), 14),
        ('BOTTOMPADDING', (0,0), (-1,-1), 14),
        ('LEFTPADDING', (0,0), (-1,-1), 20),
        ('RIGHTPADDING', (0,0), (-1,-1), 20),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('TOPPADDING', (0,0), (0,0), 40),
        ('BOTTOMPADDING', (0,-1), (-1,-1), 40),
    ])
    t = Table(portada_data, colWidths=[W - 4*cm])
    t.setStyle(ts)
    items.append(t)
    items.append(sp(20))

    # Tabla de versión / contacto
    meta = [
        ['Documento', 'Informe de cumplimiento normativo — Facturación'],
        ['Versión', '1.0'],
        ['Fecha', 'Octubre 2026'],
        ['Ámbito', 'Flutter app + Cloud Functions'],
        ['Normativa', 'RD 1619/2012 · Ley 37/1992 · LGT 58/2003 · RD 1007/2023'],
        ['Clasificación', 'Confidencial — Uso interno'],
    ]
    ts2 = TableStyle([
        ('FONTNAME',  (0,0), (0,-1), 'Helvetica-Bold'),
        ('FONTSIZE',  (0,0), (-1,-1), 9),
        ('TEXTCOLOR', (0,0), (0,-1), C_AZUL),
        ('TEXTCOLOR', (1,0), (1,-1), C_TEXTO),
        ('GRID', (0,0), (-1,-1), 0.3, C_GRIS_CLARO),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [white, C_GRIS_MUY_CLARO]),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
    ])
    t2 = Table(meta, colWidths=[4.5*cm, W - 4*cm - 4.5*cm])
    t2.setStyle(ts2)
    items.append(t2)
    items.append(PageBreak())
    return items

# ── ÍNDICE ────────────────────────────────────────────────────────────────────
def indice():
    items = [p('ÍNDICE DE CONTENIDOS', H1), hr(C_AZUL, 1.5)]
    secciones = [
        ('1.', 'Marco normativo aplicable'),
        ('2.', 'Arquitectura del módulo de facturación'),
        ('3.', 'Flujos de facturación y documentos fiscales'),
        ('4.', 'Módulo TPV: integración con facturación'),
        ('5.', 'Otras pantallas que usan el servicio de facturación'),
        ('6.', 'Verifactu: estado de implementación'),
        ('7.', 'Modelos fiscales AEAT: estado de implementación'),
        ('8.', 'Auditoría de cumplimiento: hallazgos'),
        ('9.', 'Mapa de riesgos por pantalla/flujo'),
        ('10.', 'Plan de corrección priorizado'),
    ]
    for num, titulo in secciones:
        items.append(Paragraph(
            f'<font color="#1565C0"><b>{num}</b></font>  {titulo}',
            estilo(f'idx_{num}', fontSize=10, leading=18, leftIndent=8)
        ))
    items.append(PageBreak())
    return items

# ── SECCIÓN 1: MARCO NORMATIVO ────────────────────────────────────────────────
def seccion_normativa():
    items = [p('1. MARCO NORMATIVO APLICABLE', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'El módulo de facturación de Fluix opera bajo el siguiente marco normativo español '
        'vigente a octubre de 2026. Todo el código del módulo debe cumplir simultáneamente '
        'con estas normas.', BODY_J))
    items.append(sp(8))

    normas = [
        ['Norma', 'Ámbito', 'Artículos clave para la app'],
        ['RD 1619/2012\nReglamento de Facturación',
         'Contenido obligatorio de facturas\ncompletas y simplificadas.\nFacturas rectificativas.',
         'Art. 6: campos obligatorios factura completa\nArt. 7: factura simplificada (límite 400 €)\nArt. 15: rectificativas (motivo + método)\nArt. 9: facturas electrónicas'],
        ['Ley 37/1992 — LIVA',
         'IVA: tipos impositivos,\nbase imponible, devengo,\noperaciones exentas.',
         'Art. 90-91: tipos (4%/10%/21%/0%)\nArt. 80: rectificación base imponible\nArt. 97: requisitos formales\nArt. 154: recargo de equivalencia'],
        ['LGT 58/2003',
         'Obligaciones formales,\nconservación, sanciones.',
         'Art. 29.2.j: sistemas informáticos\nArt. 66: prescripción tributaria (4 años)\nArt. 201bis: infractores sistemas'],
        ['RD 1007/2023 — Verifactu',
         'Registro fiscal electrónico\nde operaciones de venta.',
         'Art. 10: timestamp (60 s para XML)\nArt. 8: inalterabilidad hash chain\nAnexo I: estructura XML\nAnexo II: QR en factura'],
        ['Orden HAC/1177/2024',
         'Desarrollo técnico Verifactu:\ncódigos R1-R5, F1/F2,\nespecificaciones AEAT.',
         'Tipos factura: F1/F2/R1-R5\nCódigos motivo rectificación\nFormato hash SHA-256'],
        ['RD 254/2025',
         'Obligatoriedad Verifactu\ny calendario de implantación.',
         'Plazos obligatoriedad por tipo empresa\nSanciones por incumplimiento'],
        ['Art. 30 Cód. Comercio',
         'Conservación documentos\nmercantiles.',
         '6 años desde último asiento'],
        ['Ley 18/2022 — Crea y Crece',
         'Factura electrónica B2B\nobligatoria.',
         'Obligación factura electrónica entre\nempresarios (plazos escalonados 2024-2025)'],
        ['LIRPF (Ley 35/2006)',
         'Retenciones IRPF en facturas\nde profesionales.',
         'Art. 86.2: 7% primeros 2 años\nArt. 101.3: 15% general profesional\nArt. 101.6: 19% arrendamientos'],
    ]
    t = tabla_simple(normas,
        [4*cm, 5.5*cm, W - 4*cm - 5.5*cm - 3*cm])
    items.append(t)
    items.append(sp(10))

    items.append(caja_coloreada([
        p('<b>Cambios normativos en vigor desde julio 2023 (no completamente reflejados en la app):</b>', SMALL),
        pb('IVA 0% temporal: pan, cereales, leche, queso, huevos, frutas, verduras y legumbres (R.D-ley 17/2022 prorrogado)'),
        pb('IVA 5% temporal: aceite de oliva, pasta alimenticia'),
        pb('Estas modificaciones se aplicaron de forma indefinida en la última prórroga de 2024'),
    ], C_AMARILLO_CLARO, C_NARANJA, '⚠ Tipos IVA temporales activos', C_NARANJA))
    items.append(PageBreak())
    return items

# ── SECCIÓN 2: ARQUITECTURA ───────────────────────────────────────────────────
def seccion_arquitectura():
    items = [p('2. ARQUITECTURA DEL MÓDULO DE FACTURACIÓN', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'El módulo está implementado en Flutter (Dart) con backend en Firebase Firestore '
        'y Cloud Functions (TypeScript). La siguiente tabla describe los componentes principales '
        'y su responsabilidad legal.', BODY_J))
    items.append(sp(8))

    items.append(p('2.1 Capas de la arquitectura', H2))
    capas = [
        ['Capa', 'Archivos principales', 'Responsabilidad legal'],
        ['Modelos de datos',
         'domain/modelos/factura.dart\ndomain/modelos/factura_recibida.dart\ndomain/modelos/factura_recurrente.dart',
         'Estructura de la factura según Art. 6 RD 1619/2012.\nCampos obligatorios, series, tipos IVA, IRPF, rectificativas.'],
        ['Servicio de facturación',
         'services/facturacion_service.dart',
         'CRUD de facturas. Numeración correlativa (R1).\nValidación fiscal integral. Cálculo de totales.\nCreación de rectificativas (Art. 15 RD 1619/2012).\nCriterio IVA (devengo/caja). Estadísticas 303/111.'],
        ['Validador fiscal',
         'services/validador_fiscal_integral.dart',
         'Reglas R1-R9: correlatividad, NIF, series,\ntiempo, conservación, desglose IVA.'],
        ['Generación PDF',
         'services/pdf_service.dart\nservices/tpv/tpv_document_renderer.dart',
         'Genera facturas PDF con todos los campos obligatorios.\nSoporta 9 layouts visuales + ticket térmico (80/58mm).\nIncrusta QR Verifactu. Registro de plantilla usada (R8).'],
        ['Verifactu',
         'services/verifactu_service.dart\nservices/verifactu/hash_chain_service.dart\nservices/verifactu/xml_payload_verifactu_builder.dart\nservices/verifactu/firma_xades_pkcs12_service.dart',
         'Registro electrónico AEAT (RD 1007/2023).\nHash chain SHA-256. XML XAdES-BES.\nQR de verificación en factura. Firma cualificada PKCS12.'],
        ['TPV (Punto de Venta)',
         'services/tpv_facturacion_service.dart\nservices/tpv/facturacion_automatica_service.dart',
         'Facturación por pedido o resumen diario.\nEmite ticket/factura simplificada/completa según config.\nSerie TPV separada (cumple R9).'],
        ['Facturas recurrentes',
         'services/factura_recurrente_service.dart',
         'Generación automática según período.\nSe apoya en facturacion_service para numeración y validación.'],
        ['Cloud Functions',
         'functions/src/fiscal/models/model303.ts\n... (10 modelos fiscales)',
         'Cálculo de modelos AEAT: 303, 111, 115, 347, 349, etc.\nExtracción IA de facturas recibidas (OCR + Claude API).'],
        ['Configuración fiscal',
         'features/facturacion/pantallas/\npantalla_configuracion_fiscal_empresa.dart',
         'NIF/CIF empresa, régimen IVA, criterio devengo/caja.\nFuente de verdad para datos del emisor en el PDF.'],
    ]
    t = tabla_simple(capas, [4*cm, 6.5*cm, W - 4*cm - 6.5*cm - 3*cm])
    items.append(t)
    items.append(sp(10))

    items.append(p('2.2 Base de datos — Colecciones Firestore relevantes', H2))
    colecciones = [
        ['Colección', 'Contenido', 'Afecta a'],
        ['empresas/{id}/facturas', 'Facturas emitidas (ingresos)\nUna por documento fiscal', 'FacturacionService · PdfService · Verifactu · Mod.303'],
        ['empresas/{id}/facturas_recibidas', 'Facturas de proveedores (gastos)\nIVA soportado deducible', 'ContabilidadService · Mod.303 · Mod.115'],
        ['empresas/{id}/configuracion/facturacion', 'Contadores por serie:\nultimoNumeroFac, Rect, TPV, etc.\nAño de reset automático', 'FacturacionService._generarNumeroFacturaSerie()'],
        ['empresas/{id}/configuracion/fiscal', 'criterio_iva (devengo/caja)\nconfiguración modelos', 'FacturacionService · todos los Mod.'],
        ['empresas/{id}/pdf_config', 'Datos del emisor para el PDF:\nNIF, razón social, dirección, IBAN', 'PdfService._cargarDatosEmpresa()'],
        ['empresas/{id}/configuracion/facturacionTpv', 'Modo TPV, tipo documento,\nplantillas, impresora, serie', 'TpvFacturacionService · FacturacionAutomaticaService'],
        ['empresas/{id}/verifactu_registros', 'Cadena hash de registros\nenviados a AEAT', 'VerifactuService · HashChainService'],
    ]
    t2 = tabla_simple(colecciones, [5*cm, 5.5*cm, W - 5*cm - 5.5*cm - 3*cm])
    items.append(t2)
    items.append(PageBreak())
    return items

# ── SECCIÓN 3: FLUJOS DE FACTURACIÓN ─────────────────────────────────────────
def seccion_flujos():
    items = [p('3. FLUJOS DE FACTURACIÓN Y DOCUMENTOS FISCALES', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'La app genera distintos tipos de documentos con diferente tratamiento fiscal. '
        'Es fundamental conocer cuáles tienen validez fiscal y cuáles son solo comerciales.', BODY_J))
    items.append(sp(8))

    items.append(p('3.1 Tipos de documentos y su validez fiscal', H2))
    docs = [
        ['Tipo', 'Serie', 'Verifactu', 'Validez fiscal', 'Observaciones'],
        ['Factura completa', 'F-AAAA-XXXX', 'F1 ✓', '✓ Plena',
         'Documento fiscal principal. Campos obligatorios Art. 6 RD 1619/2012.'],
        ['Factura desde pedido', 'F-AAAA-XXXX', 'F1 ✓', '✓ Plena',
         'Mismo tratamiento que factura completa. Vinculada a pedidoId.'],
        ['Factura simplificada (TPV)', 'TPV-AAAA-XXXX', 'F2 ✓', '✓ Limitada',
         'Solo válida ≤ 400 € o actividades específicas. Sin NIF destinatario.'],
        ['Factura rectificativa', 'R-AAAA-XXXX', 'R1-R5 ✓', '✓ Plena',
         'Obligatoria para corregir errores (Art. 15). Métodos S/I. Serie propia.'],
        ['Albarán (entrega)', 'A-AAAA-XXXX', '✗ No', '✗ Sin efecto fiscal',
         'Documento de entrega. No devenga IVA hasta conversión a factura.'],
        ['Presupuesto/Proforma', 'P-AAAA-XXXX', '✗ No', '✗ Sin efecto fiscal',
         'Oferta comercial. No es factura ni devenga IVA.'],
        ['Ticket TPV', 'TPV-AAAA-XXXX', 'F2 ✓', '✓ Limitada',
         'Impreso en papel térmico. Equivalente a factura simplificada.'],
        ['Factura recurrente', 'F-AAAA-XXXX', 'F1 ✓', '✓ Plena',
         'Genera factura ordinaria en fechas programadas. Usa FacturacionService.'],
    ]
    ts_docs = [
        ('BACKGROUND', (2,1), (2,-1), C_VERDE_CLARO),
        ('BACKGROUND', (4,3), (4,3), C_ROJO_CLARO),
    ]
    t = tabla_simple(docs, [3.5*cm, 3*cm, 2*cm, 2.5*cm, W - 3.5*cm - 3*cm - 2*cm - 2.5*cm - 3*cm],
                    ts_docs)
    items.append(t)
    items.append(sp(10))

    items.append(p('3.2 Ciclo de vida de una factura', H2))
    items.append(p(
        'El flujo estándar de una factura en el sistema sigue estos pasos. '
        'Cada transición de estado queda registrada en el historial interno.', BODY))
    estados = [
        ['Estado', 'Significado', 'Transiciones permitidas', 'Nota legal'],
        ['pendiente', 'Emitida, a cobrar', '→ pagada, vencida, rectificada', 'Edición permitida (solo pendiente)'],
        ['pagada', 'Cobrada', '→ solo con rectificativa', 'Fecha de pago registrada para criterio de caja'],
        ['vencida', 'Plazo superado sin pago', '→ pagada, rectificada', 'Marcado automático por el sistema'],
        ['rectificada', 'Corregida por rectificativa', '(estado final de la original)', 'La original NO se anula; ambas coexisten'],
        ['anulada', 'Estado actual del sistema', '(estado final)', '⚠ Problemático: ver hallazgo C4. Solo legal en proformas/albaranes.'],
    ]
    ts_e = [
        ('BACKGROUND', (0,5), (-1,5), C_ROJO_CLARO),
        ('TEXTCOLOR',  (0,5), (-1,5), C_ROJO),
    ]
    t2 = tabla_simple(estados, [2.5*cm, 4*cm, 4.5*cm, W - 2.5*cm - 4*cm - 4.5*cm - 3*cm], ts_e)
    items.append(t2)
    items.append(sp(10))

    items.append(p('3.3 Numeración y series', H2))
    items.append(p(
        'El sistema genera números de factura automáticamente de forma atómica '
        '(transacción Firestore) para garantizar unicidad. El formato es:', BODY))
    items.append(p('PREFIJO-AÑO-NNNN   (ej: F-2026-0042, R-2026-0001, TPV-2026-0123)', CODE))
    items.append(p(
        'Al inicio de cada año natural, el contador se resetea a 0001. Esto es correcto según '
        'el Art. 6.1.a) RD 1619/2012 que permite reiniciar series cada año.', BODY_J))
    series = [
        ['Serie', 'Prefijo', 'Tipos de documento', 'Reset anual'],
        ['fac',  'F',   'Facturas ordinarias, desde pedido, recurrentes', '✓'],
        ['rect', 'R',   'Facturas rectificativas únicamente', '✓'],
        ['pro',  'P',   'Presupuestos/Proformas (sin efecto fiscal)', '✓'],
        ['tpv',  'TPV', 'Documentos TPV (tickets, simplificadas, completas)', '✓'],
        ['alb',  'A',   'Albaranes de entrega (sin efecto fiscal)', '✓'],
    ]
    t3 = tabla_simple(series, [2*cm, 2.5*cm, 8*cm, 2*cm])
    items.append(t3)
    items.append(PageBreak())
    return items

# ── SECCIÓN 4: TPV ────────────────────────────────────────────────────────────
def seccion_tpv():
    items = [p('4. MÓDULO TPV: INTEGRACIÓN CON FACTURACIÓN', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'El TPV es el punto de mayor volumen de transacciones y el que genera más '
        'documentos fiscales por unidad de tiempo. Su correcta configuración es crítica '
        'para el cumplimiento normativo diario.', BODY_J))
    items.append(sp(6))

    items.append(p('4.1 Modos de facturación del TPV', H2))
    modos = [
        ['Modo', 'Cuándo genera factura', 'Tipo documento', 'Serie', 'Riesgo'],
        ['porVenta\n(por pedido)',
         'Al cobrar cada pedido',
         'Ticket / Fact. simplificada / Fact. completa\n(configurable)',
         'TPV-AAAA-XXXX',
         'BAJO si configurado correctamente'],
        ['resumenDiario\n(batch)',
         'Automático a hora configurada\n(o manual al cerrar caja)',
         'Una factura agrupa todos los\npedidos del día',
         'TPV-AAAA-XXXX',
         'MEDIO — perder pedido si el\nbatch falla antes de ejecutarse'],
        ['manual',
         'Solo cuando el usuario\nlo solicita explícitamente',
         'Factura completa (manual)',
         'TPV o F',
         'BAJO — el operador controla\nla emisión'],
    ]
    ts_m = [
        ('BACKGROUND', (0,2), (-1,2), C_AMARILLO_CLARO),
    ]
    t = tabla_simple(modos, [3*cm, 4*cm, 5*cm, 2.5*cm, W - 3*cm - 4*cm - 5*cm - 2.5*cm - 3*cm], ts_m)
    items.append(t)
    items.append(sp(8))

    items.append(p('4.2 Pantallas del TPV y su interacción con facturación', H2))
    pantallas_tpv = [
        ['Pantalla / Widget', 'Archivo', 'Qué hace con facturación'],
        ['Caja Rápida',
         'caja_rapida_screen.dart',
         'Cobro rápido sin mesa. Llama a TpvFacturacionService.\nPermite factura bajo demanda vía DiálogoFacturaTpv.'],
        ['TPV Tienda',
         'tpv_tienda_screen.dart',
         'Catálogo visual con carrito. Cobro genera factura/ticket\nvía FacturacionAutomaticaService al confirmar pago.'],
        ['TPV Peluquería',
         'tpv_peluqueria_screen.dart',
         'Flujo especializado por servicio/empleado.\nUsa FacturacionService.crearFactura() directamente.'],
        ['TPV Root',
         'tpv_root_screen.dart',
         'Pantalla base. Inicializa ConfiguracionFacturacionTpv\ny determina el tipo de documento por defecto.'],
        ['TpvBarCobro (widget)',
         'tpv_bar_cobro.dart',
         'Widget de cobro. Contiene la lógica de selección\nde método de pago y llama al flujo de facturación.'],
        ['DiálogoFacturaTpv (widget)',
         'dialogo_factura_tpv.dart\n+ dialogo_devoluciones.dart',
         'Modal para pedir NIF/datos del cliente.\nDecide factura simplificada vs completa según campos.'],
        ['Configuración Facturación TPV',
         'configuracion_facturacion_tpv_screen.dart',
         'Configura: modo, tipo documento, plantillas PDF,\nimpresora térmica, propina, descuento máximo, serie.'],
        ['Facturar Pedidos (batch)',
         'facturar_pedidos_screen.dart',
         'Genera facturas agrupando pedidos seleccionados.\nUsa FacturacionService.crearFactura() por cada lote.'],
        ['Cierre de Caja',
         'pantalla_cierre_caja.dart',
         'Puede disparar el resumen diario automático si\nel modo está configurado como resumenDiario.'],
        ['Devoluciones (widget)',
         'dialogo_devoluciones.dart',
         'Devolución parcial/total desde TPV. Debería generar\nrectificativa — actualmente usa anularFactura() ⚠'],
    ]
    ts_p = [
        ('BACKGROUND', (0,10), (-1,10), C_ROJO_CLARO),
        ('TEXTCOLOR',  (2,10), (2,10), C_ROJO),
    ]
    t2 = tabla_simple(pantallas_tpv,
        [4*cm, 4.5*cm, W - 4*cm - 4.5*cm - 3*cm], ts_p)
    items.append(t2)
    items.append(sp(8))

    items.append(p('4.3 Flujo de cobro TPV — paso a paso', H2))
    flujo_items = [
        '1. El operador selecciona productos/servicios en el carrito (TpvCaja widget)',
        '2. Pulsa "Cobrar" → se abre TpvBarCobro con selección de método de pago',
        '3. Si el modo es "pedir datos cliente" → aparece DiálogoFacturaTpv',
        '4. El cliente aporta NIF → el sistema decide: factura simplificada (sin NIF) o completa (con NIF)',
        '5. Se llama a FacturacionAutomaticaService.procesarCobro()',
        '6. Dentro de procesarCobro: TpvFacturacionService.generarFacturaPorPedido() o generarFacturaResumenDiario()',
        '7. FacturacionService.crearFactura() → genera número correlativo → valida → guarda en Firestore',
        '8. VerifactuService.registrarFactura() → genera hash → construye XML → envía a AEAT (si Verifactu activo)',
        '9. PdfService / TpvDocumentRenderer → genera PDF / datos para impresora térmica',
        '10. Si hay impresora configurada → envía bytes a la impresora por IP/puerto configurado',
    ]
    for fl in flujo_items:
        items.append(pb(fl))
    items.append(PageBreak())
    return items

# ── SECCIÓN 5: OTRAS PANTALLAS ────────────────────────────────────────────────
def seccion_otras_pantallas():
    items = [p('5. OTRAS PANTALLAS QUE USAN EL SERVICIO DE FACTURACIÓN', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'Además del módulo de facturación y el TPV, hay otras áreas de la app que '
        'interactúan directamente con FacturacionService o generan/consumen documentos fiscales.', BODY_J))
    items.append(sp(8))

    pantallas = [
        ['Pantalla', 'Módulo', 'Cómo usa facturación', 'Riesgo'],
        ['Módulo Facturación\n(pantalla raíz)',
         'Facturación',
         'TabBar con: Facturas, Recurrentes, Recibidas,\nAlbaranes, Libro ingresos, Modelos, Gráficos.',
         'BAJO'],
        ['Formulario Factura',
         'Facturación',
         'Crea/edita facturas: cliente, líneas, IVA, IRPF,\nvencimiento, método pago. Valida R1-R9.',
         'BAJO'],
        ['Detalle Factura',
         'Facturación',
         'Ver, cambiar estado, generar PDF, enviar por email,\ncrear rectificativa. Accede a PdfService.',
         'BAJO'],
        ['Formulario Rectificativa',
         'Facturación',
         'Crea rectificativa (Art. 15). Selecciona motivo\n(R1-R5), método (S/I), líneas corregidas.',
         'BAJO — pero bug en códigos AEAT (C2)'],
        ['Tab Facturas Recibidas',
         'Contabilidad',
         'Registra gastos. IVA soportado para Mod.303.\nSoporte arrendamiento (Mod.115).',
         'BAJO'],
        ['Resumen Fiscal',
         'Facturación',
         'Calcula mod.303, mod.111 desde facturas.\nExporta CSV. Criterio IVA devengo/caja.',
         'MEDIO — afectado por bug C1 (España/ESPANA)'],
        ['Tab Modelos Fiscales',
         'Facturación',
         'Mod. 303, 111, 115, 347, 349, 130, 202.\nGenera resúmenes desde Cloud Functions.',
         'MEDIO — Mod.303 afectado por C1'],
        ['Pantalla Contabilidad',
         'Contabilidad',
         'Gastos, proveedores, facturas recibidas.\nContabilidad básica de la empresa.',
         'BAJO'],
        ['Detalle Pedido',
         'Pedidos',
         'Desde un pedido: genera factura directamente.\nUsa FacturacionService.crearFacturaDesdePedido().',
         'BAJO'],
        ['Caja Rápida',
         'TPV',
         'Cobro rápido. Factura/ticket al cerrar.',
         'BAJO — ver sección 4'],
        ['Upload Invoice',
         'Fiscal/Facturación',
         'OCR de facturas recibidas vía Claude API.\nExtracción de NIF, importe, IVA, retención.',
         'BAJO — validación post-OCR correcta'],
        ['Modelo 111 Screen',
         'Fiscal',
         'Usa PdfService para generar el PDF del modelo.\nLee retenciones IRPF de FacturacionService.',
         'BAJO'],
        ['Detalle Nómina',
         'RRHH/Nóminas',
         'Genera PDF de nómina usando PdfService.\nNo usa facturacion_service directamente.',
         'BAJO'],
        ['Finiquito / Carta Cese',
         'RRHH',
         'PDF generado con PdfService.\nNo vinculado a facturación.',
         'BAJO'],
        ['Modulo TPV Screen',
         'TPV',
         'Menú de acceso al TPV. Configura facturación TPV.\nAccede a ConfiguracionFacturacionTpv.',
         'BAJO'],
    ]
    ts_p = [
        ('BACKGROUND', (0,6),  (-1,6),  C_AMARILLO_CLARO),
        ('BACKGROUND', (0,7),  (-1,7),  C_AMARILLO_CLARO),
        ('BACKGROUND', (0,4),  (-1,4),  C_ROJO_CLARO),
        ('TEXTCOLOR',  (0,4),  (-1,4),  C_ROJO),
    ]
    t = tabla_simple(pantallas, [4*cm, 2.5*cm, 7*cm, W - 4*cm - 2.5*cm - 7*cm - 3*cm], ts_p)
    items.append(t)
    items.append(PageBreak())
    return items

# ── SECCIÓN 6: VERIFACTU ───────────────────────────────────────────────────────
def seccion_verifactu():
    items = [p('6. VERIFACTU — ESTADO DE IMPLEMENTACIÓN', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'Verifactu (RD 1007/2023) es el sistema de registro fiscal electrónico que obliga '
        'a los sistemas informáticos de facturación a enviar en tiempo real (o en diferido) '
        'cada factura emitida a la AEAT, con firma digital y encadenamiento de hashes.', BODY_J))
    items.append(sp(8))

    items.append(p('6.1 Componentes implementados', H2))
    componentes = [
        ['Componente', 'Estado', 'Archivo', 'Notas'],
        ['Hash chain SHA-256', '✓ Implementado', 'verifactu/hash_chain_service.dart', 'Cada factura incluye el hash de la anterior'],
        ['Construcción XML', '✓ Implementado', 'verifactu/xml_payload_verifactu_builder.dart', 'Formato AEAT Anexo I RD 1007/2023'],
        ['Firma XAdES-BES (PKCS12)', '✓ Implementado', 'verifactu/firma_xades_pkcs12_service.dart', 'Firma cualificada con certificado digital'],
        ['QR en factura PDF', '✓ Implementado', 'verifactu/qr_service.dart + pdf_service.dart', 'URL verificación AEAT incrustada en PDF'],
        ['Tipos F1/F2/R1-R5', '✓ Implementado', 'verifactu/modelos_verifactu.dart', 'Mapeo correcto excepto R2 bug (ver C2)'],
        ['Envío a AEAT (prod)', '⚠ En desarrollo', 'verifactu_service.dart', 'Infraestructura lista; endpoint prod pendiente config'],
        ['Subida certificado UI', '✓ Implementado', 'fiscal/pantallas/subir_certificado_verifactu_screen.dart', 'Interfaz para subir .p12 / .pfx'],
        ['Panel validación R1-R9', '✓ Implementado', 'facturacion/widgets/panel_validacion_fiscal.dart', 'UI de estado de cumplimiento por factura'],
    ]
    ts_c = [
        ('BACKGROUND', (0,7), (-1,7), C_AMARILLO_CLARO),
    ]
    t = tabla_simple(componentes, [4*cm, 2.5*cm, 5.5*cm, W - 4*cm - 2.5*cm - 5.5*cm - 3*cm], ts_c)
    items.append(t)
    items.append(sp(8))

    items.append(p('6.2 Mapeo de tipos de factura a Verifactu', H2))
    tipos = [
        ['Tipo doc en app', 'Código Verifactu', 'Descripción AEAT', 'Correcto'],
        ['Factura ordinaria (F-xxxx)', 'F1', 'Factura ordinaria completa', '✓'],
        ['Factura simplificada (TPV)', 'F2', 'Factura simplificada', '✓'],
        ['Rectificativa (motivo R1)', 'R1', 'Error fundado en Derecho', '✓'],
        ['Rectificativa (devolución total)', 'R2 ❌', 'Concurso de acreedores — INCORRECTO', '✗ Bug C2'],
        ['Rectificativa (devolución parcial)', 'R2 ❌', 'Concurso de acreedores — INCORRECTO', '✗ Bug C2'],
        ['Rectificativa (error importes)', 'R4', 'Otros casos', '✓'],
        ['Rectificativa (Art. 80 LIVA)', 'R5', 'Modificación base imponible', '✓'],
    ]
    ts_t = [
        ('BACKGROUND', (0,4), (-1,5), C_ROJO_CLARO),
        ('TEXTCOLOR',  (3,4), (3,5), C_ROJO),
        ('FONTNAME',   (3,4), (3,5), 'Helvetica-Bold'),
    ]
    t2 = tabla_simple(tipos, [5*cm, 3*cm, 6*cm, 2*cm], ts_t)
    items.append(t2)
    items.append(PageBreak())
    return items

# ── SECCIÓN 7: MODELOS FISCALES ────────────────────────────────────────────────
def seccion_modelos():
    items = [p('7. MODELOS FISCALES AEAT — ESTADO DE IMPLEMENTACIÓN', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'La app implementa los principales modelos de la AEAT. Cada modelo se calcula '
        'a partir de las facturas almacenadas en Firestore, aplicando el criterio de IVA '
        '(devengo o caja) configurado por la empresa.', BODY_J))
    items.append(sp(8))

    modelos = [
        ['Modelo', 'Descripción', 'Periodicidad', 'Estado', 'Fuente de datos'],
        ['Mod. 303', 'IVA trimestral\n(IVA repercutido - IVA soportado)', 'Trimestral',
         '✓ Implementado\n⚠ Bug C1 afecta', 'facturas + facturas_recibidas'],
        ['Mod. 111', 'Retenciones IRPF\n(empleados + actividades económicas)', 'Trimestral',
         '✓ Implementado', 'facturas con porcentaje_irpf > 0\n+ nóminas'],
        ['Mod. 115', 'Retenciones arrendamientos\n(19% fijo propietario)', 'Trimestral',
         '✓ Implementado', 'facturas_recibidas con es_arrendamiento=true'],
        ['Mod. 130', 'Pago fraccionado IRPF\nautónomos (estimación directa)', 'Trimestral',
         '✓ Implementado', 'ingresos - gastos acumulados YTD'],
        ['Mod. 180', 'Resumen anual retenciones\narrendamientos', 'Anual',
         '✓ Implementado', 'Agrega datos Mod.115 anuales'],
        ['Mod. 190', 'Resumen anual retenciones\ny rendimientos del trabajo', 'Anual',
         '✓ Implementado', 'Agrega datos Mod.111 anuales'],
        ['Mod. 202', 'Impuesto sociedades\n(pago fraccionado)', 'Trimestral',
         '✓ Implementado', 'Beneficio contable estimado'],
        ['Mod. 347', 'Operaciones con terceros\n(≥ 3.000 € anuales)', 'Anual',
         '✓ Implementado', 'Agrupa facturas por NIF proveedor/cliente'],
        ['Mod. 349', 'Operaciones intracomunitarias', 'Trimestral/Mensual',
         '✓ Implementado\n⚠ Bug C1 afecta', 'facturas con es_intracomunitario=true'],
        ['Mod. 390', 'Resumen anual IVA', 'Anual',
         '✓ Implementado', 'Agrega datos Mod.303 anuales'],
    ]
    ts_m = [
        ('BACKGROUND', (0,1), (-1,1), C_AMARILLO_CLARO),
        ('BACKGROUND', (0,9), (-1,9), C_AMARILLO_CLARO),
    ]
    t = tabla_simple(modelos, [2*cm, 4.5*cm, 2.5*cm, 3*cm, W - 2*cm - 4.5*cm - 2.5*cm - 3*cm - 3*cm], ts_m)
    items.append(t)
    items.append(sp(8))

    items.append(caja_coloreada([
        p('<b>Impacto del bug C1 en los modelos:</b> La comparación incorrecta de país '
          '("ESPAÑA" ≠ "ESPANA") clasifica facturas domésticas como intracomunitarias, '
          'lo que las excluye del cálculo del Mod. 303 (IVA repercutido) y las incluye '
          'incorrectamente en el Mod. 349 (operaciones intracomunitarias). '
          'Esto provoca una <b>declaración de IVA inferior a la real</b> y una '
          '<b>declaración intracomunitaria ficticia</b>.', BODY_J),
    ], C_ROJO_CLARO, C_ROJO, '🚨 Alerta: Bug C1 contamina Mod.303 y Mod.349', C_ROJO))
    items.append(PageBreak())
    return items

# ── SECCIÓN 8: HALLAZGOS DE AUDITORÍA ─────────────────────────────────────────
def seccion_auditoria():
    items = [p('8. AUDITORÍA DE CUMPLIMIENTO — HALLAZGOS', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'Se han identificado los siguientes incumplimientos o riesgos de incumplimiento '
        'con la normativa española de facturación vigente a octubre de 2026.', BODY_J))
    items.append(sp(8))

    # ── CRÍTICOS ────────────────────────────────────────────────────
    items.append(p('8.1 HALLAZGOS CRÍTICOS (corrección inmediata)', H2))

    criticos = [
        {
            'id': 'C1',
            'titulo': 'Bug: país "ESPAÑA" ≠ "ESPANA" — empresas españolas clasificadas como intracomunitarias',
            'norma': 'Ley 37/1992 LIVA · Mod. 303 · Mod. 349',
            'archivo': 'lib/services/facturacion_service.dart:1135',
            'codigo_actual': 'if (pais.isNotEmpty && pais != \'ESPANA\' && pais != \'ES\') return true;',
            'codigo_correcto': 'if (pais.isNotEmpty && pais != \'ESPAÑA\' && pais != \'ESPANA\' && pais != \'ES\') return true;',
            'impacto': (
                'La ñ española se pierde en la comparación. "España".toUpperCase() = "ESPAÑA" que '
                'no coincide con "ESPANA". Resultado: TODAS las facturas a clientes españoles '
                'se excluyen del Mod. 303 (IVA repercutido) y se incluyen en Mod. 349 (intracomunitarias). '
                'El IVA declarado sería inferior al real → riesgo de sanción por diferencia.'
            ),
            'esfuerzo': '1 línea',
        },
        {
            'id': 'C2',
            'titulo': 'Códigos AEAT incorrectos en facturas rectificativas (R2 = concurso de acreedores)',
            'norma': 'Orden HAC/1177/2024 · RD 1007/2023 · Verifactu',
            'archivo': 'lib/domain/modelos/factura.dart:141-143',
            'codigo_actual': 'case devolucionTotal:   return \'R2\';\ncase devolucionParcial: return \'R2\';',
            'codigo_correcto': 'case devolucionTotal:   return \'R1\';\ncase devolucionParcial: return \'R1\';',
            'impacto': (
                'R2 en Verifactu significa específicamente "Concurso de acreedores" (Art. 80.3 LIVA). '
                'Registrar devoluciones ordinarias como R2 implica que la empresa está en quiebra, '
                'lo que puede desencadenar revisiones de la AEAT. Las devoluciones de mercancía '
                'o servicios deben ser R1 (error fundado en Derecho).'
            ),
            'esfuerzo': '2 líneas',
        },
        {
            'id': 'C3',
            'titulo': 'Regla R6 (60 segundos) aplicada incorrectamente a fecha de expedición',
            'norma': 'Art. 10.2 RD 1007/2023',
            'archivo': 'lib/services/validador_fiscal_integral.dart:176-191',
            'codigo_actual': 'if (diferencia > 60) { errores.add(\'R6-TIEMPO...\'); }',
            'codigo_correcto': 'Eliminar de validarFacturaCompleta(). Mover al servicio Verifactu,\nsolo al construir el timestamp XML de registro.',
            'impacto': (
                'La regla de 60 segundos es para el campo Timestamp del XML que se envía a AEAT, '
                'no para la fecha de expedición de la factura. Aplicarla a la creación de facturas '
                'bloquea: registrar facturas del día anterior, conversiones de proformas con fecha '
                'anterior, rectificativas. Genera cientos de advertencias falsas en uso normal.'
            ),
            'esfuerzo': 'Bajo — mover validación',
        },
        {
            'id': 'C4',
            'titulo': 'anularFactura() en documentos fiscales no genera la rectificativa obligatoria',
            'norma': 'Art. 15 RD 1619/2012',
            'archivo': 'lib/services/facturacion_service.dart:750-771',
            'codigo_actual': 'await _facturas(id).doc(facturaId).update({\'estado\': \'anulada\'});\n// Sin factura rectificativa',
            'codigo_correcto': 'Añadir guardia: if (factura.esDocumentoFiscal) throw Exception(\n  \'Las facturas fiscales no se anulan, se rectifican. Usar crearFacturaRectificativa.\'\n);',
            'impacto': (
                'El RD 1619/2012 Art. 15 no permite "anular" facturas ya emitidas. Solo se pueden '
                'corregir mediante factura rectificativa. Si se marca como anulada sin emitir '
                'rectificativa, el IVA devengado nunca se corrige en los registros de la AEAT, '
                'la cadena Verifactu queda inconsistente y la deducción del cliente es imposible.'
            ),
            'esfuerzo': 'Medio — añadir guardia + refactorizar llamadas',
        },
    ]

    for hall in criticos:
        items.append(sp(4))
        inner = [
            p(f'<b>[{hall["id"]}]</b> {hall["titulo"]}', CRITICO_LBL),
            hr(C_ROJO, 0.5),
            p(f'<b>Norma:</b> {hall["norma"]}', SMALL),
            p(f'<b>Archivo:</b> {hall["archivo"]}', SMALL),
            sp(4),
            p('<b>Código actual (incorrecto):</b>', SMALL),
            p(hall['codigo_actual'], CODE),
            p('<b>Corrección:</b>', SMALL),
            p(hall['codigo_correcto'], CODE),
            p(f'<b>Impacto:</b> {hall["impacto"]}', NOTA),
            p(f'<b>Esfuerzo estimado:</b> {hall["esfuerzo"]}', SMALL),
        ]
        items.append(caja_coloreada(inner, C_ROJO_CLARO, C_ROJO))
        items.append(sp(6))

    items.append(PageBreak())

    # ── MEDIOS ────────────────────────────────────────────────────────────────
    items.append(p('8.2 HALLAZGOS MEDIOS (corregir antes del próximo cierre fiscal)', H2))
    items.append(sp(6))

    medios = [
        ['Código', 'Descripción', 'Norma', 'Archivo', 'Corrección'],
        ['M1', 'Umbral de NIF obligatorio fijado en >400 € para facturas B2B. El NIF es obligatorio\nen toda factura completa a empresario/profesional independientemente del importe.',
         'Art. 6.1.d) RD 1619/2012',
         'validador_fiscal_integral.dart:81',
         'Eliminar la condición factura.total > 400 del bloque de error. Mantenerla solo\ncomo advertencia en facturas sin datos fiscales (B2C presumible).'],
        ['M2', 'Plazo de conservación configurado en 4 años. El Código de Comercio exige 6 años\npara documentos mercantiles.',
         'Art. 30 Cód. Comercio\n+ Art. 66 LGT',
         'validador_fiscal_integral.dart:200',
         'Cambiar Duration(days: 1461) por Duration(days: 2192) (6 años).'],
        ['M3', 'Tipos IVA temporales de 2023 no en el enum TipoIVA: 0% alimentos básicos y 5%\naceite/pasta. Empresas del sector alimentación aplican IVA incorrecto.',
         'RD-ley 17/2022\n(prorrogado 2024)',
         'domain/modelos/factura.dart (enum TipoIVA)',
         'Añadir valores ceroTemporalAlimentos y reducidoTemp5 al enum. Marcarlos\ncomo temporales con comentario de vigencia.'],
        ['M4', 'Texto en ticket TPV indica "Válida hasta 3.000 €". El límite general de la factura\nsimplificada es 400 € (Art. 7.2 RD 1619/2012). El de 3.000 € es solo para\nactividades específicas (venta ambulante, transporte, etc.).',
         'Art. 7.2 RD 1619/2012',
         'tpv_document_renderer.dart:501',
         'Cambiar el texto a 400 € o añadir nota indicando que el límite de 3.000 €\naplica solo a actividades del Art. 7.1 RD 1619/2012.'],
        ['M5', 'editarFactura() no re-registra en Verifactu tras modificar. Si se edita una factura\ntras su creación pero antes de enviarla, el hash chain queda desincronizado.',
         'Art. 8 RD 1007/2023',
         'facturacion_service.dart:257-328',
         'Añadir llamada a VerifactuService.registrarFactura() al final de editarFactura(),\no bloquear la edición tras el registro Verifactu.'],
    ]
    ts_med = [
        ('BACKGROUND', (0,0), (-1,0), C_NARANJA),
        ('TEXTCOLOR',  (0,0), (-1,0), white),
    ]
    t = tabla_simple(medios, [1.5*cm, 5.5*cm, 3*cm, 3*cm, W - 1.5*cm - 5.5*cm - 3*cm - 3*cm - 3*cm], ts_med)
    items.append(t)
    items.append(PageBreak())

    # ── BAJOS ─────────────────────────────────────────────────────────────────
    items.append(p('8.3 HALLAZGOS DE BAJA SEVERIDAD (hardening recomendado)', H2))
    items.append(sp(6))

    bajos = [
        ['Código', 'Descripción', 'Norma / Referencia', 'Acción recomendada'],
        ['B1', 'Las facturas simplificadas del TPV no validan el importe antes de emitir.\nSin NIF destinatario, si el total supera 400 € (sin actividad específica) la\nfactura es técnicamente inválida.',
         'Art. 7.2 RD 1619/2012',
         'Añadir check en TpvFacturacionService: si tipo=simplificada y total > 400 y sin NIF,\nbloquearlo o solicitar datos al cliente.'],
        ['B2', 'El campo porcentajeIrpf en Factura mezcla retenciones de actividades\neconómicas (Mod.111) con arrendamientos (Mod.115), que son modelos distintos.',
         'LIRPF Art. 86 y 101',
         'Separar el campo en irpfActividad (Mod.111) y retArrend (Mod.115)\no documentar que esArrendamiento ya lo diferencia en FacturaRecibida.'],
        ['B3', 'El modelo Factura principal no tiene campo claveRegimenEspecial\n(régimen especial OSS, bienes usados, etc.), que sí existe en billing_service.',
         'RD 1007/2023 Anexo I',
         'Añadir campo opcional claveRegimenEspecial a Factura. Necesario para\nnegocios en régimen especial (OSS, RE Bienes Usados, viajes, etc.).'],
        ['B4', 'No hay validación que impida que una rectificativa apunte a otra rectificativa\ncomo factura original (estructura inválida según normativa).',
         'Art. 15 RD 1619/2012',
         'Añadir en crearFacturaRectificativa(): if (original.esRectificativa) throw Exception.'],
        ['B5', 'Devoluciones desde el diálogo de devoluciones del TPV podrían llamar\na anularFactura() en lugar de crearFacturaRectificativa().',
         'Art. 15 RD 1619/2012',
         'Revisar dialogo_devoluciones.dart y asegurar que usa el flujo de rectificativas,\nno el de anulación.'],
    ]
    t2 = tabla_simple(bajos, [1.5*cm, 6*cm, 3*cm, W - 1.5*cm - 6*cm - 3*cm - 3*cm])
    items.append(t2)
    items.append(PageBreak())
    return items

# ── SECCIÓN 9: MAPA DE RIESGOS POR PANTALLA ──────────────────────────────────
def seccion_mapa_riesgos():
    items = [p('9. MAPA DE RIESGOS POR PANTALLA Y FLUJO', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'Esta tabla consolida el nivel de riesgo actual de cada pantalla/flujo '
        'con los hallazgos específicos que les afectan.', BODY_J))
    items.append(sp(8))

    mapa = [
        ['Pantalla / Flujo', 'Riesgo\nactual', 'Hallazgos\nafectantes', 'Impacto si no se corrige'],
        ['Módulo Facturación → Tab Facturas', 'BAJO', '—', 'Ninguno significativo'],
        ['Formulario Factura (crear/editar)', 'MEDIO', 'C3, M1', 'Bloqueo falso por R6 + NIF no exigido en B2B pequeño'],
        ['Formulario Rectificativa', 'CRÍTICO', 'C2', 'Registros Verifactu con código R2 (concurso de acreedores) para devoluciones normales'],
        ['Detalle Factura → Anular', 'CRÍTICO', 'C4', 'Facturas "anuladas" sin rectificativa → IVA devengado no corregido en AEAT'],
        ['Resumen Fiscal / Mod. 303', 'CRÍTICO', 'C1', 'IVA repercutido declarado incorrecto (bajo) → diferencia a pagar + recargo'],
        ['Mod. 349 Intracomunitarias', 'CRÍTICO', 'C1', 'Declaración ficticia de operaciones intracomunitarias (facturas domésticas)'],
        ['TPV → Cobro por pedido', 'BAJO', 'B1', 'Factura simplificada emitida por encima de 400 € sin NIF (raro en práctica)'],
        ['TPV → Devoluciones', 'ALTO', 'C4, B5', 'Devolución procesada como anulación, no como rectificativa → IVA no corregido'],
        ['TPV → Config Facturación', 'MEDIO', 'M4', 'Texto incorrecto sobre límite factura simplificada (3.000 € en lugar de 400 €)'],
        ['TPV → Factura Simplificada', 'MEDIO', 'M3', 'Sin tipo IVA 0%/5% temporales → alimentación aplica tipos incorrectos'],
        ['Facturas recurrentes', 'BAJO', 'C3', 'Advertencia R6 falsa en facturas generadas automáticamente'],
        ['Conversión albarán → factura', 'BAJO', '—', 'Flujo correcto; anularFactura solo sobre albarán (no fiscal)'],
        ['Conversión proforma → factura', 'BAJO', 'C4', 'anularFactura sobre proforma (no fiscal) → aceptable, pero confuso'],
        ['Upload Invoice (OCR)', 'BAJO', '—', 'Extracción IA correcta; validación NIF post-OCR implementada'],
        ['Modelos fiscales (111, 115, etc.)', 'BAJO', '—', 'Cálculos correctos; no afectados por bug C1'],
    ]
    colores = {
        'CRÍTICO': C_ROJO_CLARO,
        'ALTO':    C_NARANJA_CLARO,
        'MEDIO':   C_AMARILLO_CLARO,
        'BAJO':    C_VERDE_CLARO,
    }
    text_colors = {
        'CRÍTICO': C_ROJO,
        'ALTO':    C_NARANJA,
        'MEDIO':   HexColor('#F57F17'),
        'BAJO':    C_VERDE,
    }
    ts_extra = []
    for i, row in enumerate(mapa[1:], 1):
        nivel = row[1]
        if nivel in colores:
            ts_extra.append(('BACKGROUND', (1, i), (1, i), colores[nivel]))
            ts_extra.append(('TEXTCOLOR',  (1, i), (1, i), text_colors[nivel]))
            ts_extra.append(('FONTNAME',   (1, i), (1, i), 'Helvetica-Bold'))
    t = tabla_simple(mapa, [5.5*cm, 1.8*cm, 2.5*cm, W - 5.5*cm - 1.8*cm - 2.5*cm - 3*cm], ts_extra)
    items.append(t)
    items.append(PageBreak())
    return items

# ── SECCIÓN 10: PLAN DE CORRECCIÓN ────────────────────────────────────────────
def seccion_plan():
    items = [p('10. PLAN DE CORRECCIÓN PRIORIZADO', H1), hr(C_AZUL, 1.5), sp()]
    items.append(p(
        'El siguiente plan ordena las correcciones por urgencia, impacto en cumplimiento '
        'y esfuerzo de implementación. Las tareas de la Fase 1 deben completarse antes '
        'del cierre del trimestre en curso.', BODY_J))
    items.append(sp(8))

    items.append(p('FASE 1 — Urgente (antes del próximo cierre fiscal)', H2))
    f1 = [
        ['#', 'Tarea', 'Archivo', 'Línea(s)', 'Esfuerzo', 'Responsable'],
        ['1.1', 'Fix C1: Añadir "ESPAÑA" a la comparación de país para\nevitar clasificar clientes españoles como intracomunitarios',
         'facturacion_service.dart', '1135', '1 línea', 'Dev backend'],
        ['1.2', 'Fix C2: Cambiar R2→R1 para devolucionTotal y\ndevolucionParcial en codigoAEAT',
         'factura.dart', '141-143', '2 líneas', 'Dev backend'],
        ['1.3', 'Fix C3: Mover validación R6 (60 seg) fuera de\nvalidarFacturaCompleta(); solo en servicio Verifactu',
         'validador_fiscal_integral.dart', '176-191', '< 1h', 'Dev backend'],
        ['1.4', 'Fix C4: Añadir guardia en anularFactura() que impida\nsu uso en documentos fiscales',
         'facturacion_service.dart', '750-771', '< 2h', 'Dev backend'],
        ['1.5', 'Fix M4: Corregir texto "válida hasta 3.000 €" por "400 €"\nen ticket TPV',
         'tpv_document_renderer.dart', '501', '1 línea', 'Dev frontend'],
    ]
    ts_f1 = [('BACKGROUND', (0,0), (-1,0), C_VERDE), ('TEXTCOLOR', (0,0), (-1,0), white)]
    t1 = tabla_simple(f1, [0.5*cm, 6.5*cm, 3.5*cm, 1.2*cm, 1.5*cm, W-0.5*cm-6.5*cm-3.5*cm-1.2*cm-1.5*cm-3*cm], ts_f1)
    items.append(t1)
    items.append(sp(12))

    items.append(p('FASE 2 — Próxima iteración (antes del cierre del trimestre)', H2))
    f2 = [
        ['#', 'Tarea', 'Archivo', 'Esfuerzo'],
        ['2.1', 'Fix M1: Eliminar umbral de 400 € del error de NIF en facturas B2B\n(mantener solo como advertencia en facturas sin datos fiscales)',
         'validador_fiscal_integral.dart:81', '< 30 min'],
        ['2.2', 'Fix M2: Cambiar plazo conservación de 4 a 6 años',
         'validador_fiscal_integral.dart:200', '1 línea'],
        ['2.3', 'Fix M3: Añadir TipoIVA.ceroTemporalAlimentos y reducidoTemp5\nal enum + recargos de equivalencia correspondientes',
         'factura.dart (enum TipoIVA)', '< 2h'],
        ['2.4', 'Fix M5: Añadir re-registro Verifactu en editarFactura() o\nbloquear edición tras registro Verifactu',
         'facturacion_service.dart:257', '< 3h'],
        ['2.5', 'Fix B5: Verificar que dialogo_devoluciones.dart usa\ncrearFacturaRectificativa() en lugar de anularFactura()',
         'dialogo_devoluciones.dart', '< 1h'],
        ['2.6', 'Fix B4: Añadir validación que impida rectificativa de rectificativa',
         'facturacion_service.dart:350', '< 30 min'],
    ]
    t2 = tabla_simple(f2, [0.5*cm, 8*cm, 4*cm, W-0.5*cm-8*cm-4*cm-3*cm])
    items.append(t2)
    items.append(sp(12))

    items.append(p('FASE 3 — Largo plazo (mejoras normativas)', H2))
    f3 = [
        ['#', 'Tarea', 'Estimación'],
        ['3.1', 'Añadir campo claveRegimenEspecial a Factura (OSS, bienes usados, etc.)', '2-4h'],
        ['3.2', 'Separar retención actividades económicas vs arrendamientos en el modelo Factura', '4-6h'],
        ['3.3', 'Implementar validación de importe máximo para factura simplificada en TPV', '2h'],
        ['3.4', 'Completar obligatoriedad Verifactu (endpoint producción AEAT)', '1-2 semanas'],
        ['3.5', 'Factura electrónica B2B obligatoria (Ley 18/2022 Crea y Crece) — preparar infraestructura', '2-3 semanas'],
    ]
    t3 = tabla_simple(f3, [0.5*cm, 11*cm, W-0.5*cm-11*cm-3*cm])
    items.append(t3)
    items.append(sp(12))

    # ── Resumen ejecutivo final ─────────────────────────────────────────────
    items.append(hr(C_AZUL, 1))
    items.append(p('RESUMEN EJECUTIVO', H2))
    resumen = [
        ['Severidad', 'Cantidad', 'Estado', 'Acción'],
        ['Crítico', '4', 'Corrección inmediata requerida', 'Fase 1 (< 1 día de trabajo)'],
        ['Medio', '5', 'Antes del próximo cierre fiscal', 'Fase 2 (< 1 semana)'],
        ['Bajo', '5', 'Mejora de robustez', 'Fase 3 (planificación)'],
        ['Total', '14', '—', '—'],
    ]
    ts_res = [
        ('BACKGROUND', (0,1), (-1,1), C_ROJO_CLARO),
        ('TEXTCOLOR',  (0,1), (-1,1), C_ROJO),
        ('BACKGROUND', (0,2), (-1,2), C_AMARILLO_CLARO),
        ('BACKGROUND', (0,3), (-1,3), C_VERDE_CLARO),
        ('BACKGROUND', (0,4), (-1,4), C_GRIS_CLARO),
        ('FONTNAME',   (0,4), (-1,4), 'Helvetica-Bold'),
    ]
    t4 = tabla_simple(resumen, [3*cm, 2.5*cm, 6*cm, W-3*cm-2.5*cm-6*cm-3*cm], ts_res)
    items.append(t4)
    items.append(sp(10))

    items.append(caja_coloreada([
        p('El módulo de facturación de Fluix/PlaneaG tiene una base sólida de cumplimiento normativo, '
          'con implementación de Verifactu, series separadas, validación NIF, criterio IVA devengo/caja '
          'y todos los modelos fiscales principales. Los 4 hallazgos críticos son correcciones puntuales '
          '(1-2 líneas de código en su mayoría) que deben priorizarse antes del próximo cierre fiscal. '
          'El hallazgo C1 (bug España/ESPANA) es el más urgente ya que afecta la declaración trimestral '
          'de IVA en producción ahora mismo.', BODY_J),
    ], C_AZUL_CLARO, C_AZUL))

    return items

# ── MAIN ──────────────────────────────────────────────────────────────────────
def main():
    out_path = os.path.join(os.path.dirname(__file__), 'informe_facturacion_legal.pdf')
    doc = SimpleDocTemplate(
        out_path,
        pagesize=A4,
        rightMargin=2*cm, leftMargin=2*cm,
        topMargin=2.4*cm, bottomMargin=2.2*cm,
        title='Fluix — Informe Facturación Legal',
        author='Claude Code / Fluix',
        subject='Situación legal módulo facturación',
    )

    story = []
    story += portada()
    story += indice()
    story += seccion_normativa()
    story += seccion_arquitectura()
    story += seccion_flujos()
    story += seccion_tpv()
    story += seccion_otras_pantallas()
    story += seccion_verifactu()
    story += seccion_modelos()
    story += seccion_auditoria()
    story += seccion_mapa_riesgos()
    story += seccion_plan()

    doc.build(story, onFirstPage=_header_footer, onLaterPages=_header_footer)
    print(f'[OK] PDF generado: {out_path}')
    return out_path

if __name__ == '__main__':
    main()

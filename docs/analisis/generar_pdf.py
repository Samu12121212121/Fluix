#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generador PDF — Fluix CRM Análisis Técnico
Requiere: reportlab
Uso: python generar_pdf.py
"""

import re
from pathlib import Path
from datetime import date

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether, ListFlowable, ListItem
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY, TA_RIGHT
from reportlab.pdfgen import canvas as pdfcanvas

BASE_DIR = Path(__file__).parent
INPUT_MD = BASE_DIR / "informe_final.md"
OUTPUT_PDF = BASE_DIR / "Analisis_Fluix_CRM.pdf"

# ── Colores ──────────────────────────────────────────────────────────────────
AZUL_FLUIX   = colors.HexColor("#1A3A5C")
AZUL_CLARO   = colors.HexColor("#2E6DA4")
GRIS_OSCURO  = colors.HexColor("#333333")
GRIS_MEDIO   = colors.HexColor("#666666")
GRIS_CLARO   = colors.HexColor("#F5F5F5")
ROJO         = colors.HexColor("#C0392B")
AMARILLO     = colors.HexColor("#E67E22")
VERDE        = colors.HexColor("#1E8449")
BLANCO       = colors.white

PAGE_W, PAGE_H = A4
MARGIN = 2.2 * cm


# ── Numeración de páginas ────────────────────────────────────────────────────
class NumberedCanvas(pdfcanvas.Canvas):
    def __init__(self, *args, **kwargs):
        pdfcanvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []
        self._page_counter = 0

    def showPage(self):
        self._page_counter += 1
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for idx, state in enumerate(self._saved_page_states):
            self.__dict__.update(state)
            self._draw_page_number(idx + 1, num_pages)
            pdfcanvas.Canvas.showPage(self)
        pdfcanvas.Canvas.save(self)

    def _draw_page_number(self, page_num: int, page_count: int):
        if page_num > 1:  # No en portada
            self.setFont("Helvetica", 8)
            self.setFillColor(GRIS_MEDIO)
            self.drawRightString(
                PAGE_W - MARGIN,
                0.8 * cm,
                f"Fluix CRM — Análisis Técnico  ·  Página {page_num} de {page_count}"
            )
            self.setStrokeColor(GRIS_CLARO)
            self.line(MARGIN, 1.2 * cm, PAGE_W - MARGIN, 1.2 * cm)


# ── Estilos ──────────────────────────────────────────────────────────────────
def make_styles():
    base = getSampleStyleSheet()

    styles = {
        "normal": ParagraphStyle(
            "normal", parent=base["Normal"],
            fontName="Helvetica", fontSize=9.5,
            leading=14, textColor=GRIS_OSCURO,
            alignment=TA_JUSTIFY, spaceAfter=4,
        ),
        "h1": ParagraphStyle(
            "h1", fontName="Helvetica-Bold", fontSize=17,
            textColor=AZUL_FLUIX, spaceBefore=18, spaceAfter=6, leading=22,
        ),
        "h2": ParagraphStyle(
            "h2", fontName="Helvetica-Bold", fontSize=13,
            textColor=AZUL_FLUIX, spaceBefore=14, spaceAfter=4, leading=18,
            borderPad=4,
        ),
        "h3": ParagraphStyle(
            "h3", fontName="Helvetica-Bold", fontSize=11,
            textColor=AZUL_CLARO, spaceBefore=10, spaceAfter=3, leading=15,
        ),
        "h4": ParagraphStyle(
            "h4", fontName="Helvetica-BoldOblique", fontSize=10,
            textColor=GRIS_OSCURO, spaceBefore=8, spaceAfter=2,
        ),
        "code": ParagraphStyle(
            "code", fontName="Courier", fontSize=8,
            textColor=GRIS_OSCURO, backColor=GRIS_CLARO,
            leading=11, leftIndent=8, rightIndent=8,
            spaceBefore=2, spaceAfter=2,
        ),
        "bullet": ParagraphStyle(
            "bullet", parent=base["Normal"],
            fontName="Helvetica", fontSize=9.5,
            leading=14, textColor=GRIS_OSCURO,
            leftIndent=16, spaceAfter=2,
        ),
        "caption": ParagraphStyle(
            "caption", fontName="Helvetica-Oblique", fontSize=8,
            textColor=GRIS_MEDIO, alignment=TA_CENTER,
        ),
        "table_header": ParagraphStyle(
            "table_header", fontName="Helvetica-Bold", fontSize=8.5,
            textColor=BLANCO, alignment=TA_CENTER,
        ),
        "table_cell": ParagraphStyle(
            "table_cell", fontName="Helvetica", fontSize=8.5,
            textColor=GRIS_OSCURO, alignment=TA_LEFT, leading=11,
        ),
    }
    return styles


# ── Utilidades de parseo ─────────────────────────────────────────────────────
def inline_format(text: str) -> str:
    """Convierte markdown inline a ReportLab XML."""
    # Escapar caracteres especiales RL antes de insertar tags
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    # Negrita-cursiva ***text***
    text = re.sub(r'\*\*\*(.+?)\*\*\*', r'<b><i>\1</i></b>', text)
    # Negrita **text**
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    # Cursiva *text*
    text = re.sub(r'\*(.+?)\*', r'<i>\1</i>', text)
    # Código `code`
    text = re.sub(r'`([^`]+)`', r'<font name="Courier" size="8">\1</font>', text)
    # Emojis de semáforo → texto
    text = text.replace("⛔", "[CRÍTICO]")
    text = text.replace("🔴", "[ALTO]")
    text = text.replace("🟡", "[MEDIO]")
    text = text.replace("🟢", "[OK]")
    text = text.replace("❌", "[NO]")
    text = text.replace("✅", "[SÍ]")
    text = text.replace("⚠️", "[AVISO]")
    text = text.replace("ℹ️", "[INFO]")
    return text


def is_table_row(line: str) -> bool:
    return line.strip().startswith("|") and line.strip().endswith("|")


def is_separator_row(line: str) -> bool:
    return is_table_row(line) and re.match(r'^\|[-| :]+\|$', line.strip())


def parse_table(lines: list[str]) -> list[list[str]]:
    rows = []
    for line in lines:
        if is_separator_row(line):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        rows.append(cells)
    return rows


def build_table_flowable(rows: list[list[str]], styles: dict):
    if not rows:
        return None

    ncols = max(len(r) for r in rows)
    # Normalizar filas al mismo número de columnas
    norm = [r + [""] * (ncols - len(r)) for r in rows]

    # Primera fila como encabezado
    header = [Paragraph(inline_format(c), styles["table_header"]) for c in norm[0]]
    body = [
        [Paragraph(inline_format(c), styles["table_cell"]) for c in row]
        for row in norm[1:]
    ]

    data = [header] + body

    # Calcular anchos de columna
    available = PAGE_W - 2 * MARGIN
    col_w = available / ncols

    t = Table(data, colWidths=[col_w] * ncols, repeatRows=1)
    t.setStyle(TableStyle([
        # Encabezado
        ("BACKGROUND", (0, 0), (-1, 0), AZUL_FLUIX),
        ("TEXTCOLOR", (0, 0), (-1, 0), BLANCO),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, 0), 8.5),
        ("ALIGN", (0, 0), (-1, 0), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        # Cuerpo
        ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
        ("FONTSIZE", (0, 1), (-1, -1), 8.5),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [BLANCO, GRIS_CLARO]),
        # Bordes
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#CCCCCC")),
        ("LINEBELOW", (0, 0), (-1, 0), 1, AZUL_FLUIX),
        # Padding
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
    ]))
    return t


# ── Parser de Markdown ────────────────────────────────────────────────────────
def md_to_flowables(md_text: str, styles: dict) -> list:
    flowables = []
    lines = md_text.splitlines()
    i = 0
    in_code_block = False
    code_lines = []

    while i < len(lines):
        line = lines[i]

        # Bloque de código ```
        if line.strip().startswith("```"):
            if in_code_block:
                # Cerrar bloque
                if code_lines:
                    code_text = "\n".join(
                        l.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                        for l in code_lines
                    )
                    # Dividir en líneas individuales para evitar overflow
                    for cl in code_lines:
                        cl_safe = cl.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                        flowables.append(Paragraph(cl_safe or " ", styles["code"]))
                    flowables.append(Spacer(1, 4))
                code_lines = []
                in_code_block = False
            else:
                in_code_block = True
            i += 1
            continue

        if in_code_block:
            code_lines.append(line)
            i += 1
            continue

        # Línea horizontal ---
        if re.match(r'^---+\s*$', line):
            flowables.append(HRFlowable(
                width="100%", thickness=0.5,
                color=colors.HexColor("#CCCCCC"),
                spaceAfter=6, spaceBefore=6
            ))
            i += 1
            continue

        # Encabezados
        m = re.match(r'^(#{1,4})\s+(.*)', line)
        if m:
            level = len(m.group(1))
            text = inline_format(m.group(2))
            style_key = f"h{level}" if level <= 4 else "h4"
            # Añadir separador bajo H1 y H2
            if level == 1:
                flowables.append(PageBreak())
                flowables.append(Paragraph(text, styles["h1"]))
                flowables.append(HRFlowable(
                    width="100%", thickness=2,
                    color=AZUL_FLUIX, spaceAfter=8
                ))
            elif level == 2:
                flowables.append(Paragraph(text, styles["h2"]))
                flowables.append(HRFlowable(
                    width="100%", thickness=0.8,
                    color=AZUL_CLARO, spaceAfter=4
                ))
            else:
                flowables.append(Paragraph(text, styles[style_key]))
            i += 1
            continue

        # Tabla Markdown
        if is_table_row(line):
            table_lines = []
            while i < len(lines) and is_table_row(lines[i]):
                table_lines.append(lines[i])
                i += 1
            rows = parse_table(table_lines)
            tbl = build_table_flowable(rows, styles)
            if tbl:
                flowables.append(Spacer(1, 4))
                flowables.append(tbl)
                flowables.append(Spacer(1, 8))
            continue

        # Línea de lista - item
        m = re.match(r'^(\s*[-*+])\s+(.*)', line)
        if m:
            indent = len(m.group(1)) - len(m.group(1).lstrip())
            text = inline_format(m.group(2))
            bullet_style = ParagraphStyle(
                "bullet_dyn", parent=styles["bullet"],
                leftIndent=16 + indent * 8,
            )
            flowables.append(Paragraph(f"• {text}", bullet_style))
            i += 1
            continue

        # Línea de lista numerada
        m = re.match(r'^\s*(\d+)\.\s+(.*)', line)
        if m:
            num = m.group(1)
            text = inline_format(m.group(2))
            flowables.append(Paragraph(f"{num}. {text}", styles["bullet"]))
            i += 1
            continue

        # Línea vacía
        if not line.strip():
            flowables.append(Spacer(1, 6))
            i += 1
            continue

        # Párrafo normal
        text = inline_format(line.strip())
        if text:
            flowables.append(Paragraph(text, styles["normal"]))
        i += 1

    return flowables


# ── Portada ───────────────────────────────────────────────────────────────────
def build_cover_page(styles: dict) -> list:
    flowables = []
    flowables.append(Spacer(1, 3 * cm))

    # Logo / nombre empresa
    flowables.append(Paragraph(
        "FLUIX TECH, S.L.",
        ParagraphStyle(
            "cover_company", fontName="Helvetica-Bold", fontSize=22,
            textColor=AZUL_FLUIX, alignment=TA_CENTER, spaceAfter=6,
        )
    ))

    flowables.append(HRFlowable(
        width="80%", thickness=2, color=AZUL_FLUIX,
        spaceAfter=20, spaceBefore=10
    ))

    # Título
    flowables.append(Paragraph(
        "Análisis Técnico de Publicación",
        ParagraphStyle(
            "cover_title", fontName="Helvetica-Bold", fontSize=28,
            textColor=AZUL_FLUIX, alignment=TA_CENTER, spaceAfter=8,
        )
    ))

    flowables.append(Paragraph(
        "Fluix CRM v1.0.18",
        ParagraphStyle(
            "cover_subtitle", fontName="Helvetica", fontSize=16,
            textColor=AZUL_CLARO, alignment=TA_CENTER, spaceAfter=4,
        )
    ))

    flowables.append(Spacer(1, 1.5 * cm))

    # Plataformas
    flowables.append(Paragraph(
        "iOS · Android · Windows",
        ParagraphStyle(
            "cover_platforms", fontName="Helvetica-Oblique", fontSize=13,
            textColor=GRIS_MEDIO, alignment=TA_CENTER,
        )
    ))

    flowables.append(Spacer(1, 4 * cm))

    # Recuadro de datos
    info_data = [
        ["Fecha", date.today().strftime("%d de %B de %Y")],
        ["Firebase Project", "planeaapp-4bea4 (europe-west1)"],
        ["Flutter SDK", "^3.11.1"],
        ["Módulos analizados", "Web + Nazarí, Fichajes, Empleados, Clientes, Facturación, Modelos AEAT"],
        ["Clasificación", "Uso interno — confidencial"],
    ]

    info_style_key = ParagraphStyle(
        "info_key", fontName="Helvetica-Bold", fontSize=9,
        textColor=AZUL_FLUIX,
    )
    info_style_val = ParagraphStyle(
        "info_val", fontName="Helvetica", fontSize=9,
        textColor=GRIS_OSCURO,
    )

    info_rows = [
        [Paragraph(k, info_style_key), Paragraph(v, info_style_val)]
        for k, v in info_data
    ]

    info_table = Table(info_rows, colWidths=[4 * cm, 11 * cm])
    info_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), GRIS_CLARO),
        ("LINEBELOW", (0, 0), (-1, -2), 0.3, colors.HexColor("#DDDDDD")),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("BOX", (0, 0), (-1, -1), 0.5, AZUL_FLUIX),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    flowables.append(info_table)

    flowables.append(PageBreak())
    return flowables


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    print(f"Leyendo: {INPUT_MD}")
    md_text = INPUT_MD.read_text(encoding="utf-8")

    # Quitar el bloque de índice (## Índice ... primer encabezado real)
    # Se incluye como la primera sección del informe tal cual
    styles = make_styles()

    doc = SimpleDocTemplate(
        str(OUTPUT_PDF),
        pagesize=A4,
        leftMargin=MARGIN,
        rightMargin=MARGIN,
        topMargin=MARGIN,
        bottomMargin=2 * cm,
        title="Fluix CRM — Análisis Técnico de Publicación",
        author="Fluix Tech, S.L.",
        subject="Análisis técnico multiplataforma iOS/Android/Windows",
    )

    story = []

    # Portada
    story.extend(build_cover_page(styles))

    # Contenido del markdown (salta el H1 principal que ya está en portada)
    lines = md_text.splitlines()
    # Saltar la primera línea H1 y la línea de subtítulo si es la portada
    start = 0
    for idx, line in enumerate(lines):
        if line.startswith("# ") and idx > 0:
            start = idx
            break

    content_md = "\n".join(lines[start:])
    story.extend(md_to_flowables(content_md, styles))

    print(f"Generando PDF: {OUTPUT_PDF}")
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"OK PDF generado correctamente: {OUTPUT_PDF}")
    print(f"  Tamaño: {OUTPUT_PDF.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()

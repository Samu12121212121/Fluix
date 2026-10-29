"""
generar_fichas_depilacion_gdl.py
Genera fichas Fluix para los centros de depilacion laser de Guadalajara
(+ El Casar y Azuqueca de Henares) extraidos de mejoresclinicas.net
"""

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import os

OUTPUT_DIR = r"C:\Users\Samu\Downloads\fichas_guadalajara"
os.makedirs(OUTPUT_DIR, exist_ok=True)

HDR_FILL   = PatternFill("solid", fgColor="1F3864")
HDR_FONT   = Font(bold=True, color="FFFFFF", size=11)
LABEL_FILL = PatternFill("solid", fgColor="D6E4F7")
LABEL_FONT = Font(bold=True, color="1F3864", size=10)
NOTE_FILL  = PatternFill("solid", fgColor="FFF2CC")
NOTE_FONT  = Font(color="7F6000", size=9, italic=True)
BODY_FONT  = Font(size=10)
THIN       = Side(style="thin", color="BFBFBF")
BORDER     = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)
WRAP       = Alignment(wrap_text=True, vertical="top")
CENTER     = Alignment(horizontal="center", vertical="center", wrap_text=True)


def hdr(ws, row, col, text):
    c = ws.cell(row=row, column=col, value=text)
    c.fill, c.font, c.alignment, c.border = HDR_FILL, HDR_FONT, CENTER, BORDER

def label(ws, row, text):
    c = ws.cell(row=row, column=1, value=text)
    c.fill, c.font, c.alignment, c.border = LABEL_FILL, LABEL_FONT, WRAP, BORDER

def val(ws, row, text):
    c = ws.cell(row=row, column=2, value=text)
    c.font, c.alignment, c.border = BODY_FONT, WRAP, BORDER

def note(ws, row, text):
    c = ws.cell(row=row, column=3, value=text)
    c.fill, c.font, c.alignment, c.border = NOTE_FILL, NOTE_FONT, WRAP, BORDER

def set_col_widths(ws, widths):
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w


def add_info_sheet(wb, b):
    ws = wb.active
    ws.title = "Info"
    hdr(ws, 1, 1, "CAMPO"); hdr(ws, 1, 2, "VALOR"); hdr(ws, 1, 3, "ESTADO / NOTAS")
    rows = [
        ("Nombre del negocio",  b["nombre"],        "Confirmado en directorio"),
        ("Slogan / Tagline",    b.get("slogan",""),  "Propuesta; confirmar con el negocio"),
        ("Descripcion",         b["descripcion"],    "Redaccion a partir de directorio"),
        ("Categoria",           b["categoria"],      "Enum CategoriaNegocio"),
        ("Precio medio",        b.get("precio",""),  "No publicado de forma verificable"),
        ("Especialidades",      b["especialidades"], "Servicios anunciados en directorio"),
        ("Rating de Google",    f"{b['rating']}/5 ({b['resenas']} resenas, fuente directorio)", "Verificar en Google antes de guardar"),
        ("Numero de resenas",   str(b["resenas"]),   "Dato de directorio externo"),
        ("Google Place ID",     "",                  "No localizado/verificado"),
    ]
    for i, (campo, valor, estado) in enumerate(rows, 2):
        label(ws, i, campo); val(ws, i, valor); note(ws, i, estado)
        ws.row_dimensions[i].height = 36 if "Descripcion" in campo or "Especialidades" in campo else 20
    set_col_widths(ws, [28, 55, 45])


def add_contacto_sheet(wb, b):
    ws = wb.create_sheet("Contacto")
    hdr(ws, 1, 1, "CAMPO"); hdr(ws, 1, 2, "VALOR"); hdr(ws, 1, 3, "ESTADO / NOTAS")
    maps_url = (
        "https://www.google.com/maps/search/?api=1&query="
        + b["direccion"].replace(" ", "+").replace(",", "%2C")
    )
    rows = [
        ("Direccion",              b["direccion"],          "Confirmado"),
        ("Telefono",               b["telefono"],           "Confirmado en directorio"),
        ("WhatsApp",               b.get("whatsapp",""),    "Verificar"),
        ("Email publico",          b.get("email",""),       "No publicado/verificado"),
        ("Email notificaciones",   b.get("email",""),       "Propuesta provisional"),
        ("Pagina web",             b.get("web",""),         "Confirmar que esta activa"),
        ("Instagram",              b.get("instagram",""),   "No localizado/verificado"),
        ("Facebook",               b.get("facebook",""),   "No localizado/verificado"),
        ("URL Google Maps",        maps_url,                "Enlace de busqueda por direccion"),
    ]
    for i, (campo, valor, estado) in enumerate(rows, 2):
        label(ws, i, campo); val(ws, i, valor); note(ws, i, estado)
        ws.row_dimensions[i].height = 20
    set_col_widths(ws, [28, 55, 45])


def add_horario_sheet(wb, b):
    ws = wb.create_sheet("Horario")
    cols = ["DIA","ABIERTO","FRANJA 1 APERTURA","FRANJA 1 CIERRE","FRANJA 2 APERTURA","FRANJA 2 CIERRE","NOTAS"]
    for j, c in enumerate(cols, 1):
        hdr(ws, 1, j, c)
    for i, fila in enumerate(b["horario"], 2):
        for j, v in enumerate(fila, 1):
            cell = ws.cell(row=i, column=j, value=v)
            cell.font, cell.alignment, cell.border = BODY_FONT, WRAP, BORDER
        ws.row_dimensions[i].height = 18
    set_col_widths(ws, [14, 10, 20, 20, 20, 20, 38])


def add_servicios_sheet(wb, b):
    ws = wb.create_sheet("Servicios")
    cols = ["NOMBRE DEL SERVICIO","DESCRIPCION","CATEGORIA","PRECIO","MODALIDAD PRECIO",
            "DURACION MIN","PUBLICO","ACTIVO","FOTO","ESTADO / NOTAS"]
    for j, c in enumerate(cols, 1):
        hdr(ws, 1, j, c)
    nota = "Servicio anunciado en directorio; precio y duracion no publicados/verificados"
    for i, srv in enumerate(b["servicios"], 2):
        valores = [srv.get("nombre",""), "", srv.get("categoria",""), None, "Por definir", None, "General", "Si", None, nota]
        for j, v in enumerate(valores, 1):
            cell = ws.cell(row=i, column=j, value=v)
            cell.font   = NOTE_FONT if j == 10 else BODY_FONT
            cell.fill   = NOTE_FILL if j == 10 else PatternFill()
            cell.alignment, cell.border = WRAP, BORDER
        ws.row_dimensions[i].height = 18
    set_col_widths(ws, [32, 28, 22, 10, 16, 14, 10, 8, 8, 48])


def add_extras_sheet(wb, b):
    ws = wb.create_sheet("Extras")
    hdr(ws, 1, 1, "CAMPO"); hdr(ws, 1, 2, "VALOR"); hdr(ws, 1, 3, "ESTADO / NOTAS")
    rows = [
        ("Empresa vinculada",          "",            "Seleccionar desde Fluix"),
        ("Negocio destacado",          "No definido", "Decision interna"),
        ("Reservas online activadas",  "Por verificar","Comprobar antes de activar"),
        ("Acepta tarjeta",             "",            "No verificado"),
        ("Parking",                    "",            "No verificado"),
        ("Accesible en silla de ruedas","",           "No verificado"),
        ("WiFi",                       "",            "No verificado"),
        ("Admite mascotas",            "",            "No verificado"),
        ("Terraza",                    "No aplica",   "No verificado"),
        ("Eliminar negocio",           "No ejecutar", "Accion destructiva"),
    ]
    for i, (campo, valor, estado) in enumerate(rows, 2):
        label(ws, i, campo); val(ws, i, valor); note(ws, i, estado)
        ws.row_dimensions[i].height = 18
    set_col_widths(ws, [28, 30, 45])


def add_formulario_sheet(wb, b):
    ws = wb.create_sheet("Formulario")
    hdr(ws, 1, 1, "CAMPO"); hdr(ws, 1, 2, "VALOR SUGERIDO"); hdr(ws, 1, 3, "ESTADO / NOTAS")
    rows = [
        ("Titulo del formulario",  f"Pide tu cita en {b['nombre']}", "Adaptar al CTA del negocio"),
        ("Texto del boton",        "Pedir cita",                      ""),
        ("Nombre",                 "Texto; obligatorio",              ""),
        ("Telefono",               "Telefono; obligatorio",           ""),
        ("Email",                  "Email; opcional",                 ""),
        ("Servicio de interes",    "Desplegable; opcional",           ""),
        ("Fecha preferida",        "Fecha; opcional",                 ""),
        ("Hora preferida",         "Hora; opcional",                  ""),
        ("Mensaje",                "Parrafo; opcional",               ""),
    ]
    for i, (campo, valor, estado) in enumerate(rows, 2):
        label(ws, i, campo); val(ws, i, valor); note(ws, i, estado)
        ws.row_dimensions[i].height = 18
    set_col_widths(ws, [28, 35, 45])


def add_fuentes_sheet(wb, b):
    ws = wb.create_sheet("Fuentes")
    hdr(ws, 1, 1, "FUENTE"); hdr(ws, 1, 2, "URL"); hdr(ws, 1, 3, "INFORMACION EXTRAIDA")
    rows = [
        ("Directorio mejoresclinicas.net", b["fuente_url"],
         "Nombre, direccion, telefono, horario, rating, resenas, servicios"),
    ]
    if b.get("web"):
        rows.append(("Web oficial (no verificada)", b["web"], "Pendiente de verificar"))
    rows.append(("PENDIENTE DE VERIFICAR", "",
                 "Web oficial, Google Place ID, email, redes sociales, precios, accesibilidad"))
    for i, (fuente, url, info) in enumerate(rows, 2):
        label(ws, i, fuente); val(ws, i, url); note(ws, i, info)
        ws.row_dimensions[i].height = 20
    set_col_widths(ws, [30, 60, 50])


def crear_excel(b):
    wb = openpyxl.Workbook()
    add_info_sheet(wb, b)
    add_contacto_sheet(wb, b)
    add_horario_sheet(wb, b)
    add_servicios_sheet(wb, b)
    add_extras_sheet(wb, b)
    add_formulario_sheet(wb, b)
    add_fuentes_sheet(wb, b)
    slug = (b["nombre"].lower()
        .replace(" ", "_").replace("/","").replace("!","")
        .replace("a","a").replace("e","e").replace("i","i")
        .replace("o","o").replace("u","u").replace("n","n")
        .replace(".","").replace(",",""))
    path = os.path.join(OUTPUT_DIR, f"{slug}_ficha_fluix.xlsx")
    wb.save(path)
    print(f"OK {b['nombre']}  ->  {path}")


NEGOCIOS = [
    {
        "nombre": "LC Depilacion Laser",
        "slogan": "Depilacion laser con los mejores resultados",
        "descripcion": "Centro especializado en depilacion laser ubicado en el barrio de Amistad, Guadalajara. Uno de los centros mejor valorados de la zona con horario ampliado de 9:15 a 21:00.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser",
        "precio": "",
        "rating": "5.0",
        "resenas": 24,
        "direccion": "C. Wenceslao Argumosa, 5, 19003 Guadalajara",
        "telefono": "949 25 57 14",
        "whatsapp": "949 25 57 14",
        "email": "",
        "web": "https://www.laserbolinia.com",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "Si", "09:15", "21:00", "", "", "Continuo"),
            ("Martes",    "Si", "09:15", "21:00", "", "", "Continuo"),
            ("Miercoles", "Si", "09:15", "21:00", "", "", "Continuo"),
            ("Jueves",    "Si", "09:15", "21:00", "", "", "Continuo"),
            ("Viernes",   "Si", "09:00", "21:00", "", "", "Continuo"),
            ("Sabado",    "No", "",       "",      "", "", "Cerrado"),
            ("Domingo",   "No", "",       "",      "", "", "Cerrado"),
        ],
        "servicios": [
            {"nombre": "Depilacion laser", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinica/lc-depilacion-laser/",
    },
    {
        "nombre": "ALAN DEPILACION LASER",
        "slogan": "Resultados excelentes sin dolor",
        "descripcion": "Centro especializado en depilacion laser facial y corporal ubicado en el barrio Centro de Guadalajara. Reconocido por sus resultados excelentes y atencion personalizada.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser facial y corporal, tratamiento de vello hormonal",
        "precio": "",
        "rating": "5.0",
        "resenas": 28,
        "direccion": "C. Miguel Fluiters, 45, 19001 Guadalajara",
        "telefono": "642 29 47 20",
        "whatsapp": "642 29 47 20",
        "email": "",
        "web": "",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "Si", "10:00", "19:00", "", "", "Continuo"),
            ("Martes",    "Si", "10:00", "19:00", "", "", "Continuo"),
            ("Miercoles", "Si", "10:00", "19:00", "", "", "Continuo"),
            ("Jueves",    "Si", "10:00", "19:00", "", "", "Continuo"),
            ("Viernes",   "Si", "10:00", "19:00", "", "", "Continuo"),
            ("Sabado",    "Si", "10:00", "19:00", "", "", "Continuo"),
            ("Domingo",   "No", "",       "",      "", "", "Cerrado"),
        ],
        "servicios": [
            {"nombre": "Depilacion laser facial",    "categoria": "Depilacion"},
            {"nombre": "Depilacion laser corporal",  "categoria": "Depilacion"},
            {"nombre": "Tratamiento vello hormonal", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinica/alan-depilacion-laser/",
    },
    {
        "nombre": "Centro Rubi",
        "slogan": "Depilacion laser con la mejor relacion calidad-precio",
        "descripcion": "Centro especializado en depilacion laser ubicado en el barrio Centro de Guadalajara. Destacado por su trato profesional y sus precios muy asequibles.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser",
        "precio": "Asequible segun resenas; precio exacto no publicado",
        "rating": "5.0",
        "resenas": 34,
        "direccion": "Pl. Virgen de la Antigua, 5, 19001 Guadalajara",
        "telefono": "622 84 84 60",
        "whatsapp": "622 84 84 60",
        "email": "",
        "web": "https://www.centrosrubi.com",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Martes",    "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Miercoles", "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Jueves",    "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Viernes",   "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Sabado",    "Si", "10:00", "14:00", "", "", "Solo manana"),
            ("Domingo",   "No", "",       "",      "", "", "Cerrado"),
        ],
        "servicios": [
            {"nombre": "Depilacion laser", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinica/centro-rubi/",
    },
    {
        "nombre": "Laserya",
        "slogan": "Depilacion laser y estetica en El Casar",
        "descripcion": "Centro especializado en depilacion laser y estetica ubicado en El Casar, Guadalajara. Ofrece ademas manicura, tratamientos corporales y lifting de pestanas.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser, manicura, tratamientos corporales, lifting de pestanas, limpieza facial",
        "precio": "Lifting pestanas ~35-40 euros",
        "rating": "5.0",
        "resenas": 190,
        "direccion": "C. el Salto, 13, 19170 El Casar, Guadalajara",
        "telefono": "949 41 03 27",
        "whatsapp": "949 41 03 27",
        "email": "",
        "web": "https://www.laserya.es",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Martes",    "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Miercoles", "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Jueves",    "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Viernes",   "Si", "10:00", "20:00", "", "", "Continuo"),
            ("Sabado",    "Si", "10:00", "13:30", "", "", "Solo manana"),
            ("Domingo",   "No", "",       "",      "", "", "Cerrado"),
        ],
        "servicios": [
            {"nombre": "Depilacion laser",       "categoria": "Depilacion"},
            {"nombre": "Manicura",               "categoria": "Estilo personal"},
            {"nombre": "Tratamientos corporales","categoria": "Belleza corporal"},
            {"nombre": "Lifting de pestanas",    "categoria": "Diseno de la mirada"},
            {"nombre": "Limpieza facial",        "categoria": "Belleza facial"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinica/laserya/",
    },
    {
        "nombre": "Laser Azuqueca",
        "slogan": "Depilacion laser diodo en Azuqueca de Henares",
        "descripcion": "Centro especializado en depilacion laser diodo ubicado en Azuqueca de Henares, Guadalajara. Horario amplio de lunes a viernes de 9:00 a 21:00.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser diodo",
        "precio": "",
        "rating": "4.9",
        "resenas": 80,
        "direccion": "C. la Victoria, 4, 19200 Azuqueca de Henares, Guadalajara",
        "telefono": "641 13 60 50",
        "whatsapp": "641 13 60 50",
        "email": "",
        "web": "https://www.laserazuqueca.es",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "Si", "09:00", "21:00", "", "", "Continuo"),
            ("Martes",    "Si", "09:00", "21:00", "", "", "Continuo"),
            ("Miercoles", "Si", "09:00", "21:00", "", "", "Continuo"),
            ("Jueves",    "Si", "09:00", "21:00", "", "", "Continuo"),
            ("Viernes",   "Si", "09:00", "21:00", "", "", "Continuo"),
            ("Sabado",    "Si", "09:00", "14:00", "", "", "Solo manana"),
            ("Domingo",   "No", "",       "",      "", "", "Cerrado"),
        ],
        "servicios": [
            {"nombre": "Depilacion laser diodo", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinica/laser-azuqueca/",
    },
    {
        "nombre": "Laserum Guadalajara",
        "slogan": "Depilacion laser diodo con resultados desde la primera sesion",
        "descripcion": "Franquicia especializada en depilacion laser diodo ubicada en el barrio de Amistad, Guadalajara. Con 1.721 resenas en Google, es uno de los centros mas valorados de la ciudad.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser diodo, protocolo de seguridad e higiene certificado",
        "precio": "",
        "rating": "4.9",
        "resenas": 1721,
        "direccion": "C. Manuel Paez Xaramillo, 4, 19002 Guadalajara",
        "telefono": "664 23 71 30",
        "whatsapp": "664 23 71 30",
        "email": "",
        "web": "https://www.laserum.com",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "Si", "10:00", "20:00", "",      "",      "Continuo"),
            ("Martes",    "Si", "10:00", "14:00", "16:00", "20:00", ""),
            ("Miercoles", "Si", "10:00", "14:00", "16:00", "20:00", ""),
            ("Jueves",    "Si", "10:00", "14:00", "16:00", "20:00", ""),
            ("Viernes",   "Si", "10:00", "20:00", "",      "",      "Continuo"),
            ("Sabado",    "Si", "10:00", "14:00", "",      "",      "Solo manana"),
            ("Domingo",   "No", "",       "",      "",      "",      "Cerrado"),
        ],
        "servicios": [
            {"nombre": "Depilacion laser diodo", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinica/laserum-guadalajara/",
    },
    {
        "nombre": "SinVello! Guadalajara",
        "slogan": "Depilacion laser de cuerpo completo",
        "descripcion": "Centro especializado en depilacion laser diodo ubicado en el barrio de Amistad, Guadalajara. Con 564 resenas en Google y horario ampliado incluyendo sabados.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser diodo de cuerpo completo",
        "precio": "",
        "rating": "4.9",
        "resenas": 564,
        "direccion": "C. Felipe Solano Antelo, 19, 19002 Guadalajara",
        "telefono": "604 90 14 76",
        "whatsapp": "604 90 14 76",
        "email": "",
        "web": "https://www.sinvelloporlaser.es",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "Si", "09:30", "14:30", "15:00", "21:00", ""),
            ("Martes",    "Si", "09:30", "14:30", "15:00", "21:00", ""),
            ("Miercoles", "Si", "09:30", "14:30", "15:00", "21:00", ""),
            ("Jueves",    "Si", "09:30", "14:30", "15:00", "21:00", ""),
            ("Viernes",   "Si", "09:30", "14:30", "15:00", "21:00", ""),
            ("Sabado",    "Si", "10:00", "14:00", "",      "",      "Solo manana"),
            ("Domingo",   "No", "",       "",      "",      "",      "Cerrado"),
        ],
        "servicios": [
            {"nombre": "Depilacion laser diodo cuerpo completo", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinica/sinvello-guadalajara/",
    },
    {
        "nombre": "Elha Laser Center Guadalajara",
        "slogan": "Depilacion laser profesional",
        "descripcion": "Franquicia especializada en depilacion laser con sede en Guadalajara (Av. de Francia, 12). Cadena con presencia nacional.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser",
        "precio": "",
        "rating": "4.9",
        "resenas": 133,
        "direccion": "Av. de Francia, 12, 19005 Guadalajara",
        "telefono": "872 55 06 20",
        "whatsapp": "",
        "email": "",
        "web": "https://www.elhadepilacionlaser.com",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "?", "", "", "", "", "Horario pendiente de verificar en esta sede"),
            ("Martes",    "?", "", "", "", "", ""),
            ("Miercoles", "?", "", "", "", "", ""),
            ("Jueves",    "?", "", "", "", "", ""),
            ("Viernes",   "?", "", "", "", "", ""),
            ("Sabado",    "?", "", "", "", "", ""),
            ("Domingo",   "?", "", "", "", "", ""),
        ],
        "servicios": [
            {"nombre": "Depilacion laser", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinicas-depilacion-laser/guadalajara/",
    },
    {
        "nombre": "White Lotus",
        "slogan": "Depilacion laser en Entrepeñas",
        "descripcion": "Centro de depilacion laser ubicado en el bulevar Clara Campoamor, Guadalajara (barrio Aguas Vivas). Datos de directorio; pagina individual no disponible.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser",
        "precio": "",
        "rating": "4.9",
        "resenas": 57,
        "direccion": "Blvr. Clara Campoamor, 31, 19005 Guadalajara",
        "telefono": "624 05 20 79",
        "whatsapp": "",
        "email": "",
        "web": "",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "?", "", "", "", "", "Horario pendiente de verificar"),
            ("Martes",    "?", "", "", "", "", ""),
            ("Miercoles", "?", "", "", "", "", ""),
            ("Jueves",    "?", "", "", "", "", ""),
            ("Viernes",   "?", "", "", "", "", ""),
            ("Sabado",    "?", "", "", "", "", ""),
            ("Domingo",   "?", "", "", "", "", ""),
        ],
        "servicios": [
            {"nombre": "Depilacion laser", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinicas-depilacion-laser/guadalajara/",
    },
    {
        "nombre": "Grupostop ECI Guadalajara",
        "slogan": "Depilacion laser en El Corte Ingles de Guadalajara",
        "descripcion": "Centro de depilacion laser Grupostop ubicado en El Corte Ingles de Guadalajara. Cadena con presencia nacional. Horario amplio de lunes a sabado.",
        "categoria": "Depilacion laser",
        "especialidades": "Depilacion laser (indoloro y eficaz)",
        "precio": "",
        "rating": "3.9",
        "resenas": 259,
        "direccion": "Av. Eduardo Guitian, El Corte Ingles, Guadalajara",
        "telefono": "949 87 19 11",
        "whatsapp": "",
        "email": "",
        "web": "https://www.grupostop.com",
        "instagram": "",
        "facebook": "",
        "horario": [
            ("Lunes",     "Si", "10:00", "22:00", "", "", "Continuo"),
            ("Martes",    "Si", "10:00", "22:00", "", "", "Continuo"),
            ("Miercoles", "Si", "10:00", "22:00", "", "", "Continuo"),
            ("Jueves",    "Si", "10:00", "22:00", "", "", "Continuo"),
            ("Viernes",   "Si", "10:00", "22:00", "", "", "Continuo"),
            ("Sabado",    "Si", "10:00", "22:00", "", "", "Continuo"),
            ("Domingo",   "No", "",       "",      "", "", "Cerrado"),
        ],
        "servicios": [
            {"nombre": "Depilacion laser", "categoria": "Depilacion"},
        ],
        "fuente_url": "https://mejoresclinicas.net/clinicas-depilacion-laser/guadalajara/",
    },
]

print(f"\n{'='*60}")
print(f"  Generando fichas depilacion laser -- {len(NEGOCIOS)} negocios")
print(f"  Destino: {OUTPUT_DIR}")
print(f"{'='*60}\n")

for negocio in NEGOCIOS:
    crear_excel(negocio)

print(f"\n{'='*60}")
print(f"  {len(NEGOCIOS)} fichas generadas en {OUTPUT_DIR}")
print(f"{'='*60}\n")

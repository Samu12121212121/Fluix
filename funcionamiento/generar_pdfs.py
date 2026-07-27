"""
Genera PDFs de documentacion tecnica de Fluix CRM.
Uso: python generar_pdfs.py
Salida: funcionamiento/pdf/*.pdf
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, KeepTogether
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER
import os

OUT = os.path.join(os.path.dirname(__file__), "pdf")
os.makedirs(OUT, exist_ok=True)

# ─────────────────────────── COLORES FLUIX ───────────────────────────────────
AZUL     = colors.HexColor("#1565C0")
AZUL_CLR = colors.HexColor("#E3F0FF")
GRIS     = colors.HexColor("#F5F7FA")
GRIS_OSC = colors.HexColor("#64748B")
NEGRO    = colors.HexColor("#1E293B")
VERDE    = colors.HexColor("#059669")
ROJO     = colors.HexColor("#DC2626")
AMBER    = colors.HexColor("#D97706")

# ─────────────────────────── ESTILOS ─────────────────────────────────────────
def estilos():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle("FluixH1",   fontName="Helvetica-Bold", textColor=AZUL,    fontSize=20, leading=24, spaceAfter=6))
    s.add(ParagraphStyle("FluixH2",   fontName="Helvetica-Bold", textColor=NEGRO,   fontSize=14, leading=18, spaceAfter=4, spaceBefore=12))
    s.add(ParagraphStyle("FluixH3",   fontName="Helvetica-Bold", textColor=AZUL,    fontSize=11, leading=14, spaceAfter=3, spaceBefore=8))
    s.add(ParagraphStyle("FluixBody", fontName="Helvetica",       textColor=NEGRO,   fontSize=9,  leading=13, spaceAfter=3))
    s.add(ParagraphStyle("FluixSub",  fontName="Helvetica",       textColor=GRIS_OSC,fontSize=8,  leading=12))
    s.add(ParagraphStyle("FluixCode", fontName="Courier",          textColor=NEGRO,   fontSize=8,  leading=11, backColor=GRIS, leftIndent=6, rightIndent=6, spaceBefore=2, spaceAfter=2))
    s.add(ParagraphStyle("FluixBullet",fontName="Helvetica",       textColor=NEGRO,   fontSize=9,  leading=13, leftIndent=14, bulletIndent=4, spaceAfter=2))
    s.add(ParagraphStyle("FluixCenter",fontName="Helvetica",       textColor=NEGRO,   fontSize=9,  leading=13, alignment=TA_CENTER))
    return s

ST = estilos()

# ─────────────────────────── HELPERS ─────────────────────────────────────────
def h1(t):   return Paragraph(t, ST["FluixH1"])
def h2(t):   return Paragraph(t, ST["FluixH2"])
def h3(t):   return Paragraph(t, ST["FluixH3"])
def p(t):    return Paragraph(t, ST["FluixBody"])
def sub(t):  return Paragraph(t, ST["FluixSub"])
def code(t): return Paragraph(t, ST["FluixCode"])
def sp(n=6): return Spacer(1, n)
def hr():    return HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#CBD5E1"), spaceAfter=4, spaceBefore=4)

def bul(items, color=AZUL):
    return [Paragraph(f"<bullet>&bull;</bullet> {i}", ST["FluixBullet"]) for i in items]

def tabla(data, col_widths=None, header=True):
    t = Table(data, colWidths=col_widths, repeatRows=1 if header else 0)
    style = [
        ("BACKGROUND",  (0,0), (-1,0), AZUL),
        ("TEXTCOLOR",   (0,0), (-1,0), colors.white),
        ("FONTNAME",    (0,0), (-1,0), "Helvetica-Bold"),
        ("FONTSIZE",    (0,0), (-1,-1), 8),
        ("ROWBACKGROUNDS", (0,1), (-1,-1), [colors.white, GRIS]),
        ("GRID",        (0,0), (-1,-1), 0.4, colors.HexColor("#CBD5E1")),
        ("TOPPADDING",  (0,0), (-1,-1), 4),
        ("BOTTOMPADDING",(0,0),(-1,-1), 4),
        ("LEFTPADDING", (0,0), (-1,-1), 5),
        ("VALIGN",      (0,0), (-1,-1), "TOP"),
    ]
    t.setStyle(TableStyle(style))
    return t

def badge(texto, color=AZUL):
    data = [[Paragraph(f"<b>{texto}</b>", ParagraphStyle("bg", fontName="Helvetica-Bold",
             fontSize=8, textColor=colors.white, alignment=TA_CENTER))]]
    t = Table(data, colWidths=[3*cm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,-1), color),
        ("ROUNDEDCORNERS", [4]),
        ("TOPPADDING", (0,0), (-1,-1), 3),
        ("BOTTOMPADDING", (0,0), (-1,-1), 3),
    ]))
    return t

def diagrama_flujo(pasos, color=AZUL):
    """Genera un diagrama de flujo simple como tabla vertical."""
    rows = []
    for i, paso in enumerate(pasos):
        rows.append([
            Paragraph(f"<b>{i+1}</b>", ParagraphStyle("num", fontName="Helvetica-Bold",
                       fontSize=9, textColor=colors.white, alignment=TA_CENTER)),
            Paragraph(paso, ST["FluixBody"])
        ])
        if i < len(pasos)-1:
            rows.append(["", Paragraph("▼", ParagraphStyle("arr", fontSize=8, textColor=GRIS_OSC))])
    t = Table(rows, colWidths=[0.7*cm, 14*cm])
    style = []
    for i in range(0, len(rows), 2):
        style.append(("BACKGROUND", (0,i), (0,i), color))
        style.append(("ROUNDEDCORNERS", [3]))
    t.setStyle(TableStyle([
        ("FONTSIZE", (0,0), (-1,-1), 8),
        ("TOPPADDING", (0,0), (-1,-1), 3),
        ("BOTTOMPADDING", (0,0), (-1,-1), 3),
        ("LEFTPADDING", (0,0), (-1,-1), 4),
        ("VALIGN", (0,0), (-1,-1), "MIDDLE"),
        *style,
    ]))
    return t

def cabecera_modulo(nombre, descripcion, estado="Producción", color=AZUL):
    data = [[
        Paragraph(f"<b>{nombre}</b>", ParagraphStyle("cn", fontName="Helvetica-Bold",
                   fontSize=16, textColor=colors.white)),
        Paragraph(f"<font color='white'>{descripcion}</font><br/>"
                  f"<font size='7' color='#B3D4FF'>Fluix CRM · Estado: {estado}</font>",
                  ParagraphStyle("cd", fontName="Helvetica", fontSize=9, textColor=colors.white))
    ]]
    t = Table(data, colWidths=[5*cm, 11*cm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,-1), color),
        ("TOPPADDING", (0,0), (-1,-1), 10),
        ("BOTTOMPADDING", (0,0), (-1,-1), 10),
        ("LEFTPADDING", (0,0), (-1,-1), 8),
        ("VALIGN", (0,0), (-1,-1), "MIDDLE"),
    ]))
    return t

def pie():
    return [
        sp(4), hr(),
        sub("Fluix CRM · Documentación técnica interna · Generado automáticamente"),
    ]

def build(filename, contenido):
    path = os.path.join(OUT, filename)
    doc = SimpleDocTemplate(path, pagesize=A4,
                            leftMargin=1.8*cm, rightMargin=1.8*cm,
                            topMargin=1.5*cm, bottomMargin=1.5*cm)
    doc.build(contenido + pie())
    print(f"  OK  {filename}")

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 01 — DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_dashboard():
    c = [
        cabecera_modulo("Dashboard", "Panel central de control — hub de toda la app"),
        sp(10),
        h2("¿Qué es?"),
        p("El Dashboard es la pantalla principal tras el login. Agrega información de todos los "
          "módulos en un panel configurable con widgets dinámicos. Adapta su contenido según "
          "el rol del usuario y los módulos contratados en la suscripción."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["features/dashboard/pantallas/", "Pantallas del dashboard"],
            ["widgets/grid_modulos.dart", "Grid de acceso a módulos (filtrado por suscripción)"],
            ["widgets/cabecera_dashboard.dart", "Header con logo, notificaciones y acciones"],
            ["widgets/briefing_card.dart", "Resumen del día (reservas, tareas, ventas)"],
            ["widgets/reserva_card_mejorada.dart", "Próxima reserva del día"],
            ["widgets/skeleton_loaders.dart", "Animaciones de carga"],
            ["widgets/offline_banner.dart", "Banner de modo sin conexión"],
            ["widgets/configuracion_modulos.dart", "Editor drag-and-drop del panel"],
            ["widgets/kpis_rating_widget.dart", "KPIs de satisfacción de clientes"],
            ["widgets/grafico_evolucion_rating_widget.dart", "Gráfico de evolución de valoraciones"],
            ["widgets/estado_respuesta_widget.dart", "Estado respuestas Google Business"],
            ["widgets/widget_cobertura_resumen.dart", "Cobertura de turnos de empleados"],
            ["widgets/boton_recalcular_estadisticas.dart", "Recálculo manual de métricas"],
            ["providers/provider_dashboard.dart", "ChangeNotifier — estado global del dashboard"],
            ["pantallas/tab_blog_web.dart", "Tab de gestión del blog integrado"],
            ["pantallas/tab_seo_web.dart", "Tab de SEO de la web pública"],
            ["pantallas/conectar_google_business_screen.dart", "OAuth2 para conectar GMB"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Flujo de carga"),
        diagrama_flujo([
            "Login exitoso → se inicializa provider_dashboard.dart",
            "Se abre stream en tiempo real a empresas/{id}/estadisticas/resumen",
            "skeleton_loaders.dart muestra animaciones mientras llegan los datos",
            "grid_modulos.dart lee módulos habilitados de configuracion/modulos + suscripcion",
            "Módulos sin pack activo aparecen con candado → click lleva a pantalla de upgrade",
            "briefing_card.dart agrega: reservas del día, tareas vencidas, alertas de stock",
            "Los widgets se muestran en el orden configurado por el propietario",
        ]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/estadisticas/resumen", "KPIs del día (ventas, reservas, rating)"],
            ["empresas/{id}/estadisticas/web_resumen", "Analytics de la web pública"],
            ["empresas/{id}/estadisticas/historico_diario", "Evolución histórica por día"],
            ["empresas/{id}/configuracion/modulos", "Módulos habilitados y su orden"],
            ["empresas/{id}/configuracion/dashboard", "Orden y visibilidad de widgets"],
            ["empresas/{id}/reservas", "Próximas reservas (filtro: hoy)"],
            ["empresas/{id}/tareas", "Tareas vencidas/urgentes"],
        ], col_widths=[8*cm, 8*cm]),
        sp(8),
        h2("Cómo se actualizan las estadísticas"),
        p("Las estadísticas NO se calculan en la app. Se actualizan automáticamente mediante "
          "Cloud Function triggers cuando ocurren eventos:"),
        *bul([
            "Nuevo pedido → actualiza ventas del día",
            "Nueva reserva → actualiza ocupación",
            "Nueva valoración → actualiza rating promedio",
            "El botón 'Recalcular' fuerza una recalculación manual si hay discrepancias",
        ]),
        sp(8),
        h2("Módulos integrados en el Dashboard"),
        tabla([
            ["Módulo", "Widget en dashboard", "Dato mostrado"],
            ["Reservas", "reserva_card_mejorada", "Próxima reserva del día"],
            ["Tareas", "briefing_card", "Tareas vencidas/urgentes"],
            ["Google Business", "kpis_rating + estado_respuesta", "Rating y reviews pendientes"],
            ["Valoraciones", "grafico_evolucion_rating", "Evolución del rating"],
            ["Empleados", "widget_cobertura_resumen", "Cobertura de turnos"],
            ["Suscripción", "grid_modulos", "Candados en módulos no contratados"],
            ["Web", "tab_blog_web + tab_seo_web", "Gestión blog y SEO integrados"],
        ], col_widths=[4*cm, 5*cm, 7*cm]),
        sp(8),
        h2("Rol y personalización"),
        *bul([
            "propietario / admin → Dashboard completo con todos los widgets",
            "staff → Solo los módulos en modulos_permitidos del empleado",
            "El propietario puede reordenar y ocultar widgets desde 'configuracion_modulos.dart'",
            "La configuración se persiste en empresas/{id}/configuracion/dashboard",
        ]),
    ]
    build("01_dashboard.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 02 — TPV ROOT
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_tpv_root():
    c = [
        cabecera_modulo("TPV Root Screen", "Terminal PV para restaurante / tienda con mesas y comandas",
                        color=colors.HexColor("#1565C0")),
        sp(10),
        h2("¿Qué es?"),
        p("TpvRootScreen es el TPV para negocios con mesas (restaurantes, bares). "
          "Funciona en modo landscape y tiene tres secciones principales: plano de mesas, "
          "caja rápida y cierre de caja. Soporta TPVs personalizados (catálogos independientes "
          "por zona), impresoras térmicas Bluetooth y USB/COM en Windows, pantalla de cocina "
          "(KDS) y pedidos en espera (hold)."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["tpv_root_screen.dart", "Pantalla principal (282 KB — muy compleja)"],
            ["tpv_tienda_screen.dart", "Vista de caja rápida para tienda"],
            ["pantalla_cocina_screen.dart", "Pantalla KDS para cocina"],
            ["tpv_gestion_multi_screen.dart", "Gestión de múltiples TPVs personalizados"],
            ["widgets/floor_plan_widget.dart", "Plano visual de mesas con drag & drop"],
            ["widgets/tpv_type_switcher.dart", "Cambio entre modo restaurante/tienda/peluquería"],
            ["widgets/dialogo_factura_tpv.dart", "Diálogo de cobro con elección de método de pago"],
            ["widgets/dialogo_devoluciones.dart", "Gestión de devoluciones"],
            ["widgets/empleados_banner_widget.dart", "Banner del empleado activo en el turno"],
            ["widgets/mesa_theme_selector_bottom_sheet.dart", "Selector de tema visual del plano"],
            ["widgets/tpv/historial_tickets_widget.dart", "Historial de tickets del turno"],
            ["widgets/tpv/estadisticas_turno_widget.dart", "Stats del turno actual"],
            ["widgets/tpv/hold_pedidos_widget.dart", "Pedidos en espera (hold)"],
            ["widgets/tpv/arqueo_caja_widget.dart", "Arqueo de caja"],
            ["widgets/tpv/descuento_linea_widget.dart", "Descuentos por línea de producto"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Modos de la pantalla"),
        tabla([
            ["railIndex", "Modo", "Descripción"],
            ["0 (sin mesa)", "Plano de mesas", "Vista del floor_plan con todas las mesas y zonas"],
            ["0 (con mesa)", "Comanda de mesa", "Gestión de la comanda activa de una mesa"],
            ["1", "Caja rápida", "Cobro rápido sin mesa (takeaway, mostrador)"],
            ["2", "Cierre de caja", "Z/X y arqueo de efectivo"],
        ], col_widths=[2.5*cm, 4*cm, 9.5*cm]),
        sp(8),
        h2("Cómo está vinculado con Facturación"),
        diagrama_flujo([
            "Cajero selecciona productos y pulsa 'Cobrar'",
            "dialogo_factura_tpv.dart muestra métodos de pago configurados",
            "Al confirmar pago → PedidosService() crea un Pedido en Firestore (origen: presencial)",
            "TpvFacturacionService().obtenerConfig() lee el modo de facturación configurado",
            "MODO AUTOMÁTICO: Cloud Function generarFacturasResumenTpv corre a las 23:30\n"
            "  → agrupa todos los pedidos del día → crea UNA factura resumen (serie TPV)",
            "MODO MANUAL: FacturarPedidosScreen permite seleccionar pedidos y facturar ahora\n"
            "  → llama a facturacion_service.dart → crea factura individual",
            "La factura generada entra en el flujo normal de facturación (VeriFactu si aplica)",
        ]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/pedidos", "Cada venta crea un pedido (origen: presencial)"],
            ["empresas/{id}/mesas", "Estado de cada mesa (libre, ocupada, reservada)"],
            ["empresas/{id}/zonas_tpv", "Zonas del local (sala, terraza, barra)"],
            ["empresas/{id}/comandas", "Comanda activa de cada mesa"],
            ["empresas/{id}/cierres_caja", "Histórico de cierres Z/X"],
            ["empresas/{id}/catalogo", "Catálogo de productos"],
            ["empresas/{id}/configuracion/facturacion_tpv", "Modo facturación + métodos de pago"],
        ], col_widths=[8*cm, 8*cm]),
        sp(8),
        h2("Hardware soportado"),
        tabla([
            ["Hardware", "Servicio", "Plataforma"],
            ["Impresora Bluetooth", "impresora_bluetooth_service.dart", "Android / iOS"],
            ["Impresora Windows (COM)", "impresora_windows_service.dart", "Windows (puerto COM)"],
            ["Impresora Windows (TCP)", "impresora_windows_service.dart", "Windows (IP:9100)"],
            ["Scanner código barras", "mobile_scanner", "Todas"],
        ], col_widths=[5*cm, 6*cm, 5*cm]),
        sp(8),
        h2("TPVs personalizados (multi-TPV)"),
        p("El sistema soporta múltiples TPVs independientes sobre la misma empresa. Cada TPV "
          "personalizado tiene su propio catálogo (overrides sobre el catálogo base). "
          "El propietario gestiona esto desde TpvGestionMultiScreen. Al abrir un TPV "
          "personalizado se pasa tpvPersonalizadoId para aplicar sus overrides de precios y productos."),
        sp(8),
        h2("Cloud Functions relacionadas"),
        tabla([
            ["Función", "Cuándo"],
            ["generarFacturasResumenTpv", "Scheduled 23:30 — factura resumen diaria (modo automático)"],
            ["cerrarCaja", "Callable — proceso de cierre Z/X con validaciones"],
        ], col_widths=[7*cm, 9*cm]),
    ]
    build("02_tpv_root.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 03 — TPV PELUQUERÍA
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_tpv_peluqueria():
    c = [
        cabecera_modulo("TPV Peluquería", "Terminal PV con agenda visual por profesional y timeline",
                        color=colors.HexColor("#7C3AED")),
        sp(10),
        h2("¿Qué es?"),
        p("TpvPeluqueriaScreen es el TPV especializado para negocios de servicio (peluquerías, "
          "centros de estética, spas). En lugar de mesas usa una agenda visual tipo timeline "
          "donde cada columna es un profesional y cada fila es un hueco de tiempo. "
          "Tiene un tema dinámico oscuro (InheritedWidget) configurable por el negocio."),
        sp(6),
        h2("Diferencias clave vs TPV Root"),
        tabla([
            ["Característica", "TPV Root (Restaurante)", "TPV Peluquería"],
            ["Unidad principal", "Mesa", "Profesional + Servicio"],
            ["Vista", "Plano de mesas (floor plan)", "Timeline agenda por columnas"],
            ["Tema", "Oscuro fijo", "Dinámico (InheritedWidget _TpvTema)"],
            ["Modelo de cobro", "Comanda de mesa", "Cita/servicio cobrado al terminar"],
            ["Hardware", "Bluetooth + COM/TCP", "Bluetooth + COM/TCP"],
            ["Descuentos", "Por comanda", "Por línea individual (descuento_linea_widget)"],
            ["Cupones", "No", "Sí (cupon_input_widget)"],
            ["VeriFactu QR", "Sí", "Sí (qr_service.dart)"],
        ], col_widths=[4*cm, 5.5*cm, 6.5*cm]),
        sp(8),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["tpv_peluqueria_screen.dart", "Pantalla principal (versión producción)"],
            ["tpv_peluqueria_screen_NEW.dart", "Nueva versión en desarrollo"],
            ["tpv_peluqueria_screen_nuevo.dart", "Otra variante en pruebas"],
            ["widgets/dialogo_factura_tpv.dart", "Diálogo de cobro final"],
            ["widgets/tpv/descuento_linea_widget.dart", "Descuento por línea de producto/servicio"],
            ["widgets/tpv/cupon_input_widget.dart", "Input para aplicar cupones de descuento"],
            ["services/tpv/tpv_document_renderer.dart", "Renderizado de tickets y documentos"],
            ["services/verifactu/qr_service.dart", "QR VeriFactu en el ticket"],
            ["services/cierre_caja_service.dart", "Cierre del turno"],
            ["services/actividad_cliente_service.dart", "Registro de actividad en ficha cliente"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Tema dinámico — InheritedWidget"),
        p("El TPV Peluquería usa un sistema de tema dinámico propio (no el ThemeData de Flutter) "
          "implementado con InheritedWidget para propagar colores a toda la pantalla:"),
        code("class _TpvTema { Color primario, secundario, fondo, superficie, texto }"),
        code("class _TpvTemaScope extends InheritedWidget { ... }"),
        p("El negocio puede cambiar el tema desde la configuración. Los colores por defecto son "
          "tonos oscuros (fondo #0A0F23, tarjeta #1E2139) con acentos cian (#00FFC8) y magenta (#FF3296)."),
        sp(8),
        h2("Cómo está vinculado con Facturación"),
        diagrama_flujo([
            "Profesional completa el servicio → el staff pulsa 'Cobrar'",
            "Se abre dialogo_factura_tpv.dart con los servicios de la cita como líneas",
            "Se elige método de pago (efectivo, tarjeta, Bizum, transferencia, cheque regalo...)",
            "PedidosService().crearPedido() guarda el pedido en Firestore (origen: presencial)",
            "actividad_cliente_service.dart actualiza el historial del cliente en CRM",
            "TpvFacturacionService().obtenerConfig() determina el modo de facturación:",
            "  → AUTOMÁTICO: generarFacturasResumenTpv agrupa ventas a las 23:30",
            "  → MANUAL: FacturarPedidosScreen permite facturar citas individualmente",
            "Si VeriFactu activo: qr_service.dart genera el QR para el ticket impreso",
        ]),
        sp(8),
        h2("Descuentos y Cupones"),
        tabla([
            ["Tipo", "Widget", "Cómo funciona"],
            ["Descuento por línea", "descuento_linea_widget.dart", "% o importe fijo sobre un servicio"],
            ["Cupón de descuento", "cupon_input_widget.dart", "Código que aplica descuento global o por servicio"],
        ], col_widths=[4*cm, 6*cm, 6*cm]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/pedidos", "Cada cita cobrada crea un pedido"],
            ["empresas/{id}/servicios", "Catálogo de servicios del negocio"],
            ["empresas/{id}/empleados", "Lista de profesionales disponibles"],
            ["empresas/{id}/reservas", "Citas (el TPV las marca como 'completada' al cobrar)"],
            ["empresas/{id}/clientes", "Para registrar actividad y historial"],
            ["empresas/{id}/cierres_caja", "Cierre del turno"],
        ], col_widths=[8*cm, 8*cm]),
    ]
    build("03_tpv_peluqueria.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 04 — PEDIDOS
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_pedidos():
    c = [
        cabecera_modulo("Pedidos", "Gestión de pedidos multicanal: web, app, WhatsApp, presencial",
                        color=colors.HexColor("#059669")),
        sp(10),
        h2("¿Qué es?"),
        p("El módulo de Pedidos gestiona todos los pedidos independientemente de su origen: "
          "tienda online (web/app), WhatsApp Business, TPV presencial o importación CSV de "
          "TPV externos. Incluye catálogo de productos con variantes, control de stock, "
          "historial de precios y bot de WhatsApp para recibir pedidos automáticamente."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["detalle_pedido_screen.dart", "Detalle del pedido con cambio de estado y facturación"],
            ["formulario_pedido_screen.dart", "Crear pedido manual desde la app del negocio"],
            ["catalogo_productos_screen.dart", "Búsqueda y filtro del catálogo"],
            ["formulario_producto_screen.dart", "Alta y edición de productos"],
            ["detalle_producto_screen.dart", "Ficha del producto con historial de precios"],
            ["widgets/variante_selector_widget.dart", "Selector de variantes (talla, color)"],
            ["widgets/variantes_editor_widget.dart", "Editor de variantes del producto"],
            ["widgets/historial_precios_widget.dart", "Historial de cambios de precio"],
            ["widgets/importacion_catalogo_sheet.dart", "Importar catálogo desde CSV"],
            ["services/pedidos_service.dart", "CRUD de pedidos"],
            ["services/pedidos_whatsapp_service.dart", "Integración WhatsApp Business"],
            ["domain/modelos/pedido_whatsapp.dart", "Modelo específico de pedido WhatsApp"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Modelo de datos: Pedido"),
        tabla([
            ["Campo", "Tipo", "Descripción"],
            ["clienteId", "String?", "Referencia al cliente en el CRM"],
            ["clienteNombre", "String", "Nombre (siempre presente aunque no haya clienteId)"],
            ["fecha", "DateTime", "Fecha y hora del pedido"],
            ["origen", "OrigenPedido", "web | app | whatsapp | presencial | tpvExterno"],
            ["lineas", "List<LineaPedido>", "Productos, cantidades, precios, IVA"],
            ["subtotal / totalIva / total", "double", "Totales calculados"],
            ["estado", "EstadoPedido", "pendiente→confirmado→enPreparacion→listo→entregado"],
            ["estadoPago", "EstadoPago", "pendiente | pagado | devuelto"],
            ["facturaId", "String?", "Referencia a la factura generada (si existe)"],
        ], col_widths=[4*cm, 3*cm, 9*cm]),
        sp(8),
        h2("Flujo de un pedido online"),
        diagrama_flujo([
            "Cliente hace pedido en web/app → Firestore crea documento en empresas/{id}/pedidos",
            "Cloud Function onNuevoPedido → notificación push al negocio",
            "Si es WhatsApp: whatsappWebhook procesa mensaje → crea pedido automáticamente",
            "Negocio confirma desde la app → estado: 'confirmado'",
            "onNuevoPedidoWhatsApp → envía confirmación al cliente por WhatsApp",
            "Negocio prepara y marca como 'listo' → cliente recibe notificación",
            "Al marcar como entregado + pago registrado:",
            "onNuevoPedidoGenerarFactura → crea factura automáticamente en facturacion",
        ]),
        sp(8),
        h2("Importación de catálogo CSV"),
        p("El negocio puede importar productos en bloque desde un CSV con columnas: "
          "nombre, precio, costo, categoría, stock. El sistema valida y crea cada producto."),
        *bul([
            "importacion_catalogo_sheet.dart — interface de mapeo de columnas",
            "importar_catalogo_csv_screen.dart (TPV) — versión para el TPV",
            "Detecta duplicados por nombre antes de importar",
        ]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/pedidos", "Todos los pedidos de cualquier origen"],
            ["empresas/{id}/catalogo", "Productos con precios, stock, imágenes"],
            ["empresas/{id}/categorias_catalogo", "Categorías de productos"],
        ], col_widths=[8*cm, 8*cm]),
        sp(8),
        h2("Cloud Functions relacionadas"),
        tabla([
            ["Función", "Trigger / Tipo", "Qué hace"],
            ["onNuevoPedido", "Trigger Firestore", "Notificación push al negocio"],
            ["onNuevoPedidoGenerarFactura", "Trigger Firestore", "Auto-crea factura si pedido pagado"],
            ["onNuevoPedidoWhatsApp", "Trigger Firestore", "Envía confirmación por WhatsApp"],
            ["whatsappWebhook", "HTTP", "Recibe y procesa mensajes de WhatsApp Business"],
        ], col_widths=[5.5*cm, 4*cm, 6.5*cm]),
    ]
    build("04_pedidos.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 05 — EMPLEADOS (+ conexión TPV)
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_empleados():
    c = [
        cabecera_modulo("Empleados", "Gestión de plantilla + conexión con el TPV",
                        color=colors.HexColor("#0F766E")),
        sp(10),
        h2("¿Qué es?"),
        p("Módulo de gestión de plantilla completo: alta/baja de empleados, datos de nómina, "
          "contratos, documentos, bajas laborales, embargos judiciales y permisos de acceso "
          "por módulo. Los empleados tienen un rol en la app que determina qué pueden ver."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["formulario_empleado_form.dart", "Alta y edición de datos personales y laborales"],
            ["formulario_datos_nomina_form.dart", "Datos específicos para el cálculo de nómina"],
            ["empleados_baja_screen.dart", "Gestión de bajas laborales (IT, maternidad...)"],
            ["widgets/avatar_empleado_widget.dart", "Avatar/foto del empleado"],
            ["widgets/baja_laboral_widget.dart", "Widget que muestra baja activa"],
            ["widgets/selector_foto_widget.dart", "Subida de foto a Firebase Storage"],
            ["widgets/seccion_embargos_widget.dart", "Gestión de embargos judiciales"],
            ["models/embargo_model.dart", "Modelo de embargo: importe, fechas, resolución"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Modelo de datos: Empleado"),
        tabla([
            ["Campo", "Tipo", "Descripción"],
            ["usuarioId", "String?", "UID Firebase Auth si tiene acceso a la app"],
            ["nif", "String", "NIF (obligatorio para nóminas)"],
            ["tipoContrato", "TipoContrato", "indefinido | temporal | prácticas | formación | parcial"],
            ["salarioBase", "double", "Salario base mensual bruto"],
            ["numeross", "String?", "Número de Seguridad Social"],
            ["convenio", "String?", "Convenio colectivo aplicable"],
            ["rol", "String?", "propietario | admin | staff (acceso a la app)"],
            ["modulosPermitidos", "List<String>", "Solo para rol=staff — módulos visibles"],
            ["activo", "bool", "false al dar de baja"],
            ["enBajaLaboral", "bool", "true si tiene IT activa"],
        ], col_widths=[4*cm, 3*cm, 9*cm]),
        sp(10),
        h2("Conexión de Empleados con el TPV"),
        hr(),
        p("Los empleados se conectan al TPV de tres formas distintas según el tipo de negocio:"),
        sp(4),
        h3("1. TPV Peluquería — Profesionales"),
        p("En el TPV Peluquería, cada empleado es un 'profesional' que aparece como una columna "
          "en la agenda visual. El flujo es:"),
        diagrama_flujo([
            "TpvPeluqueriaScreen carga los empleados activos de empresas/{id}/empleados",
            "Filtra los que tienen asignados servicios (servicios/{id}.empleadoIds)",
            "Cada profesional aparece como columna en el timeline de la agenda",
            "Al crear/cobrar una cita se guarda el profesionalId en el pedido",
            "empleados_banner_widget.dart muestra el nombre del empleado activo en el turno",
        ], color=colors.HexColor("#7C3AED")),
        sp(6),
        h3("2. TPV Root — Empleado del turno"),
        p("En el TPV Root (restaurante/tienda), se puede asignar un empleado al turno activo:"),
        diagrama_flujo([
            "empleados_banner_widget.dart muestra el cajero/camarero del turno",
            "El propietario selecciona el empleado al inicio del turno",
            "_empleadoSeleccionadoId se almacena en el estado de TpvRootScreen",
            "Los pedidos creados durante el turno incluyen el empleadoId (para estadísticas)",
            "El cierre de caja muestra las ventas desglosadas por empleado",
        ], color=colors.HexColor("#1565C0")),
        sp(6),
        h3("3. TPV — Control de acceso por rol"),
        p("El TPV respeta el sistema de roles de empleados:"),
        tabla([
            ["Rol", "Acceso al TPV", "Qué puede hacer"],
            ["propietario", "Completo", "Abrir/cerrar caja, configurar, ver estadísticas"],
            ["admin", "Completo (esAdmin=true)", "Igual que propietario en el TPV"],
            ["staff", "Limitado", "Solo cobrar ventas, no puede configurar ni ver config"],
        ], col_widths=[3*cm, 4*cm, 9*cm]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/empleados", "Documento principal del empleado"],
            ["empresas/{id}/empleados/{id}/documentos", "Contratos, CV subidos a Storage"],
            ["empresas/{id}/empleados/{id}/renovaciones", "Alertas de fin de contrato"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Conexión con otros módulos"),
        tabla([
            ["Módulo", "Relación"],
            ["Nóminas", "Usa salario, tipo contrato, SS, convenio para calcular la nómina"],
            ["Vacaciones", "Cada solicitud pertenece a un empleadoId"],
            ["Fichajes", "Los fichajes se asocian al empleadoId"],
            ["Finiquitos", "El cálculo usa fecha alta, salario y vacaciones pendientes"],
            ["Tareas", "Las tareas se asignan a un empleadoId"],
            ["Reservas", "En peluquería, los empleados son los profesionales disponibles"],
            ["TPV", "Ver sección anterior (profesional/cajero/acceso)"],
        ], col_widths=[4*cm, 12*cm]),
    ]
    build("05_empleados.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 06 — NEGOCIO PÚBLICO
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_negocio_publico():
    c = [
        cabecera_modulo("Negocio Público", "Panel público del negocio en la app de clientes finales",
                        color=colors.HexColor("#EA580C")),
        sp(10),
        h2("¿Qué es?"),
        p("El módulo Negocio Público es el 'escaparate' que ven los clientes finales (rol clienteFinal) "
          "cuando acceden al negocio desde la app de exploración. Es la cara pública del negocio dentro "
          "de la plataforma Fluix, independiente de la web del negocio."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["modulo_app_screen.dart", "Pantalla principal — vista pública del negocio"],
            ["personalizacion_app_screen.dart", "El propietario personaliza colores, logo, textos"],
            ["gestion_negocios_publicos_screen.dart", "Admin plataforma — gestión de todos los negocios"],
            ["resenas_fluix_screen.dart", "Reseñas recibidas en la plataforma (vs Google)"],
            ["tab_reservas_screen.dart", "Tab de reservas online desde la vista pública"],
            ["tab_servicios_negocio.dart", "Tab de servicios disponibles del negocio"],
            ["ServicioNegocio.dart", "Modelo de servicio público"],
            ["terminos_condiciones_screen.dart", "T&C del negocio"],
            ["reserva_form_widget.dart", "Formulario de reserva embebido en la vista pública"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Estructura de la vista pública"),
        tabla([
            ["Tab / Sección", "Contenido"],
            ["Inicio", "Logo, descripción, fotos, horarios, ubicación, rating"],
            ["Servicios", "Catálogo de servicios con precios y duración (tab_servicios_negocio)"],
            ["Reservas", "Formulario de reserva online (tab_reservas_screen)"],
            ["Reseñas", "Valoraciones de clientes en Fluix (resenas_fluix_screen)"],
        ], col_widths=[4*cm, 12*cm]),
        sp(8),
        h2("Cómo se publica un negocio"),
        diagrama_flujo([
            "Empresa registrada en Fluix → datos básicos en empresas/{id}",
            "El propietario personaliza la app en personalizacion_app_screen.dart",
            "Al activar la visibilidad pública → se crea/actualiza negocios_publicos/{empresaId}",
            "La colección negocios_publicos es de LECTURA PÚBLICA (sin auth)",
            "Los clientes finales ven el negocio en explorar_negocios",
            "Al hacer reserva desde la vista pública → reserva_form_widget → reservasPublicas (CF)",
        ]),
        sp(8),
        h2("Personalización por el propietario"),
        *bul([
            "Logo e imágenes del negocio (subidas a Firebase Storage)",
            "Colores de marca de la vista pública",
            "Descripción, horarios de apertura, ubicación en el mapa",
            "Servicios visibles y sus precios públicos",
            "Configuración de reservas online (disponibilidad, antelación mínima)",
            "T&C propios del negocio (terminos_condiciones_screen)",
        ]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Acceso", "Uso"],
            ["negocios_publicos/{empresaId}", "Lectura pública", "Datos del negocio visibles a clientes"],
            ["empresas/{id}/servicios", "Privada", "Catálogo de servicios del negocio"],
            ["empresas/{id}/reservas", "Privada", "Reservas recibidas desde la vista pública"],
            ["empresas/{id}/valoraciones", "Privada", "Valoraciones recibidas"],
        ], col_widths=[5.5*cm, 3*cm, 7.5*cm]),
        sp(8),
        h2("Conexión con otros módulos"),
        tabla([
            ["Módulo", "Relación"],
            ["explorar_negocios", "La vista pública aparece al hacer clic en un negocio del directorio"],
            ["reservas", "Las reservas online usan el mismo backend que las reservas internas"],
            ["servicios", "Los servicios públicos vienen del módulo de servicios interno"],
            ["fidelizacion", "El cliente puede ver y acumular sellos desde la vista pública"],
            ["valoraciones", "Las reseñas se muestran y se pueden dejar desde aquí"],
            ["tienda_monedas", "El cliente puede ver sus monedas y canjear recompensas"],
        ], col_widths=[4*cm, 12*cm]),
    ]
    build("06_negocio_publico.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 07 — PDF TEMPLATES
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_pdf_templates():
    c = [
        cabecera_modulo("PDF Templates", "Sistema de plantillas personalizadas para documentos PDF",
                        color=colors.HexColor("#BE185D")),
        sp(10),
        h2("¿Qué es?"),
        p("Módulo que permite a los negocios personalizar el diseño de sus documentos PDF: "
          "facturas, tickets de venta, nóminas, confirmaciones de reserva. El propietario "
          "puede crear plantillas con variables dinámicas que se rellenan automáticamente."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["features/pdf_templates/", "Carpeta del módulo (7 archivos dart)"],
            ["data/pdf_template_service.dart", "CRUD de plantillas en Firestore"],
            ["domain/models/pdf_template.dart", "Modelo de plantilla"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Cómo funciona"),
        *bul([
            "El propietario crea una plantilla con HTML + variables (ej: {{cliente_nombre}}, {{total}})",
            "Al generar un PDF (factura, nómina...) el sistema busca si hay plantilla configurada",
            "Si existe, inyecta los datos reales en las variables y renderiza el HTML a PDF",
            "Si no hay plantilla, usa el diseño por defecto del sistema",
            "La configuración del TPV (configuracion_facturacion_tpv_screen.dart) permite "
            "elegir qué plantilla usar para los tickets",
        ]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/pdf_templates", "Plantillas personalizadas del negocio"],
        ], col_widths=[8*cm, 8*cm]),
        sp(8),
        h2("Módulos que usan plantillas"),
        *bul([
            "Facturación — plantilla de factura emitida",
            "TPV — plantilla de ticket de venta",
            "Nóminas — plantilla de nómina mensual",
            "Reservas — plantilla de confirmación de reserva",
        ]),
    ]
    build("07_pdf_templates.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER: PDF PEQUEÑO GENÉRICO
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_simple(filename, titulo, descripcion, color, secciones):
    """Genera un PDF sencillo con secciones de texto."""
    c = [cabecera_modulo(titulo, descripcion, color=color), sp(10)]
    for sec_titulo, contenido in secciones:
        c += [h2(sec_titulo)]
        if isinstance(contenido, str):
            c += [p(contenido)]
        elif isinstance(contenido, list) and all(isinstance(x, str) for x in contenido):
            c += bul(contenido)
        else:
            c += contenido
        c += [sp(6)]
    build(filename, c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 08 — VACACIONES
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_vacaciones():
    c = [
        cabecera_modulo("Vacaciones", "Solicitudes, saldo de días, festivos y carryover anual",
                        color=colors.HexColor("#0284C7")),
        sp(10),
        h2("¿Qué es?"),
        p("Gestión del calendario vacacional de la plantilla. Los empleados solicitan períodos, "
          "el responsable valida la cobertura mínima del equipo y aprueba o rechaza. "
          "El sistema lleva el saldo de días disponibles, festivos locales y carryover entre años."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["features/vacaciones/pantallas/festivos_locales_screen.dart", "Editor de festivos propios"],
            ["features/vacaciones/widgets/calendario_vacaciones_widget.dart", "Vista calendario (table_calendar)"],
            ["features/vacaciones/widgets/saldo_vacaciones_widget.dart", "Saldo disponible por empleado"],
            ["features/vacaciones/widgets/cobertura_semanal_widget.dart", "Cobertura mínima por semana"],
        ], col_widths=[8.5*cm, 7.5*cm]),
        sp(8),
        h2("Flujo de una solicitud"),
        diagrama_flujo([
            "Empleado solicita fechas → se crea Vacacion con estado 'solicitada'",
            "cobertura_semanal_widget verifica cuántos empleados coinciden en esas fechas",
            "Si hay cobertura suficiente → propietario aprueba → estado 'aprobada'",
            "onVacacionEstadoCambiado (CF) notifica al empleado el resultado",
            "Al aprobar: se descuentan días del saldo disponible del empleado",
            "31/12: scheduledCierreAnualVacaciones cierra el período del año",
            "31/12: scheduledExpiracionCarryover elimina días caducados de carryover",
        ]),
        sp(8),
        h2("Configuración"),
        tabla([
            ["Parámetro", "Descripción"],
            ["diasAnualesTotal", "Días laborables de vacaciones al año (habitual: 22)"],
            ["carryoverMax", "Días que se pueden arrastrar al año siguiente"],
            ["periodicidadReset", "Fecha de reset del contador: '01/01' o '01/09'"],
            ["coberturaMinimaEquipo", "Nº mínimo de empleados presentes en cualquier semana"],
        ], col_widths=[5*cm, 11*cm]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/vacaciones", "Períodos solicitados/aprobados"],
            ["empresas/{id}/configuracion/vacaciones", "Días, carryover, fecha de reset"],
            ["empresas/{id}/festivos_locales", "Festivos propios del negocio (municipales)"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Cloud Functions"),
        tabla([
            ["Función", "Cuándo"],
            ["onVacacionEstadoCambiado", "Trigger — notifica al empleado"],
            ["scheduledCierreAnualVacaciones", "Scheduled 31/12 — cierra período anual"],
            ["scheduledExpiracionCarryover", "Scheduled 31/12 — elimina carryover caducado"],
            ["importarFestivosEspana", "Callable — carga festivos nacionales + autonómicos (AEMET)"],
        ], col_widths=[6.5*cm, 9.5*cm]),
    ]
    build("08_vacaciones.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 09 — FICHAJES
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_fichajes():
    c = [
        cabecera_modulo("Fichajes", "Control horario digital con validación GPS",
                        color=colors.HexColor("#0F766E")),
        sp(10),
        h2("¿Qué es?"),
        p("Control de presencia digital. Los empleados fichan entrada y salida desde la app. "
          "El sistema puede validar que el fichaje se hace dentro del radio de geolocalización "
          "del negocio. Los datos alimentan el cálculo de ausencias en las nóminas."),
        sp(6),
        h2("Archivos"),
        tabla([
            ["Carpeta/Archivo", "Contenido"],
            ["features/fichaje/ (2 archivos)", "Versión anterior (legacy)"],
            ["features/fichajes/ (6 archivos)", "Versión actual en producción"],
            ["services/fichaje_service.dart", "CRUD de fichajes"],
            ["services/geolocalizacion_service.dart", "Validación GPS del fichaje"],
        ], col_widths=[6*cm, 10*cm]),
        sp(8),
        h2("Modelo de datos"),
        tabla([
            ["Campo", "Tipo", "Descripción"],
            ["empleadoId", "String", "Referencia al empleado"],
            ["fecha", "DateTime", "Fecha del fichaje"],
            ["horaEntrada", "DateTime?", "Timestamp de entrada"],
            ["horaSalida", "DateTime?", "Timestamp de salida"],
            ["ubicacionEntrada", "GeoPoint?", "GPS al entrar (si habilitado)"],
            ["ubicacionSalida", "GeoPoint?", "GPS al salir (si habilitado)"],
            ["horasTrabajadas", "double?", "Calculado al salir"],
            ["validado", "bool", "Validado por el responsable"],
            ["incidencia", "String?", "Nota de incidencia si aplica"],
        ], col_widths=[4*cm, 3*cm, 9*cm]),
        sp(8),
        h2("Flujo de fichaje"),
        diagrama_flujo([
            "Empleado abre la app y pulsa 'Fichar entrada'",
            "geolocalizacion_service verifica que el GPS está dentro del radio configurado",
            "Si OK: se registra horaEntrada + ubicación en Firestore",
            "Al salir: pulsa 'Fichar salida' → se calcula horasTrabajadas automáticamente",
            "El responsable puede validar o añadir incidencias desde la pantalla de gestión",
            "A fin de mes: nominas_service lee los fichajes para calcular ausencias",
        ]),
        sp(8),
        h2("Integración con Nóminas"),
        *bul([
            "El módulo de Nóminas consulta los fichajes del mes para cada empleado",
            "Días sin fichar = ausencia no justificada (se descuenta del salario)",
            "Horas extras detectadas automáticamente si supera la jornada configurada",
            "El responsable puede corregir fichajes erróneos antes de aprobar la nómina",
        ]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/fichajes", "Registros de entrada/salida"],
            ["empresas/{id}/configuracion/fichaje", "Radio GPS, tolerancia en minutos, alertas"],
        ], col_widths=[7*cm, 9*cm]),
    ]
    build("09_fichajes.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 10 — PERFIL
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_perfil():
    c = [
        cabecera_modulo("Perfil", "Cuenta del usuario, auditoría, certificado digital y pagos",
                        color=colors.HexColor("#7C3AED")),
        sp(10),
        h2("¿Qué es?"),
        p("Gestión del perfil personal del usuario autenticado. Incluye: cambio de contraseña, "
          "configuración de biometría y 2FA, subida del certificado digital PKCS12 para VeriFactu, "
          "datos bancarios para pagos, historial de auditoría y gestión de cuentas vinculadas."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["pantalla_perfil.dart", "Pantalla principal con tabs"],
            ["pantalla_configuracion_pagos.dart", "IBAN y datos bancarios para Stripe"],
            ["pantalla_auditoria.dart", "Log de acciones del usuario (login, cambios)"],
            ["pantalla_sonidos_notificacion.dart", "Configurar sonido de notificaciones push"],
            ["gestion_certificado_screen.dart", "Subir/ver certificado PKCS12 para VeriFactu"],
            ["gestionar_cuentas_screen.dart", "Cuentas Google/Apple vinculadas"],
        ], col_widths=[6.5*cm, 9.5*cm]),
        sp(8),
        h2("Certificado digital VeriFactu"),
        p("Para firmar facturas con VeriFactu el negocio necesita un certificado digital cualificado "
          "(PKCS12 / .p12 o .pfx). El flujo es:"),
        diagrama_flujo([
            "Propietario accede a 'Gestionar certificado' en el perfil",
            "Sube el archivo .p12/.pfx desde el dispositivo",
            "El certificado se sube cifrado a Firebase Storage",
            "La referencia se guarda en empresas/{id}/configuracion/certificado",
            "Al firmar una factura, firmarXMLVerifactu (CF) lee el certificado y firma el XML",
            "Si el certificado va a vencer, alertaCertificado (CF Scheduled) notifica al propietario",
        ]),
        sp(8),
        h2("Auditoría"),
        *bul([
            "Cada login/logout queda en usuarios/{uid}/auditoria",
            "Los cambios críticos (contraseña, certificado) también se registran",
            "El propietario puede ver el histórico completo desde pantalla_auditoria.dart",
            "Campos: acción, timestamp, IP, dispositivo",
        ]),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["usuarios/{uid}", "Perfil del usuario (nombre, email, foto, rol)"],
            ["usuarios/{uid}/auditoria", "Historial de acciones"],
        ], col_widths=[6*cm, 10*cm]),
    ]
    build("10_perfil.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 11 — CLIENTES
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_clientes():
    c = [
        cabecera_modulo("Clientes", "CRM — Base de datos de clientes con segmentación y análisis",
                        color=colors.HexColor("#1565C0")),
        sp(10),
        h2("¿Qué es?"),
        p("El módulo de Clientes es el CRM del negocio. Centraliza todos los clientes con su "
          "historial completo (reservas, pedidos, valoraciones). Incluye herramientas para "
          "detectar duplicados, identificar clientes silenciosos (inactivos) e importar "
          "bases de datos existentes en CSV."),
        sp(6),
        h2("Archivos principales"),
        tabla([
            ["Archivo", "Rol"],
            ["clientes_silenciosos_screen.dart", "Clientes sin actividad desde N días"],
            ["duplicados_cliente_screen.dart", "Detección y fusión de duplicados"],
            ["tab_tareas_cliente.dart", "Tareas vinculadas a un cliente concreto"],
            ["services/importacion_clientes_service.dart", "Importación masiva desde CSV"],
            ["domain/modelos/cliente_importado_model.dart", "Modelo para importación"],
        ], col_widths=[7*cm, 9*cm]),
        sp(8),
        h2("Estados del cliente"),
        tabla([
            ["Estado", "Descripción", "Cuándo se asigna"],
            ["contacto", "Solo tiene datos, no ha comprado", "Al importar o crear manualmente"],
            ["activo", "Ha realizado alguna compra/reserva", "Al registrar primera transacción"],
            ["inactivo", "Sin actividad en el período configurado", "Automático por tiempo sin actividad"],
        ], col_widths=[3*cm, 5.5*cm, 7.5*cm]),
        sp(8),
        h2("Herramientas de gestión"),
        h3("Clientes silenciosos"),
        p("Filtra clientes con ultimaVisita anterior a N días. "
          "Desde esta pantalla se puede enviar un email/WhatsApp de reactivación."),
        h3("Duplicados"),
        p("Compara teléfonos y emails en toda la base de datos. "
          "Muestra pares/grupos probables y permite fusionarlos: el historial se combina "
          "y el registro secundario se elimina."),
        h3("Importación CSV"),
        p("Parsea un CSV mapeando columnas (nombre, teléfono, email, NIF). "
          "Detecta duplicados antes de importar y ofrece skip/merge por cada conflicto."),
        sp(8),
        h2("Colecciones Firestore"),
        tabla([
            ["Colección", "Uso"],
            ["empresas/{id}/clientes", "Documento principal del cliente"],
            ["empresas/{id}/clientes/{id}/actividad", "Historial: reservas, pedidos, valoraciones"],
            ["empresas/{id}/clientes/{id}/valoraciones", "Copia de sus valoraciones"],
        ], col_widths=[7*cm, 9*cm]),
    ]
    build("11_clientes.pdf", c)

# ═══════════════════════════════════════════════════════════════════════════════
# MÓDULOS 19–32 (pequeños/medianos)
# ═══════════════════════════════════════════════════════════════════════════════

def pdf_explorar_negocios():
    pdf_simple("12_explorar_negocios.pdf",
        "Explorar Negocios (#19)",
        "Directorio público de negocios registrados en Fluix",
        colors.HexColor("#0284C7"),
        [
            ("¿Qué es?",
             "Pantalla principal de la app para clientes finales. Muestra un directorio "
             "de todos los negocios activos en la plataforma Fluix. El cliente puede buscar "
             "por nombre, categoría o ubicación y acceder al perfil de cada negocio."),
            ("Archivos", [
                "features/explorar_negocios/pantallas/pantalla_explorar.dart — Listado con búsqueda",
                "4 archivos .dart en total",
            ]),
            ("Colecciones Firestore", [
                "negocios_publicos — Lectura pública sin autenticación",
                "Cada documento contiene: nombre, categoría, logo, fotos, rating, horarios, ubicación",
            ]),
            ("Quién lo usa", [
                "Usuarios con rol clienteFinal (consumidores finales)",
                "No requiere estar autenticado para ver el listado",
                "Al hacer reserva o fidelizarse, sí requiere login",
            ]),
        ]
    )

def pdf_valoraciones():
    pdf_simple("13_valoraciones.pdf",
        "Valoraciones (#20)",
        "Sistema de reseñas de clientes sobre los negocios",
        colors.HexColor("#CA8A04"),
        [
            ("¿Qué es?",
             "Los clientes pueden dejar valoraciones (1-5 estrellas + comentario) sobre "
             "los negocios. Se solicitan automáticamente 2 horas después de una reserva "
             "completada. Las valoraciones actualizan el rating del negocio en el directorio."),
            ("Colecciones Firestore", [
                "empresas/{id}/valoraciones — Valoraciones recibidas por el negocio",
                "negocios_publicos/{id} — rating y totalValoraciones se actualizan automáticamente",
            ]),
            ("Cloud Functions", [
                "onNuevaValoracion — Trigger: actualiza rating promedio en negocios_publicos",
                "onReservaCompletada — Trigger: solicita valoración al cliente 2h después",
                "onValoracionBaja — Trigger: alerta al propietario si rating < 3 estrellas",
            ]),
        ]
    )

def pdf_registro():
    pdf_simple("14_registro.pdf",
        "Registro (#21)",
        "Onboarding inicial de nuevas empresas",
        colors.HexColor("#059669"),
        [
            ("¿Qué es?",
             "Flujo de alta de nuevas empresas en Fluix. Recoge datos del negocio, "
             "datos fiscales, crea el usuario propietario en Firebase Auth y inicializa "
             "todos los datos de la empresa. También gestiona el registro por invitación "
             "cuando un propietario invita a un empleado."),
            ("Archivos principales", [
                "pantalla_registro.dart — Flujo principal de registro",
                "pantalla_registrar_empresa_social.dart — Datos fiscales del negocio",
                "pantalla_registro_invitacion.dart — Registro por deep link de invitación",
                "formulario_registro.dart / formulario_registro_simple.dart — Formularios",
            ]),
            ("Deep link de invitación", [
                "URL: fluixcrm://invite?token=...  (enviada por email al empleado)",
                "Al abrir el link, se pre-rellena el email y la empresa destino",
                "Al completar el registro, el usuario queda asociado a esa empresa",
            ]),
            ("Cloud Functions", [
                "crearEmpresaHTTP — HTTP: crea la empresa en Firestore",
                "inicializarEmpresa — Callable: setup inicial (módulos, servicios demo, suscripción)",
                "onInvitacionCreada — Trigger: envía email de invitación al empleado",
            ]),
        ]
    )

def pdf_reservas():
    pdf_simple("15_reservas.pdf",
        "Reservas (#22 y #23)",
        "Sistema de citas para todo tipo de negocio",
        colors.HexColor("#7C3AED"),
        [
            ("¿Qué es?",
             "Dos módulos complementarios: 'reservas' gestiona las citas desde el lado "
             "del negocio (confirmar, rechazar, ver agenda), y 'reservas_cliente' es la "
             "interfaz pública para que los clientes finales hagan reservas sin login."),
            ("Tipos de negocio soportados", [
                "Restaurante — número de comensales, mesa asignada",
                "Peluquería / servicios — servicio específico, profesional, duración",
                "Genérico — cualquier tipo de cita con fecha/hora",
            ]),
            ("formulario_reserva_factory.dart",
             "Factory que elige el formulario correcto según el tipo de negocio: "
             "devuelve el formulario de restaurante, peluquería o genérico."),
            ("Cloud Functions", [
                "onNuevaReserva — Notificación al negocio + email al cliente",
                "onReservaConfirmada / onReservaCancelada — Notificaciones",
                "recordatoriosCitas — Scheduled noche: recordatorio 24h antes",
                "reservasPublicas — HTTP: crear reserva sin autenticación",
                "confirmarReserva / rechazarReserva — Callable: cambiar estado",
                "expirarReservasPublicas — Scheduled: limpiar reservas sin confirmar",
            ]),
            ("Colecciones Firestore", [
                "empresas/{id}/reservas — Reservas (ambos módulos usan la misma colección)",
                "empresas/{id}/servicios — Servicios disponibles (peluquería)",
                "empresas/{id}/mesas — Mesas del restaurante",
                "empresas/{id}/configuracion/reservas — Horarios, slots, antelación mínima",
            ]),
        ]
    )

def pdf_flash_slots():
    pdf_simple("16_flash_slots.pdf",
        "Flash Slots (#24)",
        "Promociones de tiempo limitado con stock",
        colors.HexColor("#DC2626"),
        [
            ("¿Qué es?",
             "El negocio crea 'slots' (promociones de tiempo limitado): descuento %, "
             "stock limitado, fecha de expiración. Aparecen destacados en la app pública "
             "y se notifica a los clientes potenciales cercanos."),
            ("Ejemplo de uso",
             "Un restaurante crea: '20% descuento en menú de hoy — solo 10 plazas — "
             "válido hasta las 14:00'. Los clientes lo ven en la app y reservan."),
            ("Colecciones Firestore", [
                "empresas/{id}/flash_slots — Slots activos",
                "Campos: titulo, descripcion, descuentoPct, stock, fechaFin",
            ]),
            ("Cloud Functions", [
                "onNuevoFlashSlot — Trigger: notificación push a clientes potenciales",
                "expirarFlashSlots — Scheduled: limpia slots vencidos o sin stock",
            ]),
        ]
    )

def pdf_tienda_monedas():
    pdf_simple("17_tienda_monedas.pdf",
        "Tienda de Monedas (#25)",
        "Moneda virtual, canje de recompensas y trofeos",
        colors.HexColor("#7C3AED"),
        [
            ("¿Qué es?",
             "Sistema de fidelización basado en moneda virtual (monedas Fluix). "
             "Los clientes ganan monedas por actividades y las canjean por recompensas "
             "en cualquier negocio de la plataforma."),
            ("Cómo se ganan monedas", [
                "Primera reserva: +100 monedas",
                "Reserva completada: +50 monedas",
                "Valoración publicada: +75 monedas",
                "Referido registrado: +200 monedas",
                "Trofeo desbloqueado: variable según el trofeo",
            ]),
            ("Archivos principales", [
                "pantalla_tienda_monedas.dart — Catálogo de recompensas canjeables",
                "pantalla_monedero.dart — Saldo y historial de movimientos",
                "domain/modelos/monedero.dart — Modelo del monedero",
                "features/perfil_cliente/pantallas/pantalla_trofeos.dart — Colección de trofeos",
            ]),
            ("Cloud Functions", [
                "onCanjeRecompensa — Callable: valida saldo y procesa el canje",
                "evaluarTrofeosFidelidad — Callable: evalúa y desbloquea trofeos",
                "onCitaCompletadaTrofeos — Trigger: evalúa trofeos tras cita completada",
                "onResenaCreadaTrofeos — Trigger: evalúa trofeos tras reseña",
                "fanNumero1Job — Scheduled mensual: corona al cliente top del mes",
            ]),
            ("Colecciones Firestore", [
                "usuarios/{uid}/monedero — Saldo y movimientos",
                "usuarios/{uid}/trofeos — Trofeos desbloqueados",
                "empresas/{id}/recompensas — Catálogo de recompensas del negocio",
            ]),
        ]
    )

def pdf_suscripcion():
    pdf_simple("18_suscripcion.pdf",
        "Suscripción (#26)",
        "Planes, packs activos, control de acceso y Stripe",
        colors.HexColor("#1565C0"),
        [
            ("¿Qué es?",
             "Controla qué módulos tiene habilitados cada empresa según su plan de pago. "
             "Es la fuente de verdad para el control de acceso: tanto la UI del Dashboard "
             "como las Firestore Rules leen el estado de la suscripción."),
            ("Documento clave: empresas/{id}/suscripcion/actual", [
                "estado: ACTIVA | VENCIDA | SUSPENDIDA",
                "packs_activos: ['facturacion', 'nominas', 'tpv', 'rrhh', ...]",
                "addons_activos: ['verifactu', 'whatsapp', 'gmb']",
                "es_demo: bool (demo tiene acceso a todo)",
                "stripeCustomerId y stripeSubscriptionId",
                "fechaInicio y fechaFin del período",
            ]),
            ("Packs disponibles", [
                "facturacion — Facturas, contabilidad, modelos AEAT",
                "nominas — Nóminas, finiquitos, SEPA",
                "rrhh — Empleados, vacaciones, fichajes",
                "tpv — TPV completo",
                "reservas — Reservas y calendario",
                "clientes_crm — CRM, tareas, campañas",
                "web — Web pública, blog, SEO",
            ]),
            ("Flujo Stripe", [
                "Negocio selecciona plan → Stripe crea Customer + Subscription",
                "stripeWebhook recibe invoice.payment_succeeded → estado: ACTIVA",
                "stripeWebhook recibe subscription.deleted → estado: VENCIDA",
                "verificarSuscripciones (Scheduled) comprueba vencimientos cada noche",
            ]),
        ]
    )

def pdf_pdf_editor():
    pdf_simple("19_pdf_editor.pdf",
        "PDF Editor (#28)",
        "Editor de PDFs integrado",
        colors.HexColor("#BE185D"),
        [
            ("¿Qué es?",
             "Módulo con un único archivo (1 .dart) que proporciona funcionalidad "
             "básica de edición/previsualización de PDFs dentro de la app. "
             "Se usa para revisar documentos antes de enviarlos."),
            ("Estado", [
                "Módulo pequeño (1 archivo) — posiblemente en desarrollo inicial",
                "Se integra con pdf_templates para previsualizar plantillas",
            ]),
        ]
    )

def pdf_onboarding():
    pdf_simple("20_onboarding.pdf",
        "Onboarding (#29)",
        "Setup inicial guiado tras el registro de una nueva empresa",
        colors.HexColor("#059669"),
        [
            ("¿Qué es?",
             "Wizard de configuración que se muestra la primera vez que el propietario "
             "accede tras crear su empresa. Guía al usuario en la configuración básica "
             "y activa la suscripción de demostración."),
            ("Qué hace el wizard", [
                "Crear los primeros servicios/productos del negocio",
                "Configurar el tipo de negocio (restaurante, peluquería, tienda...)",
                "Habilitar los módulos según el plan elegido",
                "Crear la suscripción demo (es_demo: true, acceso total por N días)",
                "Marcar onboarding_completado: true en la empresa (evita que vuelva a aparecer)",
            ]),
            ("Colecciones Firestore", [
                "empresas/{id} — Actualiza onboarding_completado a true",
                "empresas/{id}/suscripcion/actual — Crea la suscripción demo",
            ]),
        ]
    )

def pdf_propietario():
    pdf_simple("21_propietario.pdf",
        "Propietario (#30)",
        "Panel especial solo visible para propietarios",
        colors.HexColor("#1E293B"),
        [
            ("¿Qué es?",
             "Módulo con acceso restringido al rol propietario. Contiene vistas y "
             "herramientas que solo el dueño del negocio puede ver: métricas avanzadas, "
             "gestión de accesos de empleados, configuración global del negocio."),
            ("Estado", [
                "1 archivo .dart — módulo compacto",
                "El acceso se controla en Firestore Rules: esPropietario(empresaId)",
            ]),
        ]
    )

def pdf_servicios():
    pdf_simple("22_servicios.pdf",
        "Servicios (#31)",
        "Catálogo de servicios del negocio (peluquería, spa, etc.)",
        colors.HexColor("#0F766E"),
        [
            ("¿Qué es?",
             "Gestión del catálogo de servicios del negocio (diferente del catálogo de "
             "productos). Un servicio tiene nombre, duración, precio y se puede asignar "
             "a uno o varios empleados. Es la base del TPV Peluquería y del módulo de Reservas."),
            ("Modelo: Servicio", [
                "nombre — Nombre del servicio (ej: 'Corte de pelo')",
                "descripcion — Descripción para el cliente",
                "duracionMin — Duración en minutos",
                "precio — Precio base",
                "empleadoIds — Lista de empleados que pueden realizarlo",
                "categoriaId — Categoría del servicio",
                "activo — Si aparece disponible para reservas",
            ]),
            ("Colecciones Firestore", [
                "empresas/{id}/servicios — Catálogo de servicios",
            ]),
            ("Conexión con otros módulos", [
                "Reservas — Al hacer reserva se elige el servicio",
                "TPV Peluquería — Los servicios son las líneas del ticket",
                "Negocio Público — Los servicios aparecen en la vista pública del negocio",
            ]),
        ]
    )

def pdf_web():
    pdf_simple("23_web.pdf",
        "Web (#32)",
        "Gestión de la web pública del negocio desde la app",
        colors.HexColor("#0284C7"),
        [
            ("¿Qué es?",
             "Permite al negocio gestionar su web pública integrada en la plataforma Fluix: "
             "páginas de contenido, blog, SEO y analytics de visitas. "
             "También soporta integración con WordPress para negocios que ya tienen web propia."),
            ("Qué se puede gestionar", [
                "Páginas de contenido (nosotros, contacto, servicios)",
                "Blog con artículos (tab_blog_web.dart en Dashboard)",
                "SEO: meta títulos, descripciones, palabras clave (tab_seo_web.dart)",
                "Analytics: visitas, páginas más vistas, fuentes de tráfico",
                "Script de integración para incrustar widgets en webs externas",
            ]),
            ("Colecciones Firestore", [
                "empresas/{id}/contenido_web — Páginas y artículos del blog",
                "empresas/{id}/secciones_web — Secciones de la home",
                "empresas/{id}/estadisticas/web_resumen — Analytics de visitas",
            ]),
            ("Cloud Functions", [
                "registrarVisita — Callable: tracking de visitas a la web pública",
            ]),
        ]
    )

def pdf_fidelizacion():
    pdf_simple("24_fidelizacion.pdf",
        "Fidelización",
        "Sellos digitales por QR, check-in y recompensas",
        colors.HexColor("#7C3AED"),
        [
            ("¿Qué es?",
             "Sistema de tarjeta de fidelización digital. El cliente acumula sellos "
             "escaneando un QR en cada visita. Al completar la tarjeta obtiene una recompensa. "
             "Los sellos tienen fecha de caducidad configurable."),
            ("Cómo funciona", [
                "El negocio configura: N sellos para recompensa, tipo de recompensa, caducidad",
                "El cliente muestra su QR personal desde la app",
                "El staff escanea el QR → onCheckinFidelizacion (CF) valida y añade sello",
                "Al completar la tarjeta → recompensa disponible automáticamente",
            ]),
            ("Cloud Functions", [
                "onCheckinFidelizacion — Callable: valida QR y registra sello",
                "marcarQRsExpirados — Scheduled: limpia QR vencidos",
                "verificarCaducidadSellos — Scheduled: caducar sellos expirados",
            ]),
            ("Colecciones Firestore", [
                "empresas/{id}/fidelizacion — Configuración del programa",
                "usuarios/{uid}/sellos — Sellos del cliente por empresa",
            ]),
        ]
    )

# ═══════════════════════════════════════════════════════════════════════════════
# PDF 25 — GUÍA FORMULARIOS WEB DE RESERVAS
# ═══════════════════════════════════════════════════════════════════════════════
def pdf_guia_formularios_web():
    VERDE_WEB = colors.HexColor("#059669")
    AZUL_WEB  = colors.HexColor("#1565C0")
    NARANJA   = colors.HexColor("#D97706")
    MORADO    = colors.HexColor("#7C3AED")

    c = [
        cabecera_modulo(
            "Formularios Web de Reservas",
            "Cómo crear el HTML de cada empresa — guía completa de integración",
            estado="Referencia técnica",
            color=VERDE_WEB
        ),
        sp(10),

        # ── ¿Qué es? ──────────────────────────────────────────────────────────
        h2("Concepto general"),
        p("Cada empresa tiene su propio formulario web (HTML) con su diseño, colores y campos "
          "únicos. Todos comparten un único archivo JavaScript — <b>fluix-reservas-core.js</b> — "
          "que contiene la lógica de conexión con Firebase, lectura de horarios y envío de reservas. "
          "El HTML solo declara sus campos y vincula su empresa con una sola línea."),
        sp(6),

        # ── Diagrama arquitectura ─────────────────────────────────────────────
        h2("Arquitectura: 1 script, N formularios"),
        tabla([
            ["Archivo", "Quién lo toca", "Contenido"],
            ["fluix-reservas-core.js", "Nunca se modifica", "Toda la lógica: Firebase, horarios,\naforo, bloqueos, envío a Firestore"],
            ["restaurante-a.html", "Diseñador del cliente A", "CSS propio · Campos propios · 1 línea con UID"],
            ["peluqueria-b.html", "Diseñador del cliente B", "CSS propio · Campos propios · 1 línea con UID"],
            ["hotel-c.html", "Diseñador del cliente C", "CSS propio · Campos propios · 1 línea con UID"],
        ], col_widths=[4.5*cm, 4*cm, 7.5*cm]),
        sp(6),
        p("Todos los HTML se hospedan en la misma carpeta del servidor junto con "
          "<b>fluix-reservas-core.js</b>. Solo ese archivo incluye credenciales de Firebase."),
        sp(8),

        # ── Lo mínimo que debe tener cada HTML ───────────────────────────────
        h2("Estructura mínima de cada HTML"),
        p("Estos son los 4 bloques imprescindibles. El resto (CSS, estructura, campos) "
          "es completamente libre:"),
        sp(4),

        h3("Bloque 1 — Firebase SDK (siempre igual, 3 líneas)"),
        p("Incluir al inicio del <b>&lt;body&gt;</b> o al final. Son las mismas para todas las empresas:"),
        code('&lt;script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js"&gt;&lt;/script&gt;'),
        code('&lt;script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-auth-compat.js"&gt;&lt;/script&gt;'),
        code('&lt;script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js"&gt;&lt;/script&gt;'),
        sp(6),

        h3("Bloque 2 — Script compartido de lógica"),
        p("Solo una línea. Misma para todos:"),
        code('&lt;script src="fluix-reservas-core.js"&gt;&lt;/script&gt;'),
        sp(6),

        h3("Bloque 3 — Formulario HTML con campos propios"),
        p("El <b>id</b> del &lt;form&gt; es <b>reservaForm</b> por defecto (configurable). "
          "Los campos <b>fecha</b> y <b>hora</b> son obligatorios. El resto son libres:"),
        code('&lt;form id="reservaForm"&gt;'),
        code('  &lt;input type="date" id="fecha" required&gt;    &lt;!-- OBLIGATORIO --&gt;'),
        code('  &lt;select id="hora" required&gt;&lt;/select&gt;         &lt;!-- OBLIGATORIO: el script lo rellena --&gt;'),
        code('  &lt;span id="slotInfo"&gt;&lt;/span&gt;                  &lt;!-- muestra disponibilidad --&gt;'),
        code('  &lt;input type="text" id="nombre" required&gt;   &lt;!-- campo propio --&gt;'),
        code('  &lt;input type="tel"  id="telefono"&gt;          &lt;!-- campo propio --&gt;'),
        code('  &lt;!-- ... cualquier otro campo que necesite la empresa --&gt;'),
        code('  &lt;button type="submit" id="btnReservar"&gt;Reservar&lt;/button&gt;'),
        code('  &lt;div id="formMsg"&gt;&lt;/div&gt;'),
        code('&lt;/form&gt;'),
        sp(6),

        h3("Bloque 4 — Vincular con la empresa (1 línea a cambiar)"),
        p("Al final del &lt;body&gt;. <b>La única línea diferente entre empresas es EMPRESA_ID</b>:"),
        code("&lt;script&gt;"),
        code("var EMPRESA_ID = 'TUz8GOnQ6OX8ejiov7c5GM9LFPl2';  // ← SOLO ESTO CAMBIA"),
        code(""),
        code("FluixReservas.init(EMPRESA_ID, {"),
        code("  // Campos extra a guardar en Firestore (ids de tus inputs)"),
        code("  camposExtra: ['nombre', 'telefono', 'email', 'personas']"),
        code("});"),
        code("&lt;/script&gt;"),
        sp(8),

        # ── Dónde encontrar el EMPRESA_ID ────────────────────────────────────
        h2("Dónde encontrar el EMPRESA_ID"),
        tabla([
            ["Paso", "Acción"],
            ["1", "Abrir la app Fluix con la cuenta del negocio"],
            ["2", "Ir a Módulo de Reservas → Configuración de Reservas"],
            ["3", "Pulsar la pestaña 'Web' (la cuarta)"],
            ["4", "El ID aparece en el panel 'Tu URL de reservas' — pulsar Copiar"],
        ], col_widths=[1.5*cm, 14.5*cm]),
        sp(8),

        # ── Opciones de configuración ─────────────────────────────────────────
        h2("Opciones completas de FluixReservas.init()"),
        tabla([
            ["Parámetro", "Valor por defecto", "Para qué sirve"],
            ["formId", "'reservaForm'", "id del &lt;form&gt; principal"],
            ["campoFecha", "'fecha'", "id del input type=date"],
            ["campoHora", "'hora'", "id del select de horario (rellena automáticamente)"],
            ["idSlotInfo", "'slotInfo'", "id del elemento que muestra disponibilidad"],
            ["idBotonEnviar", "'btnReservar'", "id del botón submit"],
            ["idMensaje", "'formMsg'", "id del div de resultado (éxito/error)"],
            ["idAvisoInactivo", "'reservaDesactivadoAviso'", "id del div que se muestra si web desactivada"],
            ["camposExtra", "[]", "ids de los inputs a guardar en Firestore"],
            ["mensajeExito", "texto genérico", "function(datos) → string de mensaje de éxito"],
            ["onExito", "undefined", "function(datos) → callback tras reserva guardada"],
        ], col_widths=[4*cm, 4.5*cm, 7.5*cm]),
        sp(4),
        p("<b>Nota:</b> Si usas los id por defecto (reservaForm, fecha, hora, slotInfo, btnReservar, "
          "formMsg) no necesitas declarar ninguna opción salvo <b>camposExtra</b>."),
        sp(8),

        # ── camposExtra: cómo funciona ────────────────────────────────────────
        h2("Cómo declarar camposExtra"),
        p("El array <b>camposExtra</b> contiene los ids de los inputs que quieres guardar "
          "en Firestore junto con la reserva. El script detecta automáticamente el tipo "
          "de cada campo:"),
        tabla([
            ["Tipo de campo", "Cómo se recoge el valor"],
            ["input text/email/tel/number", "element.value.trim()"],
            ["select", "element.value"],
            ["textarea", "element.value.trim()"],
            ["input type=radio", "Se busca el radio con :checked del mismo name"],
            ["input type=checkbox", "Devuelve 'si' si está marcado, 'no' si no"],
        ], col_widths=[5*cm, 11*cm]),
        sp(6),
        p("Ejemplo con 7 campos (restaurante con campo exclusivo):"),
        code("camposExtra: ['nombre', 'telefono', 'email', 'personas', 'zona', 'alergenos', 'ocasion']"),
        sp(4),
        p("Ejemplo con 4 campos (peluquería):"),
        code("camposExtra: ['nombre', 'telefono', 'servicio', 'notas']"),
        sp(8),

        # ── Qué sincroniza automáticamente ───────────────────────────────────
        h2("Qué lee el formulario de Firestore automáticamente"),
        p("Todo esto se configura en la app Fluix y se sincroniza sin tocar el HTML:"),
        tabla([
            ["Qué se configura en la app", "Efecto en el formulario web"],
            ["Días activos de la semana", "Bloquea días no activos al seleccionar fecha"],
            ["Horario de apertura/cierre por día", "Genera los slots de hora automáticamente"],
            ["Slots personalizados por día", "Muestra exactamente esos horarios (no auto-generados)"],
            ["Duración del slot (15/30/45/60 min...)", "Determina la frecuencia de los slots"],
            ["Días específicos cerrados + motivo", "Bloquea esa fecha y muestra el motivo"],
            ["Días recurrentes cerrados (ej: lunes)", "Bloquea todos los lunes, martes, etc."],
            ["Intervalo de fechas (vacaciones)", "Bloquea ese rango y muestra el motivo"],
            ["Aforo máximo por franja", "Deshabilita slots que ya tienen ese número de reservas"],
            ["Reservas web activas (toggle)", "Oculta el formulario si está desactivado"],
        ], col_widths=[7*cm, 9*cm]),
        sp(4),
        p("La sincronización es en <b>tiempo real</b>: si el propietario cambia algo en la app y "
          "guarda, el formulario web lo refleja al instante (Firestore onSnapshot)."),
        sp(8),

        # ── Dónde se guardan las reservas ─────────────────────────────────────
        h2("Dónde se guardan las reservas en Firestore"),
        p("Cada reserva enviada desde el formulario web se guarda en:"),
        code("empresas/{EMPRESA_ID}/reservas/{nuevaReservaId}"),
        sp(4),
        p("Con los siguientes campos:"),
        tabla([
            ["Campo", "Valor"],
            ["fecha_hora", "Timestamp Firestore (fecha + hora seleccionada)"],
            ["hora", "String 'HH:mm' (ej: '14:30')"],
            ["estado", "'PENDIENTE'"],
            ["origen", "'web'"],
            ["fecha_creacion", "Timestamp servidor"],
            ["...camposExtra", "Todos los campos declarados en camposExtra con su valor"],
        ], col_widths=[4*cm, 12*cm]),
        sp(4),
        p("La reserva aparece inmediatamente en el módulo de Reservas de la app del negocio."),
        sp(8),

        # ── IDs de los elementos obligatorios ────────────────────────────────
        h2("Checklist de elementos HTML obligatorios"),
        *bul([
            "<b>input type=date id=\"fecha\"</b> — selector de fecha (el script le pone el mínimo = hoy)",
            "<b>select id=\"hora\"</b> — el script lo rellena con los slots disponibles",
            "<b>button type=submit id=\"btnReservar\"</b> — envía el formulario",
            "<b>span id=\"slotInfo\"</b> — (recomendado) muestra el mensaje de disponibilidad",
            "<b>div id=\"formMsg\"</b> — (recomendado) muestra el resultado del envío",
            "<b>p id=\"reservaDesactivadoAviso\"</b> — (recomendado) aviso cuando reservas desactivadas",
        ]),
        sp(8),

        # ── Clases CSS del script ─────────────────────────────────────────────
        h2("Clases CSS que añade el script (para estilizar)"),
        p("El script añade estas clases al elemento #slotInfo. Puedes definir su estilo:"),
        tabla([
            ["Clase CSS", "Cuándo aparece"],
            [".fluix-slot-info", "Siempre (clase base)"],
            [".fluix-slot-info.fluix-ok", "Slot disponible"],
            [".fluix-slot-info.fluix-full", "Slot completo"],
            [".fluix-slot-info.fluix-closed", "Fecha bloqueada"],
        ], col_widths=[5*cm, 11*cm]),
        sp(4),
        p("El mensaje de resultado (#formMsg) usa las clases estándar de Fluix:"),
        code(".form-msg.success  { color: verde; background: verde translúcido }"),
        code(".form-msg.error    { color: rojo;  background: rojo translúcido  }"),
        sp(8),

        # ── Cosas importantes ─────────────────────────────────────────────────
        h2("Cosas importantes a tener en cuenta"),
        sp(4),
        h3("1. El script usa autenticación anónima de Firebase"),
        p("Para poder leer/escribir en Firestore, el script hace login anónimo automáticamente. "
          "No requiere que el cliente esté registrado. Asegúrate de que la autenticación anónima "
          "esté habilitada en Firebase Console → Authentication → Sign-in providers."),
        sp(4),
        h3("2. Reglas de Firestore"),
        p("Las reglas de Firestore deben permitir a usuarios anónimos:"),
        *bul([
            "LEER: empresas/{empresaId}/configuracion/reservas_web",
            "LEER: empresas/{empresaId}/reservas (para contar el aforo por fecha)",
            "ESCRIBIR: empresas/{empresaId}/reservas (para crear nuevas reservas)",
        ]),
        sp(4),
        h3("3. El select de hora es rellenado por el script — no pongas opciones"),
        p("El &lt;select id=\"hora\"&gt; debe estar vacío o con una opción placeholder. "
          "El script lo llena automáticamente cuando el usuario selecciona una fecha. "
          "Si pones opciones manuales, el script las reemplazará."),
        sp(4),
        h3("4. El formulario detecta si las reservas están desactivadas"),
        p("Si el propietario desactiva las reservas web desde la app, el formulario se oculta "
          "automáticamente y aparece el elemento #reservaDesactivadoAviso. "
          "Pon ese elemento en el HTML aunque sea con display:none — el script lo gestiona."),
        sp(4),
        h3("5. El aforo se consulta en Firestore (no localStorage)"),
        p("A diferencia de versiones anteriores, el aforo máximo por franja se consulta "
          "directamente en Firestore al seleccionar una fecha. Esto garantiza que si dos "
          "personas abren el formulario a la vez, ambas ven la disponibilidad real."),
        sp(8),

        # ── Ejemplo rápido completo ───────────────────────────────────────────
        h2("Ejemplo mínimo completo (5 campos)"),
        code("&lt;!-- Firebase SDK --&gt;"),
        code('&lt;script src="firebase-app-compat.js"&gt;&lt;/script&gt;'),
        code('&lt;script src="firebase-auth-compat.js"&gt;&lt;/script&gt;'),
        code('&lt;script src="firebase-firestore-compat.js"&gt;&lt;/script&gt;'),
        code('&lt;script src="fluix-reservas-core.js"&gt;&lt;/script&gt;'),
        sp(4),
        code("&lt;form id='reservaForm'&gt;"),
        code("  &lt;input type='text'  id='nombre'   required&gt;"),
        code("  &lt;input type='tel'   id='telefono' required&gt;"),
        code("  &lt;input type='date'  id='fecha'    required&gt;"),
        code("  &lt;select            id='hora'     required&gt;&lt;/select&gt;"),
        code("  &lt;span id='slotInfo'&gt;&lt;/span&gt;"),
        code("  &lt;select id='personas'&gt;...&lt;/select&gt;"),
        code("  &lt;button type='submit' id='btnReservar'&gt;Reservar&lt;/button&gt;"),
        code("  &lt;div id='formMsg'&gt;&lt;/div&gt;"),
        code("&lt;/form&gt;"),
        sp(4),
        code("&lt;script&gt;"),
        code("  FluixReservas.init('EMPRESA_ID_AQUI', {"),
        code("    camposExtra: ['nombre', 'telefono', 'personas']"),
        code("  });"),
        code("&lt;/script&gt;"),
        sp(8),

        # ── Resumen ───────────────────────────────────────────────────────────
        h2("Resumen: lo que cambia por empresa"),
        tabla([
            ["Qué", "¿Cambia entre empresas?", "Notas"],
            ["fluix-reservas-core.js", "NO", "Un único archivo para todos"],
            ["Firebase SDK (3 scripts)", "NO", "Siempre los mismos CDN"],
            ["EMPRESA_ID", "SÍ — única diferencia", "Copiar desde la app: Reservas → Web"],
            ["camposExtra", "SÍ", "Los ids de los inputs de ese formulario"],
            ["CSS / diseño visual", "SÍ", "Completamente libre"],
            ["Campos del formulario", "SÍ", "Cada empresa pone los que necesita"],
            ["mensajeExito (opcional)", "SÍ", "Para personalizar el texto de confirmación"],
        ], col_widths=[4.5*cm, 4*cm, 7.5*cm]),
    ]
    build("25_guia_formularios_web_reservas.pdf", c)


# ═══════════════════════════════════════════════════════════════════════════════
# EJECUTAR TODOS
# ═══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print("Generando PDFs de Fluix CRM...")
    pdf_dashboard()
    pdf_tpv_root()
    pdf_tpv_peluqueria()
    pdf_pedidos()
    pdf_empleados()
    pdf_negocio_publico()
    pdf_pdf_templates()
    pdf_vacaciones()
    pdf_fichajes()
    pdf_perfil()
    pdf_clientes()
    pdf_explorar_negocios()
    pdf_valoraciones()
    pdf_registro()
    pdf_reservas()
    pdf_flash_slots()
    pdf_tienda_monedas()
    pdf_suscripcion()
    pdf_pdf_editor()
    pdf_onboarding()
    pdf_propietario()
    pdf_servicios()
    pdf_web()
    pdf_fidelizacion()
    pdf_guia_formularios_web()
    print(f"\nListo -- {len(os.listdir(OUT))} PDFs en funcionamiento/pdf/")

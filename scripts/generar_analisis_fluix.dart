// ignore_for_file: avoid_print
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final doc = pw.Document();

  // ── Paleta ───────────────────────────────────────────────────────────
  const primary   = PdfColor.fromInt(0xFF0D1B4B);
  const accent    = PdfColor.fromInt(0xFF1565C0);
  const cyan      = PdfColor.fromInt(0xFF00BFA5);
  const warn      = PdfColor.fromInt(0xFFB71C1C);
  const ok        = PdfColor.fromInt(0xFF1B5E20);
  const gold      = PdfColor.fromInt(0xFFE65100);
  const neutral   = PdfColor.fromInt(0xFF263238);
  const bgLight   = PdfColor.fromInt(0xFFF8F9FA);
  const bgWarn    = PdfColor.fromInt(0xFFFFF8E1);
  const bgOk      = PdfColor.fromInt(0xFFE8F5E9);
  const bgCyan    = PdfColor.fromInt(0xFFE0F7FA);
  const divider   = PdfColor.fromInt(0xFFCFD8DC);

  // ── Estilos ──────────────────────────────────────────────────────────
  final coverTitle  = pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold, color: PdfColors.white, lineSpacing: 4);
  final h1          = pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: primary);
  final h2          = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent);
  final h3          = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: neutral);
  final body        = pw.TextStyle(fontSize: 9.2, color: neutral, lineSpacing: 1.4);
  final bodyBold    = pw.TextStyle(fontSize: 9.2, fontWeight: pw.FontWeight.bold, color: neutral);
  final bodyWarn    = pw.TextStyle(fontSize: 9.2, color: warn, fontWeight: pw.FontWeight.bold);
  final bodyOk      = pw.TextStyle(fontSize: 9.2, color: ok, fontWeight: pw.FontWeight.bold);
  final small       = pw.TextStyle(fontSize: 8.5, color: neutral);
  final smallMuted  = pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic);
  final tableHead   = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
  final tableCell   = pw.TextStyle(fontSize: 8.2, color: neutral);

  // ── Helpers ───────────────────────────────────────────────────────────
  pw.Widget secHeader(String num, String title) => pw.Container(
    decoration: const pw.BoxDecoration(
      gradient: pw.LinearGradient(colors: [primary, accent]),
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    margin: const pw.EdgeInsets.only(top: 14, bottom: 10),
    child: pw.Row(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: pw.BoxDecoration(color: cyan, borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Text(num, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ),
      pw.SizedBox(width: 8),
      pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    ]),
  );

  pw.Widget subHead(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10, bottom: 5),
    child: pw.Row(children: [
      pw.Container(width: 3, height: 14, color: cyan, margin: const pw.EdgeInsets.only(right: 7)),
      pw.Text(t, style: h2),
    ]),
  );

  pw.Widget bullet(String label, String body_, {bool warn_ = false, bool ok_ = false, bool gold_ = false}) {
    final c = warn_ ? warn : (ok_ ? ok : (gold_ ? gold : accent));
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(margin: const pw.EdgeInsets.only(top: 4, right: 7), width: 5, height: 5,
            decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle)),
        pw.Expanded(child: pw.RichText(text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label ', style: bodyBold),
          pw.TextSpan(text: body_, style: body),
        ]))),
      ]),
    );
  }

  pw.Widget callout(String text, {bool isWarn = false, bool isOk = false, bool isCyan = false, bool isGold = false}) {
    final bg = isWarn ? bgWarn : (isOk ? bgOk : (isCyan ? bgCyan : bgLight));
    final border = isWarn ? warn : (isOk ? ok : (isCyan ? cyan : divider));
    final ts = isWarn ? bodyWarn : (isOk ? bodyOk : body);
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bg, borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: border, width: 0.7),
      ),
      padding: const pw.EdgeInsets.all(9),
      margin: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Text(text, style: ts),
    );
  }

  pw.Widget tbl(List<String> heads, List<List<String>> rows, {List<double>? widths}) {
    int ri = 0;
    pw.TableRow mkRow(List<String> cells, bool head) {
      final bg = head ? primary : (ri++ % 2 == 0 ? bgLight : PdfColors.white);
      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: cells.map((c) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Text(c, style: head ? tableHead : tableCell, maxLines: 4),
        )).toList(),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: divider, width: 0.5),
      columnWidths: widths != null ? {for (var i = 0; i < widths.length; i++) i: pw.FixedColumnWidth(widths[i])} : null,
      children: [mkRow(heads, true), ...rows.map((r) => mkRow(r, false))],
    );
  }

  pw.Widget kpi(String val, String lbl, PdfColor c) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 3),
      padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 5),
      decoration: pw.BoxDecoration(color: c, borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(children: [
        pw.Text(val, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        pw.SizedBox(height: 2),
        pw.Text(lbl, style: pw.TextStyle(fontSize: 7, color: PdfColors.white), textAlign: pw.TextAlign.center),
      ]),
    ),
  );

  pw.Widget badge(String t, PdfColor c) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: pw.BoxDecoration(color: c, borderRadius: pw.BorderRadius.circular(10)),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 7.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // P0 — PORTADA
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero,
    build: (_) => pw.Stack(children: [
      pw.Container(decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight,
            colors: [PdfColor.fromInt(0xFF0A1628), PdfColor.fromInt(0xFF0D3D6B)]),
      )),
      pw.Padding(padding: const pw.EdgeInsets.all(52), child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 50),
          pw.Row(children: [
            pw.Container(width: 4, height: 42, color: cyan),
            pw.SizedBox(width: 12),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('FLUIX TECH', style: pw.TextStyle(fontSize: 10, letterSpacing: 4,
                  color: PdfColor(0, 1, 0.78, 0.9), fontWeight: pw.FontWeight.bold)),
              pw.Text('Plataforma de gestión + marketplace para negocios locales',
                  style: pw.TextStyle(fontSize: 9, color: PdfColor(1, 1, 1, 0.55))),
            ]),
          ]),
          pw.SizedBox(height: 28),
          pw.Text('Análisis Estratégico\nProfundo de Producto', style: coverTitle),
          pw.SizedBox(height: 16),
          pw.Container(width: 80, height: 2, color: cyan),
          pw.SizedBox(height: 18),
          pw.Text(
            'Evaluación completa de Fluix como plataforma dual B2B+B2C:\n'
            'herramienta de gestión para negocios y app de descubrimiento\n'
            'y reservas para consumidores finales.',
            style: pw.TextStyle(fontSize: 11.5, color: PdfColor(1, 1, 1, 0.72), lineSpacing: 3),
          ),
          pw.Spacer(),
          pw.Row(children: [
            _coverStat('2 lados', 'B2B + B2C'),
            pw.SizedBox(width: 14),
            _coverStat('15+', 'módulos'),
            pw.SizedBox(width: 14),
            _coverStat('50+', 'trofeos gamificación'),
            pw.SizedBox(width: 14),
            _coverStat('11', 'categorías negocio'),
          ]),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColor(1, 1, 1, 0.15), thickness: 0.5),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Septiembre 2026  ·  Análisis interno  ·  Uso confidencial',
                style: pw.TextStyle(fontSize: 8, color: PdfColor(1, 1, 1, 0.4))),
            pw.Text('v1.0.15', style: pw.TextStyle(fontSize: 8, color: PdfColor(1, 1, 1, 0.3))),
          ]),
        ],
      )),
    ]),
  ));

  // ═══════════════════════════════════════════════════════════════════════
  // P1 — RESUMEN EJECUTIVO
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 38),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Resumen Ejecutivo', style: h1),
      pw.SizedBox(height: 2),
      pw.Text('Análisis profundo — 7 secciones — Septiembre 2026', style: smallMuted),
      pw.Divider(color: accent, thickness: 0.8),
      pw.SizedBox(height: 10),

      pw.Text(
        'El error habitual al analizar Fluix es tratarlo como un SaaS de gestión más para negocios. '
        'Es incorrecto. Fluix es una plataforma de dos lados: por un lado, un software completo de '
        'gestión (TPV, reservas, facturación, empleados, web CMS, e-commerce, fidelización) para '
        'propietarios de negocio. Por otro, una app de descubrimiento, reservas y recompensas para '
        'consumidores finales, con un sistema de gamificación (50+ trofeos, monedas virtuales, '
        'tienda de canjes, flash slots) que no existe en ningún competidor directo del mercado '
        'español a septiembre 2026.',
        style: body,
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Esta dualidad cambia completamente el análisis competitivo, el modelo de negocio, '
        'el TAM potencial y la estrategia de distribución. Fluix no compite solo con Holded o '
        'Sage: compite con Fresha, Treatwell y Mindbody — y tiene funcionalidades que ellos '
        'no tienen (Verifactu, CMS web integrado, multi-categoría, gamificación avanzada).',
        style: body,
      ),
      pw.SizedBox(height: 12),

      pw.Row(children: [
        kpi('2 lados', 'Plataforma\nB2B + B2C', primary),
        kpi('~1.2M', 'Negocios\nobjetivo ES', accent),
        kpi('~75%', 'Margen bruto\npotencial', cyan),
        kpi('≈50M+', 'Consumidores\nalcanzables ES', gold),
      ]),
      pw.SizedBox(height: 12),

      subHead('Lo que el análisis anterior perdió por no mirar "Explorar"'),
      bullet('Efecto de red real:', 'cada negocio en la plataforma trae a sus clientes a la app; cada cliente activo da visibilidad al negocio → crecimiento orgánico bidireccional.', ok_: true),
      bullet('Sistema de gamificación único:', '50+ trofeos, monedas, tienda de canjes, flash slots con countdown — no existe en Treatwell, Fresha ni Booksy en España.', ok_: true),
      bullet('Flash Slots:', 'las ofertas con cuenta atrás en tiempo real son una herramienta de revenue management para el negocio y urgencia de compra para el cliente — modelo cercano a Lastminute.', ok_: true),
      bullet('Monetización dual posible:', 'SaaS (negocio paga mensualidad) + marketplace (comisión por reserva nueva vía app consumidor) como hace Fresha.', gold_: true),
      bullet('Barrera real vs. competidores que solo tienen un lado:', 'un negocio que ya tiene sus clientes en la app Fluix no se va a Holded aunque Holded sea más barato.', ok_: true),

      pw.SizedBox(height: 12),
      subHead('Veredicto ajustado'),
      callout(
        'Fluix es un producto más sofisticado de lo que parece a primera vista. '
        'La capa B2C con gamificación es su diferencial más potente y el que más tarda en copiarse. '
        'El problema sigue siendo distribución, no producto. Si consigue masa crítica de consumidores '
        'en una ciudad/nicho, el efecto de red hace casi imposible que los negocios se vayan.',
        isCyan: true,
      ),

      pw.SizedBox(height: 8),
      pw.Text('Estructura del informe:', style: h3),
      pw.SizedBox(height: 5),
      tbl(
        ['#', 'Sección', 'Pregunta clave'],
        [
          ['01', 'Producto B2B (gestión)', '¿Qué hace exactamente y dónde está frente al mercado?'],
          ['02', 'Producto B2C (Explorar)', '¿Qué tiene la app consumidor y qué ventaja da?'],
          ['03', 'Competidores', '¿Con quién compite realmente en cada lado?'],
          ['04', 'Economía', '¿ARPU, márgenes, clientes necesarios para ser sostenible?'],
          ['05', 'Mercado', '¿Tamaño real, segmentos y expansión?'],
          ['06', 'Riesgos', '¿Qué puede matar el negocio?'],
          ['07', 'Conclusión', '¿Qué es Fluix hoy y qué 5 cambios más impacto tendrían?'],
        ],
        widths: [18, 130, 302],
      ),
    ]),
  ));

  // ═══════════════════════════════════════════════════════════════════════
  // P2 — SECCIÓN 01: PRODUCTO B2B
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 38),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      secHeader('01', 'Producto B2B — Herramienta de gestión para negocios'),

      subHead('Inventario de módulos implementados'),
      tbl(
        ['Módulo', 'Funcionalidad real implementada', 'Nivel vs mercado'],
        [
          ['TPV', 'Caja, ticket, impresora BT térmica, escáner cámara, series, formas de pago', '✅ Nivel mercado'],
          ['Reservas/Agenda', 'Calendario, franjas horarias, formularios dinámicos por negocio, estados, notificaciones', '✅ Nivel mercado'],
          ['Clientes (CRM)', 'Ficha, historial, tareas asociadas, segmentación básica, notas', '⚠️ Por detrás en automatización'],
          ['Empleados', 'Alta, roles, módulos por empleado, control horario GPS, fichaje, tareas', '✅ Nivel mercado'],
          ['Facturación / Fiscal', 'Facturas, presupuestos, series, Verifactu (RD 1007/2023), firma XAdES, SII preparado', '✅ Por delante (Verifactu nativo)'],
          ['Inventario', 'Productos, stock, alertas, variantes, escáner, sincronizado con TPV', '✅ Nivel mercado'],
          ['Web CMS', 'Blog, noticias, galería, catálogo, secciones, editor WYSIWYG, publicación Hostinger', '✅ Por delante (único all-in-one)'],
          ['E-commerce', 'Tienda online, pedidos web, Stripe, catálogo sincronizado, gestión pedidos', '⚠️ Básico (sin envíos, sin devoluciones)'],
          ['Fidelización', 'Tarjeta sellos QR, escáner offline, historial, premios configurables', '✅ Por delante (propio, sin terceros)'],
          ['Valoraciones', 'Reseñas Fluix con verificación, respuesta del negocio, rating nativo', '✅ Diferencial'],
          ['Estadísticas', 'Ventas, productos, empleados, gráficas fl_chart, exportación PDF', '⚠️ Básico; sin BI avanzado'],
          ['Fichaje', 'Entrada/salida GPS, reportes, calendario vacaciones', '✅ Nivel mercado'],
          ['Pedidos', 'Gestión pedidos internos y web, estados, fechas, tienda', '⚠️ En maduración'],
          ['WhatsApp', 'Integración mensajes (Twilio), campañas básicas', '⚠️ Incipiente'],
          ['Automatizaciones', 'Resend emails, Cloud Functions, triggers Firebase', '⚠️ Sin interfaz visual tipo Zapier'],
        ],
        widths: [80, 260, 110],
      ),

      subHead('Diferencial B2B real frente al mercado'),
      bullet('Verifactu nativo completo:', 'RD 1007/2023, huella SHA-256, firma XAdES, cadena de registros — ningún competidor de su rango de precio lo tiene al 100%.', ok_: true),
      bullet('Web CMS + tienda + TPV en un mismo producto:', 'publicar un post del blog desde la misma app que registra una venta es algo que no existe en la competencia.', ok_: true),
      bullet('Formularios de reserva dinámicos:', 'cada negocio configura sus propios campos — una clínica pide historial, una academia pide nivel. Fresha/Booksy tienen campos fijos.', ok_: true),
      bullet('Multi-vertical desde el diseño:', 'peluquería, hostelería, comercio, servicios — no es un vertical adaptado a posteriori.', ok_: true),

      callout(
        '⚠ Debilidades B2B que siguen siendo reales:\n'
        '• Sin integración bancaria/conciliación (Holded lo lleva ventaja de años)\n'
        '• Sin exportación contable directa a A3/ContaPlus (objeción frecuente de gestorías)\n'
        '• E-commerce sin lógica de envíos ni devoluciones (no compite con Shopify)\n'
        '• WhatsApp y automatizaciones incipientes (Clientify está años por delante aquí)\n'
        '• Sin BI real ni dashboards avanzados (Holded tiene informes contables; Fluix no)',
        isWarn: true,
      ),
    ]),
  ));

  // ═══════════════════════════════════════════════════════════════════════
  // P3 — SECCIÓN 02: PRODUCTO B2C (EXPLORAR)
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 38),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      secHeader('02', 'Producto B2C — App "Explorar" para consumidores finales'),

      callout(
        'Esta sección es la más importante del informe. La app de consumidor es el elemento '
        'que diferencia Fluix de cualquier otro SaaS de gestión para pymes, '
        'y el que crea la barrera de entrada más difícil de copiar.',
        isCyan: true,
      ),

      subHead('Estructura de la app consumidor'),
      tbl(
        ['Pantalla / Módulo', 'Funcionalidades clave', 'Diferencial'],
        [
          ['TAB Explorar', 'Chips por 11 categorías, carrusel Flash Slots con countdown, secciones "Recomendados" / "Cerca de ti" / "Ofertas especiales" / "Favorito aleatorio diario"', '★ Flash Slots únicos en España'],
          ['TAB Buscar', 'Búsqueda text client-side, filtro por categorías múltiples, 200 negocios en cache local', '★ Offline-first'],
          ['TAB Favoritos', 'Grid guardados con orden por recientes/rating/nombre, acceso directo', 'Estándar'],
          ['Detalle negocio (6 tabs)', 'Reservar, Info (horarios/contacto), Reseñas Fluix, Servicios, Galería, Política de cancelación', '★ Reseñas Fluix verificadas'],
          ['Sistema de reservas', 'Calendario disponibilidad codificado por color, formularios dinámicos, confirmación en tiempo real', '★ Formularios dinámicos por negocio'],
          ['Flash Slots', 'Ofertas con countdown en tiempo real, plazas, foto, precio con descuento, reserva directa', '★ Revenue management para negocio'],
          ['Geolocalización', 'Ordenar por distancia Haversine, badge abierto/cerrado por minuto, "Cerca de ti"', 'Estándar (como Fresha)'],
          ['Filtros avanzados', 'Rango precio €0-200, rating mínimo, "Solo abiertos ahora"', 'Estándar'],
          ['Trofeos (50+)', 'Más de 50 trofeos por categorías, progreso visual, desbloqueo animado, confeti', '★★ Único en el mercado'],
          ['Monedas virtuales', 'Saldo, historial transacciones, multiplicador 2x, ganancia por reservas/reseñas', '★★ Único en el mercado'],
          ['Tienda de canjes', 'Marcos de avatar, temas, títulos, multiplicadores, caja misteriosa (loot box)', '★★ Único en el mercado'],
          ['Notificaciones cliente', 'Confirmación reserva, cambio estado, respuesta reseña, badge con contador', 'Estándar'],
          ['Perfil personalizable', '10+ gradientes, emojis, marcos canjeados, avatar pulsante, título, nivel', '★ Gamificación profunda'],
        ],
        widths: [95, 225, 130],
      ),

      subHead('Por qué la gamificación cambia el modelo de negocio'),
      bullet('Retención de consumidores:', 'un usuario con 30 trofeos y saldo de monedas no abandona la app. El coste de oportunidad de irse a Treatwell es perder su "progreso".', ok_: true),
      bullet('Comportamiento de booking:', 'los trofeos premiando "5ª reserva", "1ª reseña" etc. incrementan directamente las métricas que le interesan al negocio.', ok_: true),
      bullet('Los Flash Slots crean urgencia real:', 'un salón puede publicar "2 huecos hoy a las 16h con 20% descuento" → se llena → el cliente ve el countdown → reserva → nadie en el mercado tiene esto.', ok_: true),
      bullet('Reseñas verificadas Fluix:', 'solo puede reseñar quien ha reservado → calidad más alta que Google Reviews → argumento de ventas para negocios que sufren reseñas falsas.', ok_: true),

      callout(
        '⚠ Debilidades críticas del lado B2C:\n'
        '• Sin negocios reales en la app aún = app vacía = nadie la usa. El huevo y la gallina.\n'
        '• Sin app nativa en App Store / Google Play separada para el consumidor — no se puede "descargar Fluix" como cliente sin ser también empleado/dueño.\n'
        '• Sin estrategia de captación de usuarios: cómo sabe un consumidor que existe Fluix?\n'
        '• La gamificación solo funciona si hay masa crítica de negocios y reservas reales.',
        isWarn: true,
      ),
    ]),
  ));

  // ═══════════════════════════════════════════════════════════════════════
  // P4 — SECCIÓN 03: COMPETIDORES
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 38),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      secHeader('03', 'Análisis competitivo — Dos tablas, dos lados del mercado'),

      subHead('Competidores lado B2C (marketplaces de reservas para consumidores)'),
      tbl(
        ['Competidor', 'Modelo negocio', 'Precio negocio', 'Gamificación', 'Multi-cat.', 'CMS web', 'Verifactu'],
        [
          ['Fresha', 'Software gratis + comisión 1-3€ por nueva reserva vía marketplace', 'Gratis*', '✗', '✗ Solo belleza', '✗', '✗'],
          ['Treatwell', 'Suscripción + 30% comisión reservas nuevas marketplace', '€49-99/mes + 30%', '✗', '✗ Solo belleza/spa', '✗', '✗'],
          ['Booksy', 'Suscripción fija', '€59-119/mes', '✗', '✗ Solo belleza', '✗', '✗'],
          ['Mindbody', 'Suscripción + marketplace propio', '€129-349/mes', 'Básico', '✗ Fitness/wellness', '✗', '✗'],
          ['Google/Maps', 'Gratuito; anuncios', 'Gratis (ads)', '✗', '✓', '✗', '✗'],
          ['Fluix (B2C)', 'Suscripción negocio (+ comisión futura posible)', 'Est. €59-99/mes', '✓✓ 50+ trofeos', '✓ 11 cat.', '✓', '✓'],
        ],
        widths: [68, 130, 80, 65, 65, 45, 47],
      ),

      subHead('Competidores lado B2B (software de gestión para negocios)'),
      tbl(
        ['Competidor', 'Segmento', 'Precio/mes', 'TPV físico', 'Reservas', 'Web CMS', 'Verifactu', 'App cliente'],
        [
          ['Holded', 'Pymes genérico', '€19-89', '✗', '✗', '✗', 'Parcial', '✗'],
          ['Revo POS', 'Hostelería/Retail', '€59-119', '✓', '✗', '✗', '✗', '✗'],
          ['Glop', 'Hostelería', '€50-100', '✓', '✗', '✗', '✗', '✗'],
          ['Quipu', 'Autónomos', '€19-39', '✗', '✗', '✗', 'Parcial', '✗'],
          ['Clientify', 'CRM/Marketing', '€39-199', '✗', '✗', '✗', '✗', '✗'],
          ['Square', 'Retail/Servicios', '0+comisión', 'Propio', 'Básico', '✗', '✗', '✗'],
          ['Shopify', 'E-commerce', '€29-79', '✗', '✗', 'Tienda', '✗', '✗'],
          ['Fluix (B2B)', 'Multi-vertical', 'Est. €59-99', '✓ BT', '✓ Avanzado', '✓ CMS+blog', '✓ Nativo', '✓ Integrada'],
        ],
        widths: [62, 80, 55, 55, 55, 55, 55, 63],
      ),

      subHead('Conclusión del mapa competitivo'),
      callout(
        'Fluix no tiene un competidor directo real en España que combine los dos lados.\n\n'
        'Los competidores B2C (Fresha, Treatwell) son solo verticales de belleza, sin Verifactu y '
        'sin web CMS. Los competidores B2B (Holded, Revo) no tienen app de consumidor ni gamificación.\n\n'
        'El espacio en el que Fluix opera (gestión integral + marketplace consumidor + gamificación '
        'multi-vertical + fiscal español) está prácticamente vacío en España.\n\n'
        'Esto es una OPORTUNIDAD enorme. También es una ADVERTENCIA: si ese espacio existe, '
        'o nadie lo ha validado todavía (riesgo de mercado) o es difícil de monetizar (riesgo de modelo).',
        isCyan: true,
      ),

      subHead('Ventana de oportunidad vs. entrada de competidores'),
      bullet('Fresha:', 'tiene 250M+ en financiación. Si ve tracción en el multi-vertical español, puede replicar módulos en 12-18 meses. Su ventaja: marketplace. Su desventaja: no adaptará fiscal español fácilmente.', warn_: true),
      bullet('Holded (CaixaBank):', 'tiene espalda financiera y marca. Pero añadir TPV físico + reservas + app consumidor es reescribir el producto. Estimado: 2-3 años si se lo proponen.', warn_: true),
      bullet('Startups nativas:', 'el mayor riesgo. Una startup con €500K bien financiada que copie el modelo tiene ventaja de tiempo y frescura. Fluix necesita marca y clientes antes de que eso ocurra.'),
    ]),
  ));

  // ═══════════════════════════════════════════════════════════════════════
  // P5 — SECCIÓN 04: ECONOMÍA
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 38),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      secHeader('04', 'Economía del producto'),
      callout('⚠ Todo lo económico de Fluix son ESTIMACIONES basadas en benchmarks públicos del sector SaaS y cloud. Se indica cuando se usa un dato real de mercado.', isWarn: true),

      subHead('Modelo de monetización posible (dos palancas)'),
      tbl(
        ['Palanca', 'Descripción', 'ARPU estimado', 'Analogía mercado'],
        [
          ['SaaS B2B (hoy)', 'Suscripción mensual del negocio por usar el software completo', '€59-99/mes', 'Fresha cobró cero hasta masa crítica; Booksy cobra €59-119'],
          ['Comisión marketplace (futuro)', 'Porcentaje o tarifa plana por cada reserva nueva generada desde la app Explorar', '+€1-3 por reserva nueva', 'Fresha: €1-3 por cliente nuevo; Treatwell: 30%'],
          ['Flash Slots premium (futuro)', 'El negocio paga por publicar una oferta flash destacada', '+€5-20 por slot', 'Similar a Lastminute "Offer Boost"'],
          ['Features premium consumidor (futuro)', 'Suscripción opcional para usuarios que quieren trofeos dobles, reservas prioritarias', '+€2-5/mes usuario activo', 'Modelo Duolingo Plus / Tinder Gold'],
        ],
        widths: [90, 180, 90, 100],
      ),

      subHead('Costes de servicio por negocio cliente / mes (ESTIMACIÓN)'),
      tbl(
        ['Coste', 'Base de cálculo', 'Estimación'],
        [
          ['Firebase Firestore', 'Negocio activo: ~50K reads/día + 5K writes/día (datos: precios Firebase oficiales)', '€1.80-3.50'],
          ['Firebase Storage', '~3-6 GB imágenes/PDFs por negocio acumulado', '€0.60-1.20'],
          ['Firebase Functions', 'Thumbnails, Verifactu, emails, triggers activos', '€0.40-0.90'],
          ['Stripe/pagos', 'Si procesa cobros online (~10 transacciones/mes × €25 avg)', '€0.50-1.50'],
          ['Resend / email transaccional', '~300-600 emails/mes por negocio (confirmaciones, recordatorios)', '€0.20-0.50'],
          ['WhatsApp Business API', 'Si usa integración official (360dialog/Twilio) ~50 mensajes/mes', '€0.80-2.50'],
          ['Soporte y mantenimiento', 'Amortización tiempo atención (estimado conservador sin equipo)', '€4.00-8.00'],
          ['TOTAL', '', '€8.30-18.10 / negocio / mes'],
        ],
        widths: [120, 230, 100],
      ),

      pw.SizedBox(height: 6),
      pw.Row(children: [
        kpi('€79', 'ARPU\nestimado/mes', accent),
        kpi('€13', 'Coste medio\nvariable', warn),
        kpi('€66', 'Contribución\npor cliente', ok),
        kpi('84%', 'Margen bruto\npotencial', cyan),
      ]),
      pw.SizedBox(height: 10),

      subHead('Clientes necesarios para cada umbral de beneficio neto'),
      pw.Text('Asumiendo: ARPU €79 · Coste variable €13 · Contribución €66/cliente · Costes fijos €1.800/mes (infraestructura + herramientas, SIN equipo)',
          style: smallMuted),
      pw.SizedBox(height: 5),
      tbl(
        ['Beneficio\nobjetivo/mes', 'Clientes\nnecesarios', 'MRR\nnecesario', 'Escenario'],
        [
          ['€1.000', '~43 clientes', '~€3.400', 'Alcanzable en 6-12 meses con ventas directas activas'],
          ['€3.000', '~73 clientes', '~€5.767', 'Horizonte realista a 12-18 meses'],
          ['€5.000', '~104 clientes', '~€8.216', 'Requiere marketing inbound o equipo comercial'],
          ['€10.000', '~179 clientes', '~€14.141', 'Difícil sin marca o canal de distribución claro'],
          ['€20.000', '~332 clientes', '~€26.228', 'Necesita marca conocida, growth y posiblemente financiación'],
        ],
        widths: [80, 80, 80, 210],
      ),
      callout(
        'Nota: con un equipo de 2-3 personas, los costes fijos subirían a €8.000-18.000/mes, '
        'multiplicando por 4-6x los clientes necesarios para cada umbral. '
        'Con 3 personas y costes fijos de €15.000/mes, necesitaría ~244 clientes para €5.000 de beneficio neto.\n\n'
        'Referencia de mercado (dato real): Fresha tardó ~3 años en llegar a 50.000 negocios con modelo freemium y €80M en financiación. '
        'Booksy llegó a 500 clientes de pago en España en 18 meses con equipo comercial local.',
        isWarn: false,
      ),
    ]),
  ));

  // ═══════════════════════════════════════════════════════════════════════
  // P6 — SECCIÓN 05: MERCADO
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 38),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      secHeader('05', 'Potencial de mercado — España + expansión'),

      subHead('TAM España por segmento (fuente: CNAE / INE 2024-2025, datos públicos)'),
      tbl(
        ['Segmento', 'Establecimientos', 'Sin software avanzado', 'Ticket est./mes', 'Prioridad Fluix'],
        [
          ['Peluquerías y centros de estética', '~92.000', '~60.000 (65%)', '€69-89', '★★★ Máxima'],
          ['Clínicas estética / centros bienestar', '~35.000', '~25.000 (71%)', '€79-99', '★★★ Máxima'],
          ['Academias, formación, clases', '~45.000', '~35.000 (78%)', '€59-79', '★★★ Alta'],
          ['Pequeños comercios con web', '~380.000', '~266.000 (70%)', '€59-79', '★★ Alta'],
          ['Hostelería (bar/restaurante <50 cub.)', '~180.000', '~99.000 (55%)', '€69-89', '★★ Media (sin comandas)'],
          ['Clínicas veterinarias, dentales', '~25.000', '~15.000 (60%)', '€89-119', '★★ Media'],
          ['Servicios profesionales (fisio, coach)', '~80.000', '~50.000 (63%)', '€59-89', '★★ Media'],
          ['Hostelería mediana (50+ cubiertos)', '~100.000', '~30.000 (30%)', '€99+', '★ Baja (sin comandas)'],
          ['TOTAL TAM relevante', '~937.000', '~580.000', '€69-89 avg', ''],
        ],
        widths: [130, 75, 100, 75, 80],
      ),

      subHead('SAM, SOM y proyección realista'),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('TAM total', style: h3),
          pw.Text('~937.000 negocios en España con encaje parcial o total', style: body),
          pw.SizedBox(height: 8),
          pw.Text('SAM (addressable)', style: h3),
          pw.Text('~280.000 negocios con smartphone, internet, disposición a pagar €50-100/mes y necesidad real del producto completo', style: body),
          pw.SizedBox(height: 8),
          pw.Text('SOM realista', style: h3),
          pw.Text('Sin financiación (1 persona): 500-2.000 clientes en 3 años\nCon equipo (2-4 personas): 3.000-8.000 en 3 años\nCon ronda seed: 15.000-40.000 en 4-5 años', style: body),
        ])),
        pw.SizedBox(width: 16),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('El lado B2C: el multiplicador oculto', style: h3),
          pw.SizedBox(height: 4),
          pw.Text(
            'España tiene ~47M de personas. Los consumidores de servicios locales (que reservarían '
            'cita en peluquería, estética, academia) son ~25-30M. Si la app de consumidor alcanza '
            '500K usuarios activos mensuales, el coste de adquisición de negocios cae drásticamente '
            'porque los negocios quieren estar donde están sus clientes.',
            style: body,
          ),
          pw.SizedBox(height: 8),
          pw.Text('Estrategia de entrada recomendada', style: h3),
          pw.SizedBox(height: 4),
          pw.Text('Ciudad piloto → peluquerías/estéticas → 50 negocios → campaña "descarga Fluix, reserva en tu salón favorito" → efecto red local → expansión ciudad a ciudad.', style: body),
        ])),
      ]),

      subHead('Expansión internacional'),
      tbl(
        ['País', 'Atractivo', 'Obstáculo principal', 'Prioridad'],
        [
          ['México', 'Alto: 5.5M micropymes, mismo idioma, pocos líderes locales', 'CFDI (fiscal), competidores locales en CRM', '2ª prioridad (2-3 años)'],
          ['Colombia / Chile', 'Medio: pymes emergentes, poca digitalización', 'Regulación fiscal distinta por país', '3ª (3-4 años)'],
          ['Portugal', 'Bajo-medio: mercado pequeño (1M pymes)', 'SAF-T obligatorio, idioma, mercado pequeño', '2ª (1-2 años)'],
          ['Italia', 'Medio: gran sector belleza/servicios', 'SDI factura electrónica, idioma, competencia local', '4ª (4+ años)'],
        ],
        widths: [65, 155, 140, 100],
      ),
      callout('Recomendación firme: consolidar España (mínimo 1.000 clientes pagando) antes de cualquier expansión. La fragmentación de mercado en fase temprana es una causa frecuente de muerte de producto.', isCyan: true),
    ]),
  ));

  // ═══════════════════════════════════════════════════════════════════════
  // P7 — SECCIÓN 06: RIESGOS
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 38),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      secHeader('06', 'Riesgos — Análisis crítico sin filtros'),

      subHead('Matriz de riesgos'),
      tbl(
        ['Riesgo', 'Prob.', 'Impacto', 'Mitigación'],
        [
          ['Huevo-gallina: sin negocios no hay consumidores, sin consumidores no se venden negocios', 'ALTA', 'CRÍTICO', 'Lanzar en 1 ciudad con 30-50 negocios antes de abrir al público general'],
          ['Bus factor: si el producto depende de 1 desarrollador, un mes de baja = producto muerto', 'ALTA', 'CRÍTICO', 'Documentar arquitectura, externalizar partes, contratar antes de que sea urgente'],
          ['Firebase costes a escala: a 5.000 negocios activos los costes escalan a €15-40K/mes', 'MEDIA', 'ALTO', 'Caché agresiva (ya hay parte implementada), revisar arquitectura si supera 1K clientes'],
          ['Fresha entra en España con fuerza y añade módulos B2B (TPV, fiscal)', 'MEDIA', 'ALTO', 'Acelerar masa crítica consumidores + Verifactu es barrera técnica real'],
          ['Cambios Verifactu / AEAT (revisión constante regulación)', 'ALTA', 'ALTO', 'Canal permanente con asesor fiscal técnico, alertas de cambios legislativos'],
          ['Churn alto por onboarding difícil (el negocio no sabe usarlo sin ayuda)', 'ALTA', 'ALTO', 'Wizard autoservicio, vídeos de setup, soporte proactivo en los primeros 30 días'],
          ['Sin pricing visible = cero conversión inbound', 'CERTEZA', 'ALTO', 'Publicar pricing hoy. Es un cambio de 2 horas con impacto inmediato.'],
          ['RGPD: datos de clientes finales (consumidores) en la app Explorar', 'MEDIA', 'MEDIO', 'DPA firmado con Firebase/Google, política privacidad, consentimiento explícito en registro'],
          ['Startup bien financiada copia el modelo antes de que Fluix tenga marca', 'MEDIA', 'ALTO', 'Marca y clientes son la única defensa; el código se puede copiar, la red no'],
          ['E-commerce sin lógica de envíos bloquea comercios que quieren vender online', 'ALTA', 'MEDIO', 'Integrar con Correos Express / MRW API o limitar el módulo a comercios sin envío'],
          ['WhatsApp Business API — Meta puede cambiar precios o restringir acceso', 'MEDIA', 'MEDIO', 'Fallback a SMS/email; no hacer el negocio dependiente de WhatsApp exclusivamente'],
        ],
        widths: [180, 38, 50, 182],
      ),

      pw.SizedBox(height: 8),
      subHead('El riesgo más subestimado: el problema del huevo y la gallina'),
      callout(
        'Fresha tardó 4 años y €80M en financiación en crear el efecto de red que tiene hoy. '
        'Treatwell tardó 12 años. El modelo de plataforma de dos lados es el más difícil de arrancar '
        'porque ningún lado tiene valor sin el otro.\n\n'
        'La ventaja de Fluix es que puede vender el lado B2B (software de gestión) con valor '
        'independiente del marketplace — un negocio paga por Fluix aunque no haya consumidores '
        'en la app. Eso da una forma de arrancar que Fresha en sus inicios no tenía. '
        'Es la estrategia correcta: adquirir negocios por el valor B2B, '
        'y después construir el marketplace con sus clientes.',
        isWarn: false,
      ),
    ]),
  ));

  // ═══════════════════════════════════════════════════════════════════════
  // P8 — SECCIÓN 07: CONCLUSIÓN
  // ═══════════════════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 38),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      secHeader('07', 'Conclusión — Qué es Fluix hoy y dónde está la oportunidad'),

      subHead('Qué producto es realmente Fluix (sin eufemismos)'),
      pw.Text(
        'Fluix es la apuesta más ambiciosa del mercado español de software para micropymes: '
        'una plataforma de dos lados que combina lo mejor de Holded (gestión), '
        'Fresha (marketplace de reservas), Treatwell (app consumidor), '
        'y Duolingo (gamificación de retención). Todo en un solo producto, en español, '
        'con Verifactu nativo y multi-vertical.',
        style: body,
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'La implementación técnica es sólida — más de lo esperado para un producto en v1.0.15. '
        'La arquitectura Firebase es escalable con ajustes. '
        'El sistema de gamificación es genuinamente único en el mercado español. '
        'Los Flash Slots son una idea de producto brillante que los competidores no tienen.',
        style: body,
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'El problema no es el producto. El problema es que nadie sabe que existe. '
        'No hay pricing público, no hay landing comparativa, no hay casos de éxito documentados, '
        'no hay estrategia de captación visible. Con el producto actual, Fluix podría '
        'cerrar sus primeros 50-100 clientes mañana si tuviera una mínima presencia comercial.',
        style: pw.TextStyle(fontSize: 9.5, color: warn, fontWeight: pw.FontWeight.bold, lineSpacing: 1.4),
      ),

      subHead('Madurez por área (evaluación objetiva)'),
      tbl(
        ['Área', 'Puntuación', 'Justificación'],
        [
          ['Tecnología y arquitectura', '8 / 10', 'Flutter multi-plataforma, Firebase, Verifactu, seguridad auditada, gamificación compleja'],
          ['Producto B2B (gestión)', '7.5 / 10', '14 módulos funcionales, Verifactu nativo, web CMS — faltan contabilidad y BI'],
          ['Producto B2C (Explorar)', '7 / 10', 'App sofisticada con gamificación única — falta masa crítica de negocios y app en stores'],
          ['UX / Onboarding', '4 / 10', 'Sin wizard autoservicio, sin pricing público, sin trial autoguiado'],
          ['Posicionamiento y marca', '1.5 / 10', 'Sin landing pública, sin casos de éxito, sin presencia inbound'],
          ['Distribución y ventas', '1 / 10', 'Sin canal estructurado visible'],
          ['Modelo de negocio validado', '3 / 10', 'Modelo correcto en papel; sin validación real de ARPU, churn ni LTV'],
          ['Efecto de red (marketplace)', '1 / 10', 'No se puede activar hasta tener negocios y consumidores activos simultáneamente'],
        ],
        widths: [130, 60, 260],
      ),

      subHead('Las 5 acciones que más valor generarían (ordenadas por impacto/esfuerzo)'),
      pw.Container(
        decoration: pw.BoxDecoration(color: bgOk, borderRadius: pw.BorderRadius.circular(5),
            border: pw.Border.all(color: ok, width: 0.6)),
        padding: const pw.EdgeInsets.all(10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          bullet('1. Pricing público + landing comparativa (1-2 días de trabajo):',
            '"Fluix vs pagar 3 softwares separados — desde €X/mes". '
            'Sin esto, cero conversión inbound. Mayor ROI por hora de cualquier mejora posible.',
            ok_: true),
          pw.SizedBox(height: 5),
          bullet('2. Publicar la app consumidor en App Store y Google Play como app independiente:',
            '"Descarga Fluix y reserva en los mejores negocios de [ciudad]". '
            'Activa el lado B2C y da credibilidad al pitch de ventas B2B: "tus clientes ya pueden descargarte".',
            ok_: true),
          pw.SizedBox(height: 5),
          bullet('3. Lanzamiento ciudad piloto (50 negocios, 1 ciudad):',
            'Peluquerías y estéticas de Granada o similar. 50 negocios bien onboardeados '
            'con sus clientes en la app son la prueba de concepto del efecto de red. '
            'Foco total en un mercado local antes de escalar.',
            ok_: true),
          pw.SizedBox(height: 5),
          bullet('4. Onboarding wizard autoservicio (<15 min para primer setup):',
            'TPV funcionando, 5 servicios cargados, primera reserva de prueba — todo sin llamada. '
            'Cada hora adicional de setup multiplica el churn en los primeros 30 días.',
            ok_: true),
          pw.SizedBox(height: 5),
          bullet('5. Integración contable (exportación A3/Holded/ContaPlus):',
            'Elimina la objeción de la gestoría, que es el principal veto en la decisión de compra '
            'de micropymes españolas. Un botón "Exportar a mi gestor" cambia la conversación.',
            ok_: true),
        ]),
      ),

      pw.SizedBox(height: 10),
      pw.Container(
        decoration: pw.BoxDecoration(
          gradient: const pw.LinearGradient(colors: [primary, accent]),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        padding: const pw.EdgeInsets.all(12),
        child: pw.Text(
          '"Fluix tiene el producto. Le falta el mercado. '
          'La oportunidad de ser el Fresha multi-vertical de España existe hoy y el espacio está vacío. '
          'Pero cada mes sin distribución activa es un mes que la competencia puede ganar. '
          'La prioridad del próximo trimestre es que 50 negocios reales usen Fluix a diario, '
          'y que sus clientes la tengan descargada en el móvil. Todo lo demás es secundario."',
          style: pw.TextStyle(fontSize: 10.5, color: PdfColors.white, fontStyle: pw.FontStyle.italic, lineSpacing: 3),
        ),
      ),

      pw.Spacer(),
      pw.Divider(color: divider),
      pw.Text(
        'Informe elaborado: septiembre 2026 · Fluix Tech · Datos de competidores: sitios web públicos, '
        'Capterra, G2, TechCrunch a fecha del análisis. Cifras de Fluix: estimaciones basadas en benchmarks de mercado.',
        style: smallMuted,
      ),
    ]),
  ));

  final output = File(r'C:\Users\Samu\Desktop\Fluix_Analisis_Estrategico_2026.pdf');
  await output.writeAsBytes(await doc.save());
  print('PDF guardado en: ${output.path}');
}

pw.Widget _coverStat(String val, String lbl) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(val, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,
        color: PdfColor(0, 1, 0.78))),
    pw.Text(lbl, style: pw.TextStyle(fontSize: 7.5, color: PdfColor(1, 1, 1, 0.55))),
  ],
);

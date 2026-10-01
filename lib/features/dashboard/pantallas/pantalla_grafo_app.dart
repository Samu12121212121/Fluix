import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:graphify/graphify.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/fluix_app_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PantallaGrafoApp — Mapa interactivo de la arquitectura de Fluix
//
// Muestra todos los módulos, pantallas y relaciones de navegación
// como un grafo de red con fuerza dirigida (Apache ECharts).
//
// Solo disponible en Android, iOS y Web (graphify usa WebView).
// ─────────────────────────────────────────────────────────────────────────────

class PantallaGrafoApp extends StatefulWidget {
  const PantallaGrafoApp({super.key});

  @override
  State<PantallaGrafoApp> createState() => _PantallaGrafoAppState();
}

class _PantallaGrafoAppState extends State<PantallaGrafoApp> {
  late final GraphifyController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = GraphifyController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1E) : const Color(0xFF0F172A),
      appBar: FluixAppBar(
        titulo: 'Arquitectura de Fluix',
        showLeading: true,
        extraActions: [
          Tooltip(
            message: 'Usa gestos de pellizco para hacer zoom y arrastra para mover el grafo',
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.help_outline_rounded, size: 18),
            ),
          ),
        ],
      ),
      body: _esPlataformaCompatible
          ? _buildGrafo()
          : _buildFallbackDesktop(),
    );
  }

  bool get _esPlataformaCompatible =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Widget _buildGrafo() => Column(children: [
    // Leyenda de categorías
    Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _kCategorias.map((c) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: _hx(c['color']!), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(c['name']!, style: const TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w500)),
          ]),
        )).toList()),
      ),
    ),
    // Grafo interactivo
    Expanded(child: GraphifyView(controller: _ctrl, initialOptions: _opciones)),
    // Pie informativo
    Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Icons.touch_app_rounded, size: 13, color: Colors.white38),
        const SizedBox(width: 6),
        const Text('Pellizca para zoom · Arrastra para mover · Toca un nodo para resaltar sus conexiones',
            style: TextStyle(fontSize: 10, color: Colors.white38)),
        const Spacer(),
        Text('${_kNodos.length} pantallas · ${_kLinks.length} conexiones',
            style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ]),
    ),
  ]);

  Future<void> _abrirEnNavegador() async {
    try {
      final html = _generarHtml();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fluix_grafo_arquitectura.html');
      await file.writeAsString(html, encoding: utf8);
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _generarHtml() {
    final opts = jsonEncode(_opciones);
    return '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Fluix — Mapa de Arquitectura</title>
  <script src="https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #0F172A; font-family: system-ui, -apple-system, sans-serif; overflow: hidden; }
    #chart { width: 100vw; height: 100vh; }
    #header {
      position: fixed; top: 0; left: 0; right: 0; z-index: 10;
      background: rgba(15,23,42,0.95); backdrop-filter: blur(8px);
      border-bottom: 1px solid rgba(255,255,255,0.08);
      padding: 10px 20px; display: flex; align-items: center; gap: 12px;
    }
    #header h1 { color: #E2E8F0; font-size: 15px; font-weight: 700; }
    #header span { color: #64748B; font-size: 12px; }
    .badge { background: rgba(124,58,237,0.15); border: 1px solid rgba(124,58,237,0.3);
             border-radius: 20px; padding: 3px 10px; color: #A78BFA; font-size: 11px; }
    #tip { position: fixed; bottom: 14px; left: 50%; transform: translateX(-50%);
           color: #475569; font-size: 11px; pointer-events: none; transition: opacity 0.3s; }
    #panel {
      position: fixed; right: 0; top: 44px; bottom: 0; width: 280px;
      background: rgba(15,23,42,0.97); backdrop-filter: blur(12px);
      border-left: 1px solid rgba(255,255,255,0.08);
      transform: translateX(100%); transition: transform 0.25s ease;
      padding: 20px 16px; overflow-y: auto;
    }
    #panel.open { transform: translateX(0); }
    #panel h2 { color: #E2E8F0; font-size: 14px; font-weight: 700; margin-bottom: 4px; }
    #panel .cat { font-size: 10px; color: #94A3B8; margin-bottom: 14px; }
    #panel .section { font-size: 10px; font-weight: 700; color: #64748B;
                      letter-spacing: 0.6px; text-transform: uppercase; margin: 12px 0 6px; }
    #panel .conn { display: flex; align-items: center; gap: 8px; padding: 5px 0;
                   border-bottom: 1px solid rgba(255,255,255,0.04); font-size: 12px; color: #CBD5E1; }
    #panel .arrow { color: #7C3AED; font-size: 14px; }
    #panel .close { position: absolute; top: 12px; right: 12px; cursor: pointer;
                    color: #64748B; font-size: 18px; line-height: 1; }
  </style>
</head>
<body>
  <div id="header">
    <span style="font-size:20px">🌐</span>
    <h1>Fluix — Mapa de Arquitectura</h1>
    <span class="badge">${_kNodos.length} pantallas</span>
    <span class="badge">${_kLinks.length} conexiones</span>
    <span style="flex:1"></span>
    <span>Scroll · Arrastra · <b style="color:#A78BFA">Clic en nodo</b> para ver conexiones</span>
  </div>
  <div id="chart"></div>
  <div id="panel">
    <span class="close" onclick="closePanel()">✕</span>
    <h2 id="pname">—</h2>
    <div class="cat" id="pcat"></div>
    <div class="section">Sale hacia →</div>
    <div id="pout"></div>
    <div class="section">Recibe de ←</div>
    <div id="pin"></div>
  </div>
  <div id="tip">Generado por Fluix · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}</div>
  <script>
    const chart = echarts.init(document.getElementById('chart'), null, { renderer: 'canvas' });
    const opts = $opts;
    opts.grid = { top: 50 };
    chart.setOption(opts);
    window.addEventListener('resize', () => chart.resize());

    const allLinks = opts.series[0].links;
    const allNodes = opts.series[0].data;
    const catNames = opts.series[0].categories.map(c => c.name);

    function closePanel() {
      document.getElementById('panel').classList.remove('open');
    }

    chart.on('click', function(params) {
      if (params.dataType !== 'node') { closePanel(); return; }
      const name = params.name;
      const node = allNodes.find(n => n.name === name);
      const cat  = node ? (catNames[node.category] || '—') : '—';

      const outLinks = allLinks.filter(l => l.source === name).map(l => l.target);
      const inLinks  = allLinks.filter(l => l.target === name).map(l => l.source);

      document.getElementById('pname').textContent = name;
      document.getElementById('pcat').textContent  = cat + ' · ' + (outLinks.length + inLinks.length) + ' conexiones';

      const mkRow = (label, dir) =>
        '<div class="conn"><span class="arrow">' + dir + '</span>' + label + '</div>';

      document.getElementById('pout').innerHTML =
        outLinks.length ? outLinks.map(n => mkRow(n, '→')).join('') : '<div style="color:#475569;font-size:11px">Sin salidas</div>';
      document.getElementById('pin').innerHTML =
        inLinks.length  ? inLinks.map(n  => mkRow(n, '←')).join('') : '<div style="color:#475569;font-size:11px">Sin entradas</div>';

      document.getElementById('panel').classList.add('open');
    });
  </script>
</body>
</html>''';
  }

  Widget _buildFallbackDesktop() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    // Icono principal
    Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4)],
      ),
      child: const Icon(Icons.account_tree_rounded, size: 38, color: Colors.white),
    ),
    const SizedBox(height: 28),
    const Text('Mapa de arquitectura de Fluix',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
    const SizedBox(height: 8),
    Text('${_kNodos.length} pantallas · ${_kLinks.length} conexiones de navegación',
        style: const TextStyle(fontSize: 13, color: Colors.white54)),
    const SizedBox(height: 32),

    // Botón principal — abre en el navegador
    GestureDetector(
      onTap: _abrirEnNavegador,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.open_in_browser_rounded, size: 18, color: Colors.white),
          SizedBox(width: 10),
          Text('Abrir grafo en el navegador', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    ),
    const SizedBox(height: 12),
    const Text('Genera un HTML interactivo y lo abre en Chrome / Edge',
        style: TextStyle(fontSize: 11, color: Colors.white38)),
    const SizedBox(height: 36),

    // Resumen por categorías
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: [
        const Text('Categorías', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54, letterSpacing: 0.5)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 8, children: _kCategorias.map((c) {
          final n = _kNodos.where((nd) => nd['category'] == _kCategorias.indexOf(c)).length;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _hx(c['color']!).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _hx(c['color']!).withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: _hx(c['color']!), shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text('${c['name']} ($n)',
                  style: TextStyle(fontSize: 11, color: _hx(c['color']!), fontWeight: FontWeight.w600)),
            ]),
          );
        }).toList()),
      ]),
    ),
  ]));

  Color _hx(String hex) {
    try { return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16)); }
    catch (_) { return const Color(0xFF7C3AED); }
  }

  Map<String, dynamic> get _opciones => {
    "backgroundColor": "#0F172A",
    "tooltip": {
      "trigger": "item",
      "formatter": "{b}",
      "backgroundColor": "#1E293B",
      "borderColor": "#334155",
      "textStyle": {"color": "#E2E8F0", "fontSize": 12},
    },
    "legend": {
      "data": _kCategorias.map((c) => c['name']).toList(),
      "textStyle": {"color": "#94A3B8", "fontSize": 10},
      "bottom": 0,
      "icon": "circle",
    },
    "series": [
      {
        "type": "graph",
        "layout": "force",
        "animation": true,
        "animationDuration": 1500,
        "roam": true,
        "label": {
          "show": true,
          "position": "right",
          "fontSize": 9.5,
          "color": "#CBD5E1",
          "fontWeight": "bold",
        },
        "categories": _kCategorias.map((c) => {
          "name": c['name'],
          "itemStyle": {"color": c['color']},
        }).toList(),
        "force": {
          "repulsion": 220,
          "edgeLength": [60, 180],
          "gravity": 0.08,
          "layoutAnimation": true,
        },
        "edgeSymbol": ["none", "arrow"],
        "edgeSymbolSize": [0, 8],
        "lineStyle": {
          "color": "#334155",
          "width": 1.2,
          "curveness": 0.08,
          "opacity": 0.6,
        },
        "emphasis": {
          "focus": "adjacency",
          "label": {"fontSize": 11, "fontWeight": "bold"},
          "lineStyle": {"width": 2.5, "opacity": 1},
        },
        "blur": {"itemStyle": {"opacity": 0.2}, "lineStyle": {"opacity": 0.1}},
        "data": _kNodos,
        "links": _kLinks,
      }
    ],
  };
}

// ─── Categorías ───────────────────────────────────────────────────────────────
const _kCategorias = [
  {'name': 'Core',        'color': '#7C3AED'},  // 0 - Morado
  {'name': 'Facturación', 'color': '#3B82F6'},  // 1 - Azul
  {'name': 'Comercial',   'color': '#10B981'},  // 2 - Verde
  {'name': 'TPV',         'color': '#F59E0B'},  // 3 - Ámbar
  {'name': 'RRHH',        'color': '#6366F1'},  // 4 - Índigo
  {'name': 'Web',         'color': '#06B6D4'},  // 5 - Cian
  {'name': 'Soporte',     'color': '#94A3B8'},  // 6 - Gris
];

// ─── Nodos (pantallas / módulos) ──────────────────────────────────────────────
// symbolSize = importancia visual del nodo
const _kNodos = [
  // ── Core ──────────────────────────────────────────────────────────────────
  {'name': 'Fluix',             'category': 0, 'symbolSize': 70, 'itemStyle': {'color': '#7C3AED'}},
  {'name': 'Dashboard',         'category': 0, 'symbolSize': 55},
  {'name': 'Inicio',            'category': 0, 'symbolSize': 48},
  {'name': 'Autenticación',     'category': 0, 'symbolSize': 36},
  {'name': 'Onboarding',        'category': 0, 'symbolSize': 26},
  {'name': 'Notificaciones',    'category': 0, 'symbolSize': 30},
  {'name': 'Perfil',            'category': 0, 'symbolSize': 30},
  {'name': 'Suscripción',       'category': 0, 'symbolSize': 26},
  {'name': 'Busqueda Global',   'category': 0, 'symbolSize': 24},
  // ── Facturación ───────────────────────────────────────────────────────────
  {'name': 'Facturación',       'category': 1, 'symbolSize': 50},
  {'name': 'Nueva Factura',     'category': 1, 'symbolSize': 28},
  {'name': 'Detalle Factura',   'category': 1, 'symbolSize': 26},
  {'name': 'Contabilidad',      'category': 1, 'symbolSize': 28},
  {'name': 'Modelos Fiscales',  'category': 1, 'symbolSize': 26},
  {'name': 'Verifactu',         'category': 1, 'symbolSize': 26},
  {'name': 'Cert. Digital',     'category': 1, 'symbolSize': 24},
  {'name': 'Plantillas PDF',    'category': 1, 'symbolSize': 36},
  {'name': 'Editor Plantillas', 'category': 1, 'symbolSize': 26},
  {'name': 'Galería PDF',       'category': 1, 'symbolSize': 22},
  // ── Comercial ─────────────────────────────────────────────────────────────
  {'name': 'Clientes',          'category': 2, 'symbolSize': 44},
  {'name': 'Detalle Cliente',   'category': 2, 'symbolSize': 24},
  {'name': 'Pedidos',           'category': 2, 'symbolSize': 44},
  {'name': 'Detalle Pedido',    'category': 2, 'symbolSize': 24},
  {'name': 'Servicios',         'category': 2, 'symbolSize': 32},
  {'name': 'Reservas',          'category': 2, 'symbolSize': 40},
  {'name': 'Detalle Reserva',   'category': 2, 'symbolSize': 22},
  {'name': 'Valoraciones',      'category': 2, 'symbolSize': 28},
  {'name': 'WhatsApp',          'category': 2, 'symbolSize': 24},
  // ── TPV ───────────────────────────────────────────────────────────────────
  {'name': 'TPV',               'category': 3, 'symbolSize': 50},
  {'name': 'TPV Tienda',        'category': 3, 'symbolSize': 34},
  {'name': 'TPV Peluquería',    'category': 3, 'symbolSize': 34},
  {'name': 'TPV Selector',      'category': 3, 'symbolSize': 26},
  {'name': 'Caja / Cierre',     'category': 3, 'symbolSize': 22},
  // ── RRHH ──────────────────────────────────────────────────────────────────
  {'name': 'Empleados',         'category': 4, 'symbolSize': 44},
  {'name': 'Formulario Emp.',   'category': 4, 'symbolSize': 24},
  {'name': 'Fichajes',          'category': 4, 'symbolSize': 30},
  {'name': 'Vacaciones',        'category': 4, 'symbolSize': 28},
  {'name': 'Nóminas',           'category': 4, 'symbolSize': 30},
  {'name': 'Finiquitos',        'category': 4, 'symbolSize': 22},
  {'name': 'Embargos',          'category': 4, 'symbolSize': 20},
  {'name': 'Tareas',            'category': 4, 'symbolSize': 38},
  {'name': 'Detalle Tarea',     'category': 4, 'symbolSize': 22},
  // ── Web ───────────────────────────────────────────────────────────────────
  {'name': 'Web',               'category': 5, 'symbolSize': 40},
  {'name': 'Blog',              'category': 5, 'symbolSize': 24},
  {'name': 'Eventos',           'category': 5, 'symbolSize': 24},
  {'name': 'Mensajes',          'category': 5, 'symbolSize': 24},
  {'name': 'Config Web',        'category': 5, 'symbolSize': 24},
  {'name': 'App Pública',       'category': 5, 'symbolSize': 26},
  // ── Soporte / Dev ─────────────────────────────────────────────────────────
  {'name': 'Dashboard Analytics','category': 6, 'symbolSize': 36},
  {'name': 'Panel Propietario', 'category': 6, 'symbolSize': 30},
  {'name': 'Gestionar Cuentas', 'category': 6, 'symbolSize': 22},
  {'name': 'Bandeja Notif.',    'category': 6, 'symbolSize': 28},
  {'name': 'Explorar Negocios', 'category': 6, 'symbolSize': 32},
  {'name': 'App Demo',          'category': 6, 'symbolSize': 22},
  {'name': 'Grafo App',         'category': 6, 'symbolSize': 24, 'itemStyle': {'color': '#7C3AED'}},
];

// ─── Conexiones de navegación ─────────────────────────────────────────────────
const _kLinks = [
  // Core → Auth → Dashboard
  {'source': 'Fluix',             'target': 'Autenticación'},
  {'source': 'Fluix',             'target': 'Onboarding'},
  {'source': 'Autenticación',     'target': 'Dashboard'},
  {'source': 'Dashboard',         'target': 'Inicio'},
  {'source': 'Dashboard',         'target': 'Notificaciones'},
  // Módulos que generan notificaciones → hub
  {'source': 'Reservas',          'target': 'Notificaciones'},
  {'source': 'Tareas',            'target': 'Notificaciones'},
  {'source': 'Pedidos',           'target': 'Notificaciones'},
  {'source': 'Empleados',         'target': 'Notificaciones'},
  {'source': 'Facturación',       'target': 'Notificaciones'},
  {'source': 'Dashboard',         'target': 'Busqueda Global'},
  {'source': 'Dashboard',         'target': 'Suscripción'},
  {'source': 'Suscripción',       'target': 'Perfil'},
  // Inicio → módulos
  {'source': 'Inicio',            'target': 'Facturación'},
  {'source': 'Inicio',            'target': 'Clientes'},
  {'source': 'Inicio',            'target': 'Pedidos'},
  {'source': 'Inicio',            'target': 'TPV'},
  {'source': 'Inicio',            'target': 'Empleados'},
  {'source': 'Inicio',            'target': 'Web'},
  {'source': 'Inicio',            'target': 'Reservas'},
  {'source': 'Inicio',            'target': 'Tareas'},
  {'source': 'Inicio',            'target': 'Servicios'},
  {'source': 'Inicio',            'target': 'Valoraciones'},
  {'source': 'Inicio',            'target': 'Dashboard Analytics'},
  {'source': 'Inicio',            'target': 'Panel Propietario'},
  // Facturación
  {'source': 'Facturación',       'target': 'Nueva Factura'},
  {'source': 'Facturación',       'target': 'Detalle Factura'},
  {'source': 'Facturación',       'target': 'Contabilidad'},
  {'source': 'Facturación',       'target': 'Modelos Fiscales'},
  {'source': 'Facturación',       'target': 'Verifactu'},
  {'source': 'Facturación',       'target': 'Plantillas PDF'},
  {'source': 'Verifactu',         'target': 'Cert. Digital'},
  {'source': 'Plantillas PDF',    'target': 'Editor Plantillas'},
  {'source': 'Plantillas PDF',    'target': 'Galería PDF'},
  // Facturación ↔ otros módulos (cross-module)
  {'source': 'Nueva Factura',     'target': 'Clientes'},       // seleccionar cliente al facturar
  {'source': 'Pedidos',           'target': 'Facturación'},    // pedido → generar factura
  {'source': 'TPV Tienda',        'target': 'Facturación'},    // tickets/facturas desde TPV
  {'source': 'TPV Peluquería',    'target': 'Facturación'},
  {'source': 'Plantillas PDF',    'target': 'Nueva Factura'},  // plantilla aplicada al generar
  // Comercial
  {'source': 'Clientes',          'target': 'Detalle Cliente'},
  {'source': 'Clientes',          'target': 'WhatsApp'},
  {'source': 'Pedidos',           'target': 'Detalle Pedido'},
  {'source': 'Reservas',          'target': 'Detalle Reserva'},
  {'source': 'Reservas',          'target': 'Servicios'},
  // Clientes ↔ otros módulos (hub central de datos)
  {'source': 'Clientes',          'target': 'Facturación'},    // ver facturas del cliente
  {'source': 'Clientes',          'target': 'Pedidos'},        // ver pedidos del cliente
  {'source': 'Clientes',          'target': 'Reservas'},       // ver reservas del cliente
  {'source': 'Valoraciones',      'target': 'Clientes'},       // valoraciones de clientes
  {'source': 'TPV Tienda',        'target': 'Clientes'},       // fidelización / tarjeta cliente
  {'source': 'WhatsApp',          'target': 'Pedidos'},        // notificaciones de pedidos
  {'source': 'Servicios',         'target': 'Pedidos'},        // servicios se pueden pedir
  // TPV
  {'source': 'TPV',               'target': 'TPV Selector'},
  {'source': 'TPV Selector',      'target': 'TPV Tienda'},
  {'source': 'TPV Selector',      'target': 'TPV Peluquería'},
  {'source': 'TPV Tienda',        'target': 'Caja / Cierre'},
  {'source': 'TPV Peluquería',    'target': 'Caja / Cierre'},
  // RRHH
  {'source': 'Empleados',         'target': 'Formulario Emp.'},
  {'source': 'Empleados',         'target': 'Fichajes'},
  {'source': 'Empleados',         'target': 'Vacaciones'},
  {'source': 'Empleados',         'target': 'Nóminas'},
  {'source': 'Nóminas',           'target': 'Finiquitos'},
  {'source': 'Nóminas',           'target': 'Embargos'},
  {'source': 'Fichajes',          'target': 'Nóminas'},        // horas fichadas → cálculo nómina
  {'source': 'Tareas',            'target': 'Detalle Tarea'},
  {'source': 'Tareas',            'target': 'Empleados'},      // tareas asignadas a empleados
  // Búsqueda global → módulos principales
  {'source': 'Busqueda Global',   'target': 'Clientes'},
  {'source': 'Busqueda Global',   'target': 'Facturación'},
  {'source': 'Busqueda Global',   'target': 'Pedidos'},
  // Notificaciones → módulos destino
  {'source': 'Notificaciones',    'target': 'Reservas'},
  {'source': 'Notificaciones',    'target': 'Tareas'},
  {'source': 'Notificaciones',    'target': 'Pedidos'},
  // Web
  {'source': 'Web',               'target': 'Blog'},
  {'source': 'Web',               'target': 'Eventos'},
  {'source': 'Web',               'target': 'Mensajes'},
  {'source': 'Web',               'target': 'Config Web'},
  {'source': 'Web',               'target': 'App Pública'},
  {'source': 'App Pública',       'target': 'Reservas'},       // reservas desde la web pública
  {'source': 'App Pública',       'target': 'Clientes'},       // clientes llegan por la web
  // Soporte / Dev
  {'source': 'Dashboard Analytics','target': 'Facturación'},
  {'source': 'Dashboard Analytics','target': 'Clientes'},
  {'source': 'Dashboard Analytics','target': 'Pedidos'},
  {'source': 'Dashboard Analytics','target': 'Empleados'},     // analítica de RRHH
  {'source': 'Perfil',            'target': 'Gestionar Cuentas'},
  {'source': 'Notificaciones',    'target': 'Bandeja Notif.'},
  {'source': 'Panel Propietario', 'target': 'Grafo App'},
  {'source': 'Panel Propietario', 'target': 'Explorar Negocios'},
  {'source': 'Panel Propietario', 'target': 'App Demo'},
  // Explorar Negocios — accesible también desde inicio y perfil
  {'source': 'Inicio',            'target': 'Explorar Negocios'},
  {'source': 'Perfil',            'target': 'Explorar Negocios'},
  // Bandeja de notificaciones — punto de entrada a cada módulo
  {'source': 'Bandeja Notif.',    'target': 'Facturación'},
  {'source': 'Bandeja Notif.',    'target': 'Reservas'},
  {'source': 'Bandeja Notif.',    'target': 'Tareas'},
  {'source': 'Bandeja Notif.',    'target': 'Pedidos'},
  {'source': 'Bandeja Notif.',    'target': 'Empleados'},
];

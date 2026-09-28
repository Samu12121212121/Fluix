import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB ARCHIVO HISTÓRICO NAZARÍ
// Busca en master.json (Storage) e importa contenido bajo demanda a Firestore.
// Usa HTTP directo (cloud_functions no soporta Windows desktop).
// ═════════════════════════════════════════════════════════════════════════════

String _htmlDecode(String s) => s
    .replaceAll('&amp;',  '&')
    .replaceAll('&lt;',   '<')
    .replaceAll('&gt;',   '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;',  "'")
    .replaceAll('&#8216;', '‘')
    .replaceAll('&#8217;', '’')
    .replaceAll('&#8220;', '“')
    .replaceAll('&#8221;', '”')
    .replaceAll('&#8211;', '–')
    .replaceAll('&#8212;', '—')
    .replaceAll('&#8230;', '…')
    .replaceAll('&nbsp;',  ' ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .trim();

const _kRegion    = 'europe-west1';
const _kProjectId = 'planeaapp-4bea4';

Future<Map<String, dynamic>> _callFn(
    String name, Map<String, dynamic> params) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('No autenticado. Cierra sesión y vuelve a entrar.');

  final token = await user.getIdToken();
  final url = Uri.parse(
      'https://$_kRegion-$_kProjectId.cloudfunctions.net/$name');

  http.Response res;
  try {
    res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'data': params}),
    ).timeout(const Duration(seconds: 45));
  } catch (e) {
    throw Exception('No se pudo conectar con Firebase Functions.\n'
        'Comprueba tu conexión a internet.\nDetalle: $e');
  }

  Map<String, dynamic> body;
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw Exception('Respuesta inesperada del servidor (HTTP ${res.statusCode}):\n${res.body.substring(0, res.body.length.clamp(0, 300))}');
  }

  if (res.statusCode != 200) {
    final errMap = body['error'] as Map?;
    final msg = errMap?['message'] as String?
        ?? errMap?['status'] as String?
        ?? 'HTTP ${res.statusCode}';
    // Detectar función no desplegada
    if (res.statusCode == 404) {
      throw Exception('La función "$name" no está desplegada en Firebase.\n'
          'Ejecuta: firebase deploy --only functions:$name');
    }
    throw Exception(msg);
  }

  final result = body['result'];
  if (result == null) {
    throw Exception('La función respondió OK pero sin datos.\nRespuesta: ${res.body.substring(0, 200)}');
  }
  return Map<String, dynamic>.from(result as Map);
}

// ─────────────────────────────────────────────────────────────────────────────

class TabArchivoHistorico extends StatefulWidget {
  final String empresaId;
  final Color color;

  const TabArchivoHistorico({
    super.key,
    required this.empresaId,
    required this.color,
  });

  @override
  State<TabArchivoHistorico> createState() => _TabArchivoHistoricoState();
}

class _TabArchivoHistoricoState extends State<TabArchivoHistorico>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    ('noticias',    'Noticias',     Icons.newspaper_rounded,    ''),
    ('entrevistas', 'Entrevistas',  Icons.record_voice_over_rounded, ''),
    ('autores',     'Autores',      Icons.person_rounded,       ''),
    ('libros',      'Libros',       Icons.menu_book_rounded,
        'El catálogo de libros no está disponible vía API.\nAñade los libros manualmente desde el módulo Catálogo.'),
  ];

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Header ──────────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.archive_rounded, color: widget.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
              Text('Archivo Histórico',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              Text('Contenido migrado de WordPress · importación bajo demanda',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ])),
          ]),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: widget.color,
            labelColor: widget.color,
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: _tabs.map((t) => Tab(
              child: Row(children: [
                Icon(t.$3, size: 15),
                const SizedBox(width: 5),
                Text(t.$2),
              ]),
            )).toList(),
          ),
        ]),
      ),
      // ── Contenido por pestaña ────────────────────────────────────────────
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: _tabs.map<Widget>((t) => t.$4.isNotEmpty
              ? _TabSinDatos(mensaje: t.$4, icono: t.$3, color: widget.color)
              : _BuscadorTab(tipo: t.$1, color: widget.color)).toList(),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BuscadorTab extends StatefulWidget {
  final String tipo;
  final Color color;

  const _BuscadorTab({required this.tipo, required this.color});

  @override
  State<_BuscadorTab> createState() => _BuscadorTabState();
}

class _BuscadorTabState extends State<_BuscadorTab>
    with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hayMas  = false;
  int  _pagina  = 1;
  int  _total   = 0;
  String _error = '';
  bool _buscado = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _buscar({bool reset = true}) async {
    if (reset) { _pagina = 1; _items = []; }
    setState(() { _loading = true; _error = ''; _buscado = true; });
    try {
      final data = await _callFn('buscarArchivoNazari', {
        'tipo':      widget.tipo,
        'query':     _ctrl.text.trim(),
        'pagina':    _pagina,
        'por_pagina': 30,
      });
      final nuevos = (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _items  = reset ? nuevos : [..._items, ...nuevos];
        _total  = data['total']   as int?  ?? 0;
        _hayMas = data['hay_mas'] as bool? ?? false;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = _parseError(e); _loading = false; });
    }
  }

  String _parseError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('no está desplegada') || msg.contains('404')) {
      return msg;
    }
    if (msg.contains('master') || msg.contains('not-found') ||
        msg.contains('maestro')) {
      return 'El archivo maestro no está disponible.\nEjecuta primero: node scripts/nazari/extractor.js https://editorialnazari.com';
    }
    return msg;
  }

  Future<void> _importar(Map<String, dynamic> item) async {
    final wpId = item['wp_id'] as int?;
    if (wpId == null) return;
    setState(() => item['_importando'] = true);
    try {
      final result = await _callFn('importarContenidoNazari', {
        'tipo': widget.tipo,
        'wp_id': wpId,
      });
      final yaExistia = result['ya_existia'] as bool? ?? false;
      setState(() {
        item['importado_en_fluix'] = true;
        item['_importando'] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(yaExistia
              ? '${item['titulo'] ?? 'Ítem'} ya estaba en Fluix'
              : '✅ ${item['titulo'] ?? 'Ítem'} importado a Noticias/Entrevistas'),
          backgroundColor: yaExistia ? Colors.orange.shade700 : Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      setState(() => item['_importando'] = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error al importar'),
            content: SingleChildScrollView(
              child: Text(msg,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      // ── Barra de búsqueda ────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Buscar por título o slug…',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18,
                    color: Color(0xFF94A3B8)),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () { _ctrl.clear(); _buscar(); },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => _buscar(),
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _loading ? null : _buscar,
            style: FilledButton.styleFrom(
              backgroundColor: widget.color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: _loading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Buscar'),
          ),
        ]),
      ),
      if (_buscado && _items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(children: [
            Text('$_total encontrados',
                style: const TextStyle(
                    fontSize: 11.5, color: Color(0xFF94A3B8))),
          ]),
        ),
      Expanded(child: _buildLista()),
    ]);
  }

  Widget _buildLista() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 48,
                color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(_error, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _buscar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ]),
        ),
      );
    }
    if (_buscado && _items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 48,
            color: widget.color.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        const Text('Sin resultados',
            style: TextStyle(color: Color(0xFF64748B))),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: _items.length + (_hayMas ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () { _pagina++; _buscar(reset: false); },
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Cargar más'),
              ),
            ),
          );
        }
        return _ItemCard(
          item:       _items[i],
          color:      widget.color,
          onImportar: () => _importar(_items[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color color;
  final VoidCallback onImportar;

  const _ItemCard({
    required this.item,
    required this.color,
    required this.onImportar,
  });

  @override
  Widget build(BuildContext context) {
    final titulo      = _htmlDecode(item['titulo'] as String? ?? item['nombre'] as String? ?? '');
    final fecha       = (item['fecha'] as String? ?? '').split('T').first;
    final autor       = item['autor']  as String? ?? '';
    final yaImportado = item['importado_en_fluix'] as bool? ?? false;
    final importando  = item['_importando']        as bool? ?? false;
    final imgUrl      = item['imagen_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: yaImportado ? Colors.green.shade200 : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Miniatura ────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (imgUrl != null && imgUrl.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: imgUrl,
                    width: 52, height: 52, fit: BoxFit.cover,
                    placeholder: (_, __) => _placeholder(),
                    errorWidget: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 10),
          // ── Texto ────────────────────────────────────────────────────────
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(titulo,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              if (fecha.isNotEmpty) ...[
                const Icon(Icons.calendar_today_rounded, size: 10,
                    color: Color(0xFF94A3B8)),
                const SizedBox(width: 3),
                Text(fecha, style: const TextStyle(
                    fontSize: 10.5, color: Color(0xFF94A3B8))),
                const SizedBox(width: 8),
              ],
              if (autor.isNotEmpty) ...[
                const Icon(Icons.person_outline_rounded, size: 10,
                    color: Color(0xFF94A3B8)),
                const SizedBox(width: 3),
                Flexible(child: Text(autor, style: const TextStyle(
                    fontSize: 10.5, color: Color(0xFF94A3B8)),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ]),
            const SizedBox(height: 6),
            if (yaImportado)
              Row(children: [
                Icon(Icons.check_circle_rounded, size: 13,
                    color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text('Ya en Fluix', style: TextStyle(
                    fontSize: 11, color: Colors.green.shade600,
                    fontWeight: FontWeight.w600)),
              ])
            else
              SizedBox(
                height: 28,
                child: FilledButton.icon(
                  onPressed: importando ? null : onImportar,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 0),
                    textStyle: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  icon: importando
                      ? const SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.8, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 14),
                  label: Text(importando ? 'Importando…' : 'Importar a Fluix'),
                ),
              ),
          ])),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 52, height: 52,
    color: color.withValues(alpha: 0.08),
    child: Icon(Icons.image_rounded, size: 22, color: color.withValues(alpha: 0.35)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _TabSinDatos extends StatelessWidget {
  final String  mensaje;
  final IconData icono;
  final Color   color;

  const _TabSinDatos({
    required this.mensaje,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icono, size: 32, color: color.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ]),
      ),
    );
  }
}

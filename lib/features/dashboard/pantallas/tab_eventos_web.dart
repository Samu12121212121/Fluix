import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/evento_web.dart';
import '../../../domain/modelos/seccion_web.dart';
import '../../../core/widgets/fluix_app_bar.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB EVENTOS — listado y gestión de eventos de la web
// ═════════════════════════════════════════════════════════════════════════════

class TabEventosWeb extends StatelessWidget {
  final String empresaId;
  final ContenidoWebService svc;
  // Callback para abrir el editor Word desde un evento (data-fluix-agenda-word)
  final void Function(dynamic entrada, List<dynamic> cats)? onAbrirEditorWord;

  const TabEventosWeb({
    super.key,
    required this.empresaId,
    required this.svc,
    this.onAbrirEditorWord,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return StreamBuilder<List<EventoWeb>>(
      stream: svc.obtenerEventos(empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text('Error: ${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              ]),
            ),
          );
        }
        final eventos = snap.data ?? [];
        final proximos = eventos.where((e) => e.esFuturo && e.activo).length;

        return Stack(
          children: [
            Column(
              children: [
                // KPIs
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    _kpi('Próximos', '$proximos', color),
                    _divV(),
                    _kpi('Pasados', '${eventos.where((e) => !e.esFuturo).length}',
                        Colors.grey[500]!),
                    _divV(),
                    _kpi('Total', '${eventos.length}', const Color(0xFF455A64)),
                    if (empresaId == _kNazariId) ...[
                      _divV(),
                      _BtnImportarNazari(empresaId: empresaId, svc: svc, color: color, compact: true),
                    ],
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: eventos.isEmpty
                      ? _buildVacio(context, color)
                      : _buildLista(context, eventos, color),
                ),
              ],
            ),
            Positioned(
              right: 16, bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_nuevo_evento',
                onPressed: () => _abrirEditor(context, null, color),
                backgroundColor: color,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.event_note),
                label: const Text('Nuevo evento'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kpi(String label, String valor, Color c) => Expanded(
        child: Column(children: [
          Text(valor, style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: c)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      );

  Widget _divV() => Container(width: 1, height: 32, color: Colors.grey[200]);

  static const _kNazariId = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

  // Crea un borrador de EntradaBlog pre-relleno con los datos del evento.
  static EntradaBlog _entradaDesdeEvento(EventoWeb e) {
    const meses = ['enero','febrero','marzo','abril','mayo','junio',
                   'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    final fechaStr = '${e.fecha.day} de ${meses[e.fecha.month - 1]} de ${e.fecha.year}';
    final lugarStr = [e.lugar, e.ciudad ?? ''].where((s) => s.isNotEmpty).join(', ');
    final buf = StringBuffer('# ${e.titulo}\n\n');
    if (e.descripcion.isNotEmpty) buf.write('${e.descripcion}\n\n');
    buf.write('**Fecha:** $fechaStr\n\n');
    if (lugarStr.isNotEmpty) buf.write('**Lugar:** $lugarStr\n\n');
    if ((e.hora ?? '').isNotEmpty) buf.write('**Hora:** ${e.hora}\n\n');
    return EntradaBlog(
      id: '',
      titulo: e.titulo,
      resumen: e.subtitulo ?? '',
      contenido: buf.toString(),
      autor: e.autorNombre ?? '',
      autorId: e.autorId,
      libroId: e.libroId,
      tipo: 'noticia',
      estado: EstadoBlog.borrador,
      fechaPublicacion: e.fecha,
      etiquetas: [e.tipo.label.toLowerCase()],
      imagenUrl: e.imagenUrl,
    );
  }

  Widget _buildVacio(BuildContext context, Color color) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.event_note_outlined, size: 40, color: color.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 20),
              const Text('Agenda sin eventos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              const Text(
                'Los eventos aparecen aquí y en tu web en tiempo real.\n'
                'Presentaciones, ferias, talleres, lecturas…',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => _abrirEditor(context, null, color),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Crear evento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              if (empresaId == _kNazariId)
                _BtnImportarNazari(empresaId: empresaId, svc: svc, color: color,)
              else
                TextButton.icon(
                  onPressed: () async {
                    await svc.crearEventosEjemplo(empresaId);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ 3 eventos de ejemplo creados'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  icon: Icon(Icons.auto_awesome_rounded, size: 14, color: color),
                  label: Text('Cargar eventos de ejemplo',
                      style: TextStyle(color: color, fontSize: 12.5)),
                ),
            ],
          ),
        ),
      );

  Widget _buildLista(
      BuildContext context, List<EventoWeb> eventos, Color color) {
    // Separar y ordenar
    final proximos = (eventos.where((e) => e.esFuturo && !e.eliminado).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha)));
    final pasados  = (eventos.where((e) => !e.esFuturo && !e.eliminado).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha)));

    // Agrupar próximos por mes
    final Map<String, List<EventoWeb>> porMes = {};
    for (final e in proximos) {
      final k = _clavesMes(e.fecha);
      porMes.putIfAbsent(k, () => []).add(e);
    }

    return _TimelineEventos(
      porMes: porMes,
      pasados: pasados,
      color: color,
      onTap: (e) => _abrirEditor(context, e, color),
      onToggle: (e, v) => svc.toggleActivoEvento(empresaId, e.id, v),
      onEliminar: (e) => _confirmarEliminar(context, e),
      onDuplicar: (e) async {
        await svc.duplicarEvento(empresaId, e);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Evento duplicado — aparece oculto, actívalo cuando quieras'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 3),
        ));
      },
      onEscribir: onAbrirEditorWord != null
          ? (e) => onAbrirEditorWord!(_entradaDesdeEvento(e), [])
          : null,
      totalProximos: proximos.length,
      ciudades: proximos.map((e) => e.ciudad ?? '').where((c) => c.isNotEmpty).toSet(),
    );
  }

  static String _clavesMes(DateTime dt) {
    const meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio',
                   'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return '${meses[dt.month - 1]} ${dt.year}';
  }

  // _seccionHeader eliminado — ya no se usa

  void _abrirEditor(BuildContext context, EventoWeb? evento, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.98,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(
              color: Colors.white,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(evento == null ? Icons.event_note_outlined : Icons.edit_outlined, color: color, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      evento == null ? 'Nuevo evento' : 'Editar evento',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    )),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                  ]),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ]),
            ),
            Expanded(child: _PantallaEditorEvento(
              empresaId: empresaId,
              svc: svc,
              evento: evento,
              color: color,
              scrollController: scrollCtrl,
              onGuardado: () => Navigator.pop(ctx),
            )),
          ]),
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, EventoWeb evento) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "${evento.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await svc.eliminarEvento(empresaId, evento.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Timeline de eventos ────────────────────────────────────────────────────────

class _TimelineEventos extends StatefulWidget {
  final Map<String, List<EventoWeb>> porMes;
  final List<EventoWeb> pasados;
  final Color color;
  final void Function(EventoWeb) onTap;
  final void Function(EventoWeb, bool) onToggle;
  final void Function(EventoWeb) onEliminar;
  final void Function(EventoWeb)? onEscribir;
  final void Function(EventoWeb)? onDuplicar;
  final int totalProximos;
  final Set<String> ciudades;

  const _TimelineEventos({
    required this.porMes, required this.pasados, required this.color,
    required this.onTap, required this.onToggle, required this.onEliminar,
    this.onEscribir, this.onDuplicar,
    required this.totalProximos, required this.ciudades,
  });

  @override
  State<_TimelineEventos> createState() => _TimelineEventosState();
}

class _TimelineEventosState extends State<_TimelineEventos> {
  bool _pasadosExpanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;

    // Banner resumen próximos
    final diasAlProximo = widget.porMes.values.expand((l) => l)
        .where((e) => e.fecha.isAfter(DateTime.now()))
        .fold<int?>(null, (acc, e) {
          final d = e.fecha.difference(DateTime.now()).inDays;
          return acc == null || d < acc ? d : acc;
        });

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        // ── Banner resumen ───────────────────────────────────────────────────
        if (widget.totalProximos > 0)
          _BannerResumen(
            totalProximos: widget.totalProximos,
            diasAlProximo: diasAlProximo ?? 0,
            ciudades: widget.ciudades,
            color: c,
          ),

        // ── Timeline por mes ────────────────────────────────────────────────
        if (widget.porMes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No hay eventos próximos',
                style: TextStyle(color: Colors.grey[400], fontSize: 13))),
          ),
        ...widget.porMes.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MesHeader(label: entry.key, count: entry.value.length, color: c),
            ...entry.value.map((e) => _FilaEvento(
              evento: e, color: c,
              onTap: () => widget.onTap(e),
              onToggle: (v) => widget.onToggle(e, v),
              onEliminar: () => widget.onEliminar(e),
              onEscribir: widget.onEscribir != null ? () => widget.onEscribir!(e) : null,
              onDuplicar: widget.onDuplicar != null ? () => widget.onDuplicar!(e) : null,
            )),
          ],
        )),

        // ── Pasados (colapsable) ─────────────────────────────────────────────
        if (widget.pasados.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _pasadosExpanded = !_pasadosExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                const Icon(Icons.history_rounded, size: 15, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Text('${widget.pasados.length} eventos pasados',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(_pasadosExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                    size: 18, color: const Color(0xFF94A3B8)),
              ]),
            ),
          ),
          if (_pasadosExpanded)
            ...widget.pasados.take(20).map((e) => _FilaEvento(
              evento: e, color: const Color(0xFF94A3B8), pasado: true,
              onTap: () => widget.onTap(e),
              onToggle: (v) => widget.onToggle(e, v),
              onEliminar: () => widget.onEliminar(e),
              onEscribir: widget.onEscribir != null ? () => widget.onEscribir!(e) : null,
              onDuplicar: widget.onDuplicar != null ? () => widget.onDuplicar!(e) : null,
            )),
        ],
      ],
    );
  }
}

// ── Banner resumen ─────────────────────────────────────────────────────────────

class _BannerResumen extends StatelessWidget {
  final int totalProximos;
  final int diasAlProximo;
  final Set<String> ciudades;
  final Color color;

  const _BannerResumen({
    required this.totalProximos, required this.diasAlProximo,
    required this.ciudades, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final topCiudades = ciudades.toList().take(4).join(' · ');
    final proximoLabel = diasAlProximo == 0 ? 'Hoy'
        : diasAlProximo == 1 ? 'Mañana'
        : 'En $diasAlProximo días';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        // Próximo evento
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Próximo evento', style: TextStyle(
              color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
          Text(proximoLabel, style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
        ]),
        const SizedBox(width: 16),
        Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.25)),
        const SizedBox(width: 16),
        // Total + ciudades
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$totalProximos eventos por venir',
              style: const TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (topCiudades.isNotEmpty)
            Text(topCiudades, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ── Cabecera de mes ────────────────────────────────────────────────────────────

class _MesHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MesHeader({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                  color: color, letterSpacing: .5)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withValues(alpha: 0.2), height: 1)),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.6),
            fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Fila compacta de evento ────────────────────────────────────────────────────

class _FilaEvento extends StatelessWidget {
  final EventoWeb evento;
  final Color color;
  final bool pasado;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEliminar;
  final VoidCallback? onEscribir;
  final VoidCallback? onDuplicar;

  const _FilaEvento({
    required this.evento, required this.color, this.pasado = false,
    required this.onTap, required this.onToggle, required this.onEliminar,
    this.onEscribir, this.onDuplicar,
  });

  static const _kNazariBase = 'https://seashell-boar-580681.hostingersite.com';

  static const _meses = ['Ene','Feb','Mar','Abr','May','Jun',
                         'Jul','Ago','Sep','Oct','Nov','Dic'];

  // Resuelve rutas relativas a la URL completa del CDN de Nazarí
  static String? _resolverImagen(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '$_kNazariBase/${url.startsWith('/') ? url.substring(1) : url}';
  }
  // Color por tipo
  static Color _colorTipo(TipoEvento t) {
    switch (t) {
      case TipoEvento.presentacion: return const Color(0xFF6B1E2A);
      case TipoEvento.feria:        return const Color(0xFF1E4D6B);
      case TipoEvento.taller:       return const Color(0xFF065F46);
      case TipoEvento.lectura:      return const Color(0xFF5B21B6);
      default:                      return const Color(0xFF374151);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cTipo = pasado ? const Color(0xFF94A3B8) : _colorTipo(evento.tipo);
    final cText = pasado ? const Color(0xFF94A3B8) : const Color(0xFF0F172A);
    final cSub  = pasado ? const Color(0xFFB0BEC5) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pasado ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: pasado ? [] : [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // IntrinsicHeight para que la tira de color se estire al alto del contenido
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tira de color izquierda según tipo
                Container(width: 4, color: cTipo),
                // Contenido principal
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Bloque de fecha
                        SizedBox(
                          width: 38,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${evento.fecha.day}',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: cTipo,
                                      height: 1.0)),
                              Text(_meses[evento.fecha.month - 1],
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cSub,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: .3)),
                            ],
                          ),
                        ),
                        // Thumbnail portada (si hay imagen)
                        Builder(builder: (_) {
                          final img = _resolverImagen(evento.imagenUrl);
                          if (img == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Image.network(
                                img, width: 40, height: 56, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          );
                        }),
                        // Separador vertical
                        Container(
                          width: 1,
                          height: 36,
                          color: const Color(0xFFE8ECF0),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        // Info: tipo, ciudad, título, hora/autor
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: cTipo.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(evento.tipo.label,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cTipo,
                                          fontWeight: FontWeight.w700)),
                                ),
                                if ((evento.ciudad ?? '').isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Icon(Icons.place_rounded,
                                      size: 11, color: cSub),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(evento.ciudad!,
                                        style: TextStyle(
                                            fontSize: 11, color: cSub),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 2),
                              Text(
                                evento.titulo,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cText,
                                    height: 1.2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((evento.hora ?? '').isNotEmpty ||
                                  (evento.autorNombre ?? '').isNotEmpty)
                                Row(children: [
                                  if ((evento.hora ?? '').isNotEmpty) ...[
                                    Icon(Icons.schedule_rounded,
                                        size: 11, color: cSub),
                                    const SizedBox(width: 2),
                                    Text(evento.hora!,
                                        style: TextStyle(
                                            fontSize: 11, color: cSub)),
                                  ],
                                  if ((evento.hora ?? '').isNotEmpty &&
                                      (evento.autorNombre ?? '').isNotEmpty)
                                    Text('  ·  ',
                                        style: TextStyle(
                                            color: cSub, fontSize: 11)),
                                  if ((evento.autorNombre ?? '').isNotEmpty)
                                    Flexible(
                                      child: Text(evento.autorNombre!,
                                          style: TextStyle(
                                              fontSize: 11, color: cSub),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                ]),
                            ],
                          ),
                        ),
                        // Menú ⋮
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              size: 16, color: cSub),
                          padding: EdgeInsets.zero,
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'editar',
                              child: Row(children: [
                                Icon(Icons.edit_rounded,
                                    size: 14, color: color),
                                const SizedBox(width: 8),
                                const Text('Editar evento',
                                    style: TextStyle(fontSize: 13)),
                              ]),
                            ),
                            if (!pasado)
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(children: [
                                  Icon(
                                    evento.activo
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 14, color: Colors.grey[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    evento.activo ? 'Ocultar en web' : 'Mostrar en web',
                                    style: const TextStyle(fontSize: 13)),
                                ]),
                              ),
                            if (onEscribir != null)
                              const PopupMenuItem(
                                value: 'escribir',
                                child: Row(children: [
                                  Icon(Icons.article_rounded,
                                      size: 14, color: Color(0xFF7C3AED)),
                                  SizedBox(width: 8),
                                  Text('Escribir artículo',
                                      style: TextStyle(fontSize: 13,
                                          color: Color(0xFF7C3AED))),
                                ]),
                              ),
                            const PopupMenuItem(
                              value: 'duplicar',
                              child: Row(children: [
                                Icon(Icons.copy_outlined,
                                    size: 14, color: Color(0xFF7C3AED)),
                                SizedBox(width: 8),
                                Text('Duplicar',
                                    style: TextStyle(fontSize: 13,
                                        color: Color(0xFF7C3AED))),
                              ]),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'eliminar',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    size: 14, color: Color(0xFFEF4444)),
                                SizedBox(width: 8),
                                Text('Eliminar',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFEF4444))),
                              ]),
                            ),
                          ],
                          onSelected: (a) {
                            if (a == 'editar')    onTap();
                            if (a == 'toggle')    onToggle(!evento.activo);
                            if (a == 'escribir')  onEscribir?.call();
                            if (a == 'duplicar')  onDuplicar?.call();
                            if (a == 'eliminar')  onEliminar();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botón importación datos web Nazarí ───────────────────────────────────────

class _BtnImportarNazari extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;
  final bool compact;

  const _BtnImportarNazari({
    required this.empresaId,
    required this.svc,
    required this.color,
    this.compact = false,
  });

  @override
  State<_BtnImportarNazari> createState() => _BtnImportarNazariState();
}

class _BtnImportarNazariState extends State<_BtnImportarNazari> {
  bool _cargando = false;

  Future<void> _importar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar datos de la web'),
        content: const Text(
          'Se importarán a Firestore:\n'
          '• 56 eventos (presentaciones, firmas, ferias)\n'
          '• 16 entrevistas a autores\n'
          '• 48 noticias y crónicas\n\n'
          'Los datos existentes no se eliminarán (merge). '
          '¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cargando = true);
    try {
      await widget.svc.importarEventosNazariDesdeWeb(widget.empresaId);
      await widget.svc.importarBlogNazariDesdeWeb(widget.empresaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ 56 eventos + 64 entradas de blog importados desde la web'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al importar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Expanded(
        child: TextButton.icon(
          onPressed: _cargando ? null : _importar,
          icon: _cargando
              ? const SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5))
              : Icon(Icons.download_rounded, size: 14, color: widget.color),
          label: Text(_cargando ? '…' : 'Importar web',
              style: TextStyle(color: widget.color, fontSize: 10.5)),
        ),
      );
    }
    return TextButton.icon(
      onPressed: _cargando ? null : _importar,
      icon: _cargando
          ? SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
          : Icon(Icons.download_rounded, size: 14, color: widget.color),
      label: Text(_cargando ? 'Importando…' : 'Importar datos de la web',
          style: TextStyle(color: widget.color, fontSize: 12.5)),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════════
// EDITOR DE EVENTO
// ═════════════════════════════════════════════════════════════════════════════

class _PantallaEditorEvento extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final EventoWeb? evento;
  final Color? color;
  final ScrollController? scrollController;
  final VoidCallback? onGuardado;

  const _PantallaEditorEvento({
    required this.empresaId, required this.svc, this.evento,
    this.color, this.scrollController, this.onGuardado});

  @override
  State<_PantallaEditorEvento> createState() => _PantallaEditorEventoState();
}

class _PantallaEditorEventoState extends State<_PantallaEditorEvento> {
  final _tituloCtrl    = TextEditingController();
  final _subtituloCtrl = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _lugarCtrl     = TextEditingController();
  final _ciudadCtrl    = TextEditingController();
  final _horaCtrl      = TextEditingController();
  final _precioCtrl    = TextEditingController();
  final _urlCtrl       = TextEditingController();

  TipoEvento _tipo = TipoEvento.presentacion;
  DateTime   _fecha = DateTime.now().add(const Duration(days: 7));
  String?    _imagenUrl;
  bool _activo = true;
  bool _guardando = false;
  bool _subiendoImg = false;
  // Vínculos al catálogo
  String? _libroId;
  String? _libroTitulo;
  String? _autorId;
  String? _autorNombre;

  @override
  void initState() {
    super.initState();
    if (widget.evento != null) {
      final e = widget.evento!;
      _tituloCtrl.text    = e.titulo;
      _subtituloCtrl.text = e.subtitulo ?? '';
      _descCtrl.text      = e.descripcion;
      _lugarCtrl.text     = e.lugar;
      _ciudadCtrl.text    = e.ciudad ?? '';
      _horaCtrl.text      = e.hora ?? '';
      _precioCtrl.text    = e.precio ?? '';
      _urlCtrl.text       = e.urlInscripcion ?? '';
      _tipo      = e.tipo;
      _fecha     = e.fecha;
      _imagenUrl = e.imagenUrl;
      _activo    = e.activo;
      _libroId   = e.libroId;
      _libroTitulo = e.libroTitulo;
      _autorId   = e.autorId;
      _autorNombre = e.autorNombre;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose(); _subtituloCtrl.dispose(); _descCtrl.dispose();
    _lugarCtrl.dispose();  _ciudadCtrl.dispose();    _horaCtrl.dispose();
    _precioCtrl.dispose(); _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.watch<AppConfigProvider>().colorPrimario;
    // Si tiene scrollController viene como sheet; sin él, es pantalla completa
    if (widget.scrollController == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
                appBar: FluixAppBar(
          titulo: widget.evento == null ? 'Nuevo evento' : 'Editar evento',
          showLeading: true,
        ),
        body: _buildForm(context, color, null),
      );
    }
    return _buildForm(context, color, widget.scrollController);
  }

  Widget _buildForm(BuildContext context, Color color, ScrollController? scrollCtrl) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(14),
        children: [
          _card(Column(children: [
            // Imagen
            if (_imagenUrl != null)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: Image.network(_imagenUrl!, height: 140,
                      width: double.infinity, fit: BoxFit.cover)),
                Positioned(top: 6, right: 6,
                  child: Row(children: [
                    _miniBtn(Icons.swap_horiz, () => _subirImagen(), color),
                    const SizedBox(width: 4),
                    _miniBtn(Icons.close, () => setState(() => _imagenUrl = null),
                        Colors.red),
                  ])),
              ])
            else
              GestureDetector(
                onTap: _subiendoImg ? null : _subirImagen,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: _subiendoImg
                      ? Center(child: CircularProgressIndicator(color: color, strokeWidth: 2))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, color: color, size: 28),
                          Text('Imagen del evento', style: TextStyle(color: color, fontSize: 12)),
                        ]),
                ),
              ),
            const SizedBox(height: 10),
            TextField(controller: _tituloCtrl,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  hintText: 'Título del evento',
                  border: InputBorder.none, contentPadding: EdgeInsets.zero)),
            const SizedBox(height: 6),
            TextField(controller: _subtituloCtrl,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              decoration: const InputDecoration(
                  hintText: 'Subtítulo (ej: "José Prados firma ejemplares")',
                  border: InputBorder.none, contentPadding: EdgeInsets.zero)),
            const Divider(height: 16),
            TextField(controller: _descCtrl, maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Descripción del evento…',
                  border: InputBorder.none, contentPadding: EdgeInsets.zero)),
          ])),
          const SizedBox(height: 10),
          _card(Column(children: [
            // Tipo
            _fieldRow('Tipo', DropdownButton<TipoEvento>(
              value: _tipo, underline: const SizedBox(),
              items: TipoEvento.values.map((t) =>
                  DropdownMenuItem(value: t, child: Text(t.label))).toList(),
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            )),
            const Divider(height: 1),
            // Fecha
            _fieldRow('Fecha y hora', TextButton(
              onPressed: () => _seleccionarFecha(context),
              child: Text(
                '${_fecha.day.toString().padLeft(2,'0')}/'
                '${_fecha.month.toString().padLeft(2,'0')}/'
                '${_fecha.year}  '
                '${_fecha.hour.toString().padLeft(2,'0')}:'
                '${_fecha.minute.toString().padLeft(2,'0')}',
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            )),
            const Divider(height: 1),
            // Lugar
            TextField(controller: _lugarCtrl,
              decoration: const InputDecoration(
                  hintText: 'Lugar (ej: Biblioteca Municipal, c/ Gran Vía 1)',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18))),
            const Divider(height: 1),
            // Ciudad
            TextField(controller: _ciudadCtrl,
              decoration: const InputDecoration(
                  hintText: 'Ciudad (ej: Granada)',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.location_city_outlined, size: 18))),
            const Divider(height: 1),
            // Hora
            TextField(controller: _horaCtrl,
              decoration: const InputDecoration(
                  hintText: 'Hora (ej: 19:00 – 20:30 h)',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.schedule_outlined, size: 18))),
            const Divider(height: 1),
            // Precio
            TextField(controller: _precioCtrl,
              decoration: const InputDecoration(
                  hintText: 'Entrada (ej: Libre · 10€ · Con inscripción)',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.confirmation_number_outlined, size: 18))),
            const Divider(height: 1),
            SwitchListTile(
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
              title: Text(_activo ? '✅ Visible en la web' : '⏸ Oculto en la web',
                  style: const TextStyle(fontSize: 13)),
              contentPadding: EdgeInsets.zero,
              activeColor: color,
            ),
          ])),
          const SizedBox(height: 14),
          // ── Libro y autor vinculados (al final del editor) ────────────
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(Icons.link_rounded, size: 15, color: color.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text('Vincular libro y autor',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: color)),
              ]),
            ),
            // Selector de libro con buscador
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.svc.obtenerLibros(widget.empresaId),
              builder: (_, snap) {
                final items = snap.data ?? [];
                final librosIds = <String>{};
                final librosUniq = items.where((i) {
                  final id = i['id']?.toString() ?? '';
                  return id.isNotEmpty && librosIds.add(id);
                }).toList();
                return _fieldRow('Libro', GestureDetector(
                  onTap: () => _abrirSelectorBuscable(
                    context: context,
                    titulo: 'Seleccionar libro',
                    items: librosUniq,
                    getId: (i) => i['id']?.toString() ?? '',
                    getNombre: (i) => i['titulo']?.toString() ?? i['nombre']?.toString() ?? '',
                    valorActual: _libroId,
                    color: color,
                    onSeleccionar: (id, nombre) => setState(() {
                      _libroId = id;
                      _libroTitulo = nombre;
                    }),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(
                      _libroTitulo ?? 'Sin libro vinculado',
                      style: TextStyle(
                        fontSize: 12,
                        color: _libroTitulo != null ? const Color(0xFF0F172A) : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )),
                    Icon(Icons.search_rounded, size: 16, color: color.withValues(alpha: 0.5)),
                  ]),
                ));
              },
            ),
            const Divider(height: 1),
            // Selector de autor con buscador
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.svc.obtenerAutores(widget.empresaId),
              builder: (_, snap) {
                final autores = snap.data ?? [];
                final autoresIds = <String>{};
                final autoresUniq = autores.where((a) {
                  final id = a['id']?.toString() ?? '';
                  return id.isNotEmpty && autoresIds.add(id);
                }).toList();
                return _fieldRow('Autor', GestureDetector(
                  onTap: () => _abrirSelectorBuscable(
                    context: context,
                    titulo: 'Seleccionar autor',
                    items: autoresUniq,
                    getId: (i) => i['id']?.toString() ?? '',
                    getNombre: (i) => i['nombre']?.toString() ?? '',
                    valorActual: _autorId,
                    color: color,
                    onSeleccionar: (id, nombre) => setState(() {
                      _autorId = id;
                      _autorNombre = nombre;
                    }),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(
                      _autorNombre ?? 'Sin autor vinculado',
                      style: TextStyle(
                        fontSize: 12,
                        color: _autorNombre != null ? const Color(0xFF0F172A) : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )),
                    Icon(Icons.search_rounded, size: 16, color: color.withValues(alpha: 0.5)),
                  ]),
                ));
              },
            ),
            if (_libroTitulo != null || _autorNombre != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_outline_rounded, size: 14, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    [
                      if (_libroTitulo != null) _libroTitulo!,
                      if (_autorNombre != null) _autorNombre!,
                    ].join(' · '),
                    style: TextStyle(fontSize: 11.5, color: color,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ),
            ],
          ])),
          const SizedBox(height: 14),
          // Botón guardar (visible en modo sheet)
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton.icon(
              onPressed: _guardando ? null : () => _guardar(context),
              icon: _guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_guardando ? 'Guardando…' : widget.evento == null ? 'Crear evento' : 'Guardar cambios',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
    );
  }

  Widget _fieldRow(String label, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 80,
          child: Text(label, style: const TextStyle(
              fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500))),
      Expanded(child: child),
    ]),
  );

  Widget _miniBtn(IconData icon, VoidCallback? onTap, Color color) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );

  Widget _card(Widget child) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Future<void> _abrirSelectorBuscable({
    required BuildContext context,
    required String titulo,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) getId,
    required String Function(Map<String, dynamic>) getNombre,
    required String? valorActual,
    required Color color,
    required void Function(String? id, String? nombre) onSeleccionar,
  }) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final q = ctrl.text.toLowerCase();
          final filtrados = q.isEmpty
              ? items
              : items.where((i) => getNombre(i).toLowerCase().contains(q)).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: ctrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                ctrl.clear();
                                setModal(() {});
                              })
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8F9FB),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: color)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (_) => setModal(() {}),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ListTile(
                    leading: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                    title: const Text('— Sin selección —',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    selected: valorActual == null,
                    selectedTileColor: color.withValues(alpha: 0.06),
                    onTap: () {
                      onSeleccionar(null, null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ...filtrados.map((item) {
                    final id = getId(item);
                    final nombre = getNombre(item);
                    return ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded,
                          size: 18,
                          color: valorActual == id ? color : Colors.grey[300]),
                      title: Text(nombre,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: valorActual == id
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                      selected: valorActual == id,
                      selectedTileColor: color.withValues(alpha: 0.06),
                      onTap: () {
                        onSeleccionar(id, nombre);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  if (filtrados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('Sin resultados para "${ctrl.text}"',
                          style: const TextStyle(color: Colors.grey, fontSize: 13))),
                    ),
                ],
              )),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _subirImagen() async {
    setState(() => _subiendoImg = true);
    final url = await widget.svc.subirImagenDesdeGaleria(
        widget.empresaId, 'web/eventos');
    if (mounted) setState(() { _imagenUrl = url; _subiendoImg = false; });
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (!mounted) return;
    setState(() => _fecha = DateTime(d.year, d.month, d.day,
        t?.hour ?? _fecha.hour, t?.minute ?? _fecha.minute));
  }

  Future<void> _guardar(BuildContext context) async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El evento necesita un título'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _guardando = true);
    final evento = EventoWeb(
      id:             widget.evento?.id ?? '',
      titulo:         _tituloCtrl.text.trim(),
      descripcion:    _descCtrl.text.trim(),
      fecha:          _fecha,
      lugar:          _lugarCtrl.text.trim(),
      imagenUrl:      _imagenUrl,
      tipo:           _tipo,
      subtitulo:      _subtituloCtrl.text.trim().isEmpty ? null : _subtituloCtrl.text.trim(),
      hora:           _horaCtrl.text.trim().isEmpty ? null : _horaCtrl.text.trim(),
      ciudad:         _ciudadCtrl.text.trim().isEmpty ? null : _ciudadCtrl.text.trim(),
      precio:         _precioCtrl.text.trim().isEmpty ? null : _precioCtrl.text.trim(),
      urlInscripcion: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      activo:         _activo,
      libroId:        _libroId,
      libroTitulo:    _libroTitulo,
      autorId:        _autorId,
      autorNombre:    _autorNombre,
    );
    try {
      await widget.svc.guardarEvento(widget.empresaId, evento);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Evento guardado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        if (widget.onGuardado != null) {
          widget.onGuardado!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

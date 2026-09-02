import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/evento_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB EVENTOS — listado y gestión de eventos de la web
// ═════════════════════════════════════════════════════════════════════════════

class TabEventosWeb extends StatelessWidget {
  final String empresaId;
  final ContenidoWebService svc;

  const TabEventosWeb({super.key, required this.empresaId, required this.svc});

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return StreamBuilder<List<EventoWeb>>(
      stream: svc.obtenerEventos(empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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

  Widget _buildVacio(BuildContext context, Color color) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Sin eventos',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 6),
            Text('Crea presentaciones, talleres y ferias\nque aparecerán en tu web',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _abrirEditor(context, null, color),
              icon: const Icon(Icons.add),
              label: const Text('Crear primer evento'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white),
            ),
          ],
        ),
      );

  Widget _buildLista(
      BuildContext context, List<EventoWeb> eventos, Color color) {
    final proximos = eventos.where((e) => e.esFuturo).toList();
    final pasados  = eventos.where((e) => !e.esFuturo).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
      children: [
        if (proximos.isNotEmpty) ...[
          _seccionHeader('Próximos', Icons.upcoming_outlined, color),
          ...proximos.map((e) => _TarjetaEvento(
            evento: e, color: color,
            onTap: () => _abrirEditor(context, e, color),
            onToggle: (v) => svc.toggleActivoEvento(empresaId, e.id, v),
            onEliminar: () => _confirmarEliminar(context, e),
          )),
        ],
        if (pasados.isNotEmpty) ...[
          _seccionHeader('Pasados', Icons.history_outlined, Colors.grey[600]!),
          ...pasados.map((e) => _TarjetaEvento(
            evento: e, color: Colors.grey[500]!,
            onTap: () => _abrirEditor(context, e, color),
            onToggle: (v) => svc.toggleActivoEvento(empresaId, e.id, v),
            onEliminar: () => _confirmarEliminar(context, e),
          )),
        ],
      ],
    );
  }

  Widget _seccionHeader(String label, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
    child: Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: color, letterSpacing: .4)),
    ]),
  );

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

// ── Tarjeta evento ─────────────────────────────────────────────────────────

class _TarjetaEvento extends StatelessWidget {
  final EventoWeb evento;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEliminar;

  const _TarjetaEvento({
    required this.evento, required this.color,
    required this.onTap, required this.onToggle, required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final pasado = !evento.esFuturo;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: pasado ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pasado
            ? Colors.grey[200]!
            : color.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          leading: _buildFechaBox(),
          title: Text(evento.titulo,
              style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13,
                color: pasado ? Colors.grey[500] : Colors.black87,
              )),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (evento.lugar.isNotEmpty)
                Text('📍 ${evento.lugar}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Row(children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(evento.tipo.label,
                      style: TextStyle(fontSize: 9, color: color,
                          fontWeight: FontWeight.w600)),
                ),
                if (evento.precio != null) ...[
                  const SizedBox(width: 6),
                  Text(evento.precio!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ]),
            ],
          ),
          trailing: Switch(
            value: evento.activo,
            onChanged: pasado ? null : onToggle,
            activeThumbColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onTap: onTap,
        ),
        const Divider(height: 1),
        Row(children: [
          Expanded(child: TextButton.icon(
            onPressed: onTap,
            icon: Icon(Icons.edit, size: 14, color: color),
            label: Text('Editar', style: TextStyle(color: color, fontSize: 11)),
          )),
          Container(width: 1, height: 28, color: Colors.grey[200]),
          Expanded(child: TextButton.icon(
            onPressed: onEliminar,
            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
            label: const Text('Eliminar',
                style: TextStyle(color: Colors.red, fontSize: 11)),
          )),
        ]),
      ]),
    );
  }

  Widget _buildFechaBox() {
    const meses = ['ENE','FEB','MAR','ABR','MAY','JUN',
                   'JUL','AGO','SEP','OCT','NOV','DIC'];
    return Container(
      width: 48, height: 55,
      decoration: BoxDecoration(
        color: evento.esFuturo ? color : Colors.grey[300],
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${evento.fecha.day}',
            style: const TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.bold, height: 1)),
        Text(meses[evento.fecha.month - 1],
            style: const TextStyle(color: Colors.white70, fontSize: 10,
                letterSpacing: .4)),
      ]),
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
        appBar: AppBar(
          title: Text(widget.evento == null ? 'Nuevo evento' : 'Editar evento'),
          backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
          actions: [
            TextButton(
              onPressed: _guardando ? null : () => _guardar(context),
              child: Text(_guardando ? '…' : 'Guardar',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
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
                  hintText: 'Precio (ej: 10€ · Entrada libre)',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.confirmation_number_outlined, size: 18))),
            const Divider(height: 1),
            // URL inscripción
            TextField(controller: _urlCtrl,
              decoration: const InputDecoration(
                  hintText: 'URL de inscripción o más info (opcional)',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.link, size: 18))),
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
            // Selector de libro
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.svc.obtenerCatalogoWeb(widget.empresaId),
              builder: (_, snap) {
                final items = snap.data ?? [];
                return _fieldRow('Libro', DropdownButton<String?>(
                  isExpanded: true,
                  value: _libroId,
                  underline: const SizedBox(),
                  hint: const Text('Sin libro vinculado',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  items: [
                    const DropdownMenuItem<String?>(value: null,
                        child: Text('— Sin libro vinculado —',
                            style: TextStyle(fontSize: 12, color: Colors.grey))),
                    ...items.map((it) => DropdownMenuItem<String?>(
                      value: it['id'] as String?,
                      child: Text(it['nombre'] as String? ?? '',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) {
                    final selected = v != null
                        ? items.firstWhere((i) => i['id'] == v,
                            orElse: () => {})
                        : null;
                    setState(() {
                      _libroId     = v;
                      _libroTitulo = selected?['nombre'] as String?;
                    });
                  },
                ));
              },
            ),
            const Divider(height: 1),
            // Selector de autor
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.svc.obtenerAutores(widget.empresaId),
              builder: (_, snap) {
                final autores = snap.data ?? [];
                return _fieldRow('Autor', DropdownButton<String?>(
                  isExpanded: true,
                  value: _autorId,
                  underline: const SizedBox(),
                  hint: const Text('Sin autor vinculado',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  items: [
                    const DropdownMenuItem<String?>(value: null,
                        child: Text('— Sin autor vinculado —',
                            style: TextStyle(fontSize: 12, color: Colors.grey))),
                    ...autores.map((a) => DropdownMenuItem<String?>(
                      value: a['id'] as String?,
                      child: Text(a['nombre'] as String? ?? '',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) {
                    final selected = v != null
                        ? autores.firstWhere((a) => a['id'] == v,
                            orElse: () => {})
                        : null;
                    setState(() {
                      _autorId     = v;
                      _autorNombre = selected?['nombre'] as String?;
                    });
                  },
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

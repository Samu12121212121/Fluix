import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/permisos_service.dart';
import 'detalle_reserva_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO RESERVAS & CITAS — Estilo Booksy
// ─────────────────────────────────────────────────────────────────────────────

class ModuloReservasScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloReservasScreen({super.key, required this.empresaId, this.sesion});

  @override
  State<ModuloReservasScreen> createState() => _ModuloReservasScreenState();
}

class _ModuloReservasScreenState extends State<ModuloReservasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Reservas & Citas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tc,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.today, size: 18), text: 'Hoy'),
            Tab(icon: Icon(Icons.view_week, size: 18), text: 'Semana'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Estados'),
          ],
        ),
      ),
      body: _BodyStreams(
        empresaId: widget.empresaId,
        tc: _tc,
        sesion: widget.sesion,
        onNueva: () => _FormNuevaReserva.mostrar(
            context: context, empresaId: widget.empresaId),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_reservas',
        onPressed: () => _FormNuevaReserva.mostrar(
            context: context, empresaId: widget.empresaId),
        icon: const Icon(Icons.add),
        label: const Text('Nueva reserva'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streams combinados reservas + citas
// ─────────────────────────────────────────────────────────────────────────────

class _BodyStreams extends StatefulWidget {
  final String empresaId;
  final TabController tc;
  final SesionUsuario? sesion;
  final VoidCallback onNueva;

  const _BodyStreams(
      {required this.empresaId,
        required this.tc,
        required this.sesion,
        required this.onNueva});

  @override
  State<_BodyStreams> createState() => _BodyStreamsState();
}

class _BodyStreamsState extends State<_BodyStreams> {
  String? _empleadoFiltro;
  String? _servicioFiltro;

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  List<QueryDocumentSnapshot> _aplicarFiltros(
      List<QueryDocumentSnapshot> todos) {
    return todos.where((doc) {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      if (_empleadoFiltro != null) {
        final prof =
            (data['profesional'] ?? data['empleado'] ?? '').toString();
        if (prof != _empleadoFiltro) return false;
      }
      if (_servicioFiltro != null) {
        final serv = (data['servicio'] ?? data['tipo'] ?? '').toString();
        if (serv != _servicioFiltro) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildChipsFiltro(List<QueryDocumentSnapshot> todos) {
    final profesionales = todos
        .map((d) {
          final data = (d.data() as Map<String, dynamic>?) ?? {};
          return (data['profesional'] ?? data['empleado'] ?? '').toString();
        })
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final servicios = todos
        .map((d) {
          final data = (d.data() as Map<String, dynamic>?) ?? {};
          return (data['servicio'] ?? data['tipo'] ?? '').toString();
        })
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (profesionales.isEmpty && servicios.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 52,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          FilterChip(
            label: const Text('Todos'),
            selected:
                _empleadoFiltro == null && _servicioFiltro == null,
            onSelected: (_) => setState(() {
              _empleadoFiltro = null;
              _servicioFiltro = null;
            }),
          ),
          const SizedBox(width: 8),
          ...profesionales.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: const Icon(Icons.person, size: 14),
                  label: Text(p,
                      style: const TextStyle(fontSize: 12)),
                  selected: _empleadoFiltro == p,
                  onSelected: (_) => setState(() {
                    _empleadoFiltro =
                        _empleadoFiltro == p ? null : p;
                    _servicioFiltro = null;
                  }),
                ),
              )),
          if (profesionales.isNotEmpty && servicios.isNotEmpty)
            const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: VerticalDivider(width: 1),
            ),
          ...servicios.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar:
                      const Icon(Icons.room_service, size: 14),
                  label: Text(s,
                      style: const TextStyle(fontSize: 12)),
                  selected: _servicioFiltro == s,
                  onSelected: (_) => setState(() {
                    _servicioFiltro =
                        _servicioFiltro == s ? null : s;
                    _empleadoFiltro = null;
                  }),
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desde =
    Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 90)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .where('fecha_hora', isGreaterThanOrEqualTo: desde)
          .orderBy('fecha_hora')
          .snapshots(),
      builder: (ctx, snapR) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('citas')
            .where('fecha_hora', isGreaterThanOrEqualTo: desde)
            .orderBy('fecha_hora')
            .snapshots(),
        builder: (ctx2, snapC) {
          if (snapR.connectionState == ConnectionState.waiting ||
              snapC.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final todos = <QueryDocumentSnapshot>[
            ...(snapR.data?.docs ?? []),
            ...(snapC.data?.docs ?? []),
          ]..sort((a, b) =>
              _ts(a['fecha_hora']).compareTo(_ts(b['fecha_hora'])));

          final filtrados = _aplicarFiltros(todos);

          // Calcular si hay filtros disponibles
          final tieneFiltros = todos.any((d) {
            final data = (d.data() as Map<String, dynamic>?) ?? {};
            return (data['profesional'] ?? data['empleado'] ?? '').toString().isNotEmpty ||
                (data['servicio'] ?? data['tipo'] ?? '').toString().isNotEmpty;
          });

          return Column(
            children: [
              _buildChipsFiltro(todos),
              if (tieneFiltros) const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  controller: widget.tc,
                  children: [
                    _VistaHoy(
                        todos: filtrados,
                        empresaId: widget.empresaId,
                        onNueva: widget.onNueva),
                    _VistaSemana(
                        todos: filtrados,
                        empresaId: widget.empresaId,
                        onNueva: widget.onNueva),
                    _VistaEstados(
                        todos: filtrados,
                        empresaId: widget.empresaId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: HOY — strip de días + lista
// ─────────────────────────────────────────────────────────────────────────────

class _VistaHoy extends StatefulWidget {
  final List<QueryDocumentSnapshot> todos;
  final String empresaId;
  final VoidCallback onNueva;
  const _VistaHoy(
      {required this.todos, required this.empresaId, required this.onNueva});

  @override
  State<_VistaHoy> createState() => _VistaHoyState();
}

class _VistaHoyState extends State<_VistaHoy> {
  static const int _centro = 15;
  late DateTime _sel;
  late PageController _pc;

  @override
  void initState() {
    super.initState();
    _sel = _day(DateTime.now());
    _pc = PageController(initialPage: _centro, viewportFraction: 0.135);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> get _dias {
    final hoy = _day(DateTime.now());
    return List.generate(31, (i) => hoy.add(Duration(days: i - _centro)));
  }

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  List<QueryDocumentSnapshot> _delDia(DateTime d) => widget.todos
      .where((x) => _day(_ts(x['fecha_hora'])) == d)
      .toList();

  String _estado(QueryDocumentSnapshot d) =>
      ((d.data() as Map?)?['estado'] as String? ?? '').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final hoy = _day(DateTime.now());
    final reservas = _delDia(_sel);
    final conf = reservas.where((d) => _estado(d) == 'CONFIRMADA').length;
    final pend = reservas.where((d) => _estado(d) == 'PENDIENTE').length;

    return Column(children: [
      // Strip días
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Text(
                DateFormat('MMMM yyyy', 'es').format(_sel).capitalized,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: color),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() => _sel = hoy);
                  _pc.animateToPage(_centro,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                },
                icon: const Icon(Icons.today, size: 14),
                label: const Text('Hoy', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ]),
          ),
          SizedBox(
            height: 70,
            child: PageView.builder(
              controller: _pc,
              itemCount: _dias.length,
              onPageChanged: (i) => setState(() => _sel = _dias[i]),
              itemBuilder: (_, i) {
                final dia = _dias[i];
                final esSel = dia == _sel;
                final esHoy = dia == hoy;
                final rdias = _delDia(dia);
                final tieneConf =
                rdias.any((d) => _estado(d) == 'CONFIRMADA');
                final tienePend =
                rdias.any((d) => _estado(d) == 'PENDIENTE');

                return GestureDetector(
                  onTap: () => setState(() => _sel = dia),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: esSel
                          ? color
                          : esHoy
                          ? color.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: esHoy && !esSel
                          ? Border.all(
                          color: color.withValues(alpha: 0.4), width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE', 'es').format(dia)[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: esSel ? Colors.white70 : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${dia.day}',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: esSel ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (tieneConf)
                              _punto(esSel
                                  ? Colors.white
                                  : const Color(0xFF4CAF50)),
                            if (tienePend)
                              _punto(esSel
                                  ? Colors.white70
                                  : const Color(0xFFF57C00)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),

      // Sub-cabecera
      Container(
        color: const Color(0xFFF5F7FA),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Expanded(
            child: Text(
              DateFormat('EEEE, d MMMM', 'es').format(_sel).capitalized,
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (conf > 0)
            _Chip('$conf conf.', const Color(0xFF4CAF50)),
          const SizedBox(width: 6),
          if (pend > 0)
            _Chip('$pend pend.', const Color(0xFFF57C00)),
        ]),
      ),

      // Lista
      Expanded(
        child: reservas.isEmpty
            ? _Vacio(
          icono: Icons.event_available,
          msg: 'Sin reservas el ${DateFormat('d MMMM', 'es').format(_sel)}',
          onNueva: widget.onNueva,
        )
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: reservas.length,
          itemBuilder: (_, i) =>
              _Tarjeta(doc: reservas[i], empresaId: widget.empresaId),
        ),
      ),
    ]);
  }

  Widget _punto(Color c) => Container(
    width: 5, height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: SEMANA
// ─────────────────────────────────────────────────────────────────────────────

class _VistaSemana extends StatefulWidget {
  final List<QueryDocumentSnapshot> todos;
  final String empresaId;
  final VoidCallback onNueva;
  const _VistaSemana(
      {required this.todos, required this.empresaId, required this.onNueva});

  @override
  State<_VistaSemana> createState() => _VistaSemanaState();
}

class _VistaSemanaState extends State<_VistaSemana> {
  late DateTime _lunes;

  @override
  void initState() {
    super.initState();
    final h = DateTime.now();
    _lunes = DateTime(h.year, h.month, h.day)
        .subtract(Duration(days: h.weekday - 1));
  }

  List<DateTime> get _semana =>
      List.generate(7, (i) => _lunes.add(Duration(days: i)));

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  List<QueryDocumentSnapshot> _delDia(DateTime dia) =>
      widget.todos.where((d) {
        final f = _ts(d['fecha_hora']);
        return f.year == dia.year && f.month == dia.month && f.day == dia.day;
      }).toList();

  String _estado(QueryDocumentSnapshot d) =>
      ((d.data() as Map?)?['estado'] as String? ?? '').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final hoy = DateTime.now();

    return Column(children: [
      // Navegación semana
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: color,
            onPressed: () => setState(
                    () => _lunes = _lunes.subtract(const Duration(days: 7))),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${DateFormat('d MMM', 'es').format(_semana.first)} – '
                    '${DateFormat('d MMM yyyy', 'es').format(_semana.last)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: color,
            onPressed: () =>
                setState(() => _lunes = _lunes.add(const Duration(days: 7))),
          ),
          TextButton(
            onPressed: () => setState(() {
              final h = DateTime.now();
              _lunes = DateTime(h.year, h.month, h.day)
                  .subtract(Duration(days: h.weekday - 1));
            }),
            child: const Text('Hoy', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),

      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: _semana.map((dia) {
            final esHoy = dia.year == hoy.year &&
                dia.month == hoy.month &&
                dia.day == hoy.day;
            final reservas = _delDia(dia);
            final conf =
                reservas.where((d) => _estado(d) == 'CONFIRMADA').length;
            final pend =
                reservas.where((d) => _estado(d) == 'PENDIENTE').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera día
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: esHoy ? color : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(children: [
                    Text(
                      DateFormat('EEEE d', 'es').format(dia).capitalized,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: esHoy ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (conf > 0)
                      _Chip('$conf conf.',
                          esHoy ? Colors.white : const Color(0xFF4CAF50),
                          textColor: esHoy ? color : Colors.white),
                    const SizedBox(width: 4),
                    if (pend > 0)
                      _Chip('$pend pend.',
                          esHoy ? Colors.white70 : const Color(0xFFF57C00),
                          textColor: esHoy ? color : Colors.white),
                    if (reservas.isEmpty)
                      Text('Libre',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                              esHoy ? Colors.white60 : Colors.grey[400])),
                  ]),
                ),
                ...reservas.map((doc) => _Tarjeta(
                    doc: doc, empresaId: widget.empresaId, compact: true)),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: ESTADOS (Confirmadas / Por confirmar / Pendientes / Canceladas)
// ─────────────────────────────────────────────────────────────────────────────

class _VistaEstados extends StatefulWidget {
  final List<QueryDocumentSnapshot> todos;
  final String empresaId;
  const _VistaEstados({required this.todos, required this.empresaId});

  @override
  State<_VistaEstados> createState() => _VistaEstadosState();
}

class _VistaEstadosState extends State<_VistaEstados>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  String _est(QueryDocumentSnapshot d) =>
      ((d.data() as Map?)?['estado'] as String? ?? '').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final conf = widget.todos.where((d) => _est(d) == 'CONFIRMADA').toList();
    final porConf = widget.todos
        .where(
            (d) => _est(d) == 'POR_CONFIRMAR' || _est(d) == 'SOLICITADA')
        .toList();
    final pend = widget.todos.where((d) => _est(d) == 'PENDIENTE').toList();
    final canc = widget.todos.where((d) => _est(d) == 'CANCELADA').toList();

    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tc,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: [
            _tabBadge('Confirmadas', conf.length, const Color(0xFF4CAF50)),
            _tabBadge(
                'Por confirmar', porConf.length, const Color(0xFF1976D2)),
            _tabBadge('Pendientes', pend.length, const Color(0xFFF57C00)),
            _tabBadge('Canceladas', canc.length, const Color(0xFFD32F2F)),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tc,
          children: [
            _ListaEstado(conf, widget.empresaId,
                'No hay reservas confirmadas'),
            _ListaEstado(porConf, widget.empresaId,
                'No hay reservas por confirmar 🎉'),
            _ListaEstado(pend, widget.empresaId,
                'No hay reservas pendientes 🎉'),
            _ListaEstado(canc, widget.empresaId, 'No hay cancelaciones'),
          ],
        ),
      ),
    ]);
  }

  Tab _tabBadge(String label, int n, Color c) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Text('$n',
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class _ListaEstado extends StatelessWidget {
  final List<QueryDocumentSnapshot> reservas;
  final String empresaId;
  final String vacio;
  const _ListaEstado(this.reservas, this.empresaId, this.vacio);

  @override
  Widget build(BuildContext context) {
    if (reservas.isEmpty) {
      return _Vacio(icono: Icons.check_circle_outline, msg: vacio);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: reservas.length,
      itemBuilder: (_, i) =>
          _Tarjeta(doc: reservas[i], empresaId: empresaId),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE RESERVA — estilo Booksy
// ─────────────────────────────────────────────────────────────────────────────

class _Tarjeta extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String empresaId;
  final bool compact;
  const _Tarjeta(
      {required this.doc, required this.empresaId, this.compact = false});

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> get _d =>
      (doc.data() as Map<String, dynamic>?) ?? {};

  String get _estado =>
      (_d['estado'] as String? ?? 'PENDIENTE').toUpperCase();

  Color get _color {
    switch (_estado) {
      case 'CONFIRMADA':
        return const Color(0xFF4CAF50);
      case 'CANCELADA':
        return const Color(0xFFD32F2F);
      case 'COMPLETADA':
        return const Color(0xFF607D8B);
      case 'POR_CONFIRMAR':
      case 'SOLICITADA':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFFF57C00);
    }
  }

  IconData get _icono {
    switch (_estado) {
      case 'CONFIRMADA':
        return Icons.check_circle;
      case 'CANCELADA':
        return Icons.cancel;
      case 'COMPLETADA':
        return Icons.task_alt;
      case 'POR_CONFIRMAR':
      case 'SOLICITADA':
        return Icons.schedule;
      default:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente = '${_d['cliente'] ?? _d['nombre_cliente'] ?? 'Anónimo'}';
    final servicio = '${_d['servicio'] ?? _d['tipo'] ?? ''}';
    final fecha = _ts(_d['fecha_hora']);
    final precio = _d['precio'];
    final profesional = '${_d['profesional'] ?? _d['empleado'] ?? ''}';
    
    // Convertir comensales a int de forma segura
    final comensalesRaw = _d['numero_personas'];
    int? comensales;
    if (comensalesRaw != null) {
      if (comensalesRaw is num) {
        comensales = comensalesRaw.toInt();
      } else if (comensalesRaw is String) {
        comensales = int.tryParse(comensalesRaw);
      }
    }
    
    final esCita = doc.reference.path.contains('citas');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: compact ? 0.5 : 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _color.withValues(alpha: 0.2), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _detalle(context),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Row(children: [
            // Hora
            SizedBox(
              width: 44,
              child: Column(children: [
                Text(
                  DateFormat('HH:mm').format(fecha),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 12 : 14,
                      color: _color),
                ),
                if (!compact)
                  Text(DateFormat('d MMM', 'es').format(fecha),
                      style:
                      TextStyle(fontSize: 10, color: Colors.grey[500])),
              ]),
            ),
            // Franja de color
            Container(
              width: 3,
              height: compact ? 36 : 52,
              decoration: BoxDecoration(
                  color: _color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(cliente,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (esCita
                            ? const Color(0xFF7B1FA2)
                            : const Color(0xFF1976D2))
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        esCita ? 'Cita' : 'Reserva',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: esCita
                                ? const Color(0xFF7B1FA2)
                                : const Color(0xFF1976D2)),
                      ),
                    ),
                  ]),
                  if (servicio.isNotEmpty)
                    Text(servicio,
                        style:
                        TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  if (!compact && profesional.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.person_pin,
                          size: 11, color: Color(0xFF5C6BC0)),
                      const SizedBox(width: 3),
                      Text(profesional,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF5C6BC0),
                              fontWeight: FontWeight.w600)),
                    ]),
                  if (!compact && comensales != null && comensales > 0)
                    Row(children: [
                      const Icon(Icons.people,
                          size: 11, color: Color(0xFF607D8B)),
                      const SizedBox(width: 3),
                      Text('$comensales ${comensales == 1 ? "comensal" : "comensales"}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF607D8B),
                              fontWeight: FontWeight.w600)),
                    ]),
                ],
              ),
            ),
            // Precio + icono
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (precio != null)
                  Text(
                    '€${(precio as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1976D2)),
                  ),
                const SizedBox(height: 4),
                Icon(_icono, color: _color, size: 18),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _detalle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleReservaScreen(
          doc: doc,
          empresaId: empresaId,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  const _Chip(this.label, this.color, {this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: textColor != null ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor ?? color)),
    );
  }
}

class _Vacio extends StatelessWidget {
  final IconData icono;
  final String msg;
  final VoidCallback? onNueva;
  const _Vacio({required this.icono, required this.msg, this.onNueva});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icono, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(msg,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
            textAlign: TextAlign.center),
        // Botón quitado - solo usar el FAB principal
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO NUEVA RESERVA
// ─────────────────────────────────────────────────────────────────────────────

class _FormNuevaReserva {
  static void mostrar({
    required BuildContext context,
    required String empresaId,
    String collectionId = 'reservas',
    DateTime? fechaInicial,
  }) {
    final clienteCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final servicioCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final comensalesCtrl = TextEditingController(text: '1');
    DateTime fecha = fechaInicial ?? DateTime.now();
    TimeOfDay hora = TimeOfDay.fromDateTime(fecha);
    String estadoSel = 'PENDIENTE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(children: [
                  const Text('Nueva reserva',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    _tf(clienteCtrl, 'Cliente *', Icons.person_outline),
                    _tf(telefonoCtrl, 'Teléfono', Icons.phone_outlined),
                    _tf(servicioCtrl, 'Servicio', Icons.spa_outlined),
                    Row(
                      children: [
                        Expanded(
                          child: _tf(precioCtrl, 'Precio (€)', Icons.euro_outlined,
                              keyboard: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _tf(comensalesCtrl, 'Comensales', Icons.people_outlined,
                              keyboard: TextInputType.number),
                        ),
                      ],
                    ),
                    // Fecha y hora
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined,
                          color: Colors.grey),
                      title: Text(
                        DateFormat('EEEE d MMMM · HH:mm', 'es')
                            .format(DateTime(fecha.year, fecha.month, fecha.day,
                            hora.hour, hora.minute))
                            .capitalized,
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: fecha,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (d != null) setS(() => fecha = d);
                            },
                            child: const Text('Fecha'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final t = await showTimePicker(
                                  context: ctx, initialTime: hora);
                              if (t != null) setS(() => hora = t);
                            },
                            child: const Text('Hora'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Estado',
                        style:
                        TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['PENDIENTE', 'CONFIRMADA', 'POR_CONFIRMAR']
                          .map((e) => ChoiceChip(
                        label: Text(e,
                            style: const TextStyle(fontSize: 12)),
                        selected: estadoSel == e,
                        onSelected: (_) =>
                            setS(() => estadoSel = e),
                      ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    _tf(notasCtrl, 'Notas', Icons.notes_outlined,
                        maxLines: 3),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (clienteCtrl.text.trim().isEmpty) return;
                    final dt = DateTime(fecha.year, fecha.month, fecha.day,
                        hora.hour, hora.minute);
                    await FirebaseFirestore.instance
                        .collection('empresas')
                        .doc(empresaId)
                        .collection(collectionId)
                        .add({
                      'cliente': clienteCtrl.text.trim(),
                      'telefono': telefonoCtrl.text.trim(),
                      'servicio': servicioCtrl.text.trim(),
                      'precio': double.tryParse(precioCtrl.text.trim()),
                      'numero_personas': int.tryParse(comensalesCtrl.text.trim()) ?? 1,
                      'notas': notasCtrl.text.trim(),
                      'estado': estadoSel,
                      'fecha_hora': Timestamp.fromDate(dt),
                      'fecha_creacion': FieldValue.serverTimestamp(),
                    });

                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar reserva'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  static Widget _tf(
      TextEditingController c, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      );
}

extension _Cap on String {
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
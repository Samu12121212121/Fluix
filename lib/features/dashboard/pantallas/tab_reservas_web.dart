import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/modelos/reserva.dart';
import '../../../services/contenido_web_service.dart';

// ignore_for_file: use_build_context_synchronously

// ═════════════════════════════════════════════════════════════════════════════
// TAB RESERVAS WEB — calendario semanal + lista de reservas
// Colección: empresas/{id}/reservas  (soporta cualquier origen y campos)
// ═════════════════════════════════════════════════════════════════════════════

class TabReservasWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color? color;

  const TabReservasWeb({
    super.key,
    required this.empresaId,
    required this.svc,
    this.color,
  });

  @override
  State<TabReservasWeb> createState() => _TabReservasWebState();
}

class _TabReservasWebState extends State<TabReservasWeb> {
  late DateTime _semanaInicio;
  DateTime? _diaSeleccionado;
  String _filtroEstado   = 'todas';
  String? _filtroServicio;            // null = todos los servicios
  bool _modoSeleccion    = false;
  final Set<String> _seleccionadas = {};

  Color get _color => widget.color ?? const Color(0xFF3B82F6);

  static const _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _diasLargo = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
  static const _meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];

  // Carga sin orderBy para tolerar cualquier tipo de campo fecha_hora
  Stream<List<Reserva>> get _stream => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('reservas')
      .limit(500)
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) {
              try { return Reserva.fromMap(d.data(), d.id); }
              catch (_) { return null; }
            })
            .whereType<Reserva>()
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        return list;
      });

  @override
  void initState() {
    super.initState();
    _semanaInicio = _lunesDeEstaSemana(DateTime.now());
  }

  static DateTime _lunesDeEstaSemana(DateTime d) {
    final lunes = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(lunes.year, lunes.month, lunes.day);
  }

  void _semanaAnterior() =>
      setState(() { _semanaInicio = _semanaInicio.subtract(const Duration(days: 7)); _diaSeleccionado = null; });
  void _semanaSiguiente() =>
      setState(() { _semanaInicio = _semanaInicio.add(const Duration(days: 7)); _diaSeleccionado = null; });
  void _irAHoy() =>
      setState(() { _semanaInicio = _lunesDeEstaSemana(DateTime.now()); _diaSeleccionado = DateTime.now(); });

  bool _mismodia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Reserva> _filtrar(List<Reserva> todas) {
    var r = todas;
    if (_diaSeleccionado != null) {
      r = r.where((x) => _mismodia(x.fechaHora, _diaSeleccionado!)).toList();
    } else {
      final fin = _semanaInicio.add(const Duration(days: 7));
      r = r.where((x) =>
        !x.fechaHora.isBefore(_semanaInicio) && x.fechaHora.isBefore(fin)).toList();
    }
    if (_filtroEstado != 'todas') {
      r = r.where((x) => _estadoNorm(x.estado) == _filtroEstado).toList();
    }
    if (_filtroServicio != null) {
      r = r.where((x) => x.servicio == _filtroServicio).toList();
    }
    return r;
  }

  List<String> _serviciosUnicos(List<Reserva> todas) {
    final set = <String>{};
    for (final r in todas) {
      if (r.servicio.isNotEmpty) set.add(r.servicio);
    }
    return set.toList()..sort();
  }

  void _toggleSeleccion(Reserva r) {
    setState(() {
      if (_seleccionadas.contains(r.id)) {
        _seleccionadas.remove(r.id);
      } else {
        _seleccionadas.add(r.id);
      }
    });
  }

  void _salirModoSeleccion() =>
      setState(() { _modoSeleccion = false; _seleccionadas.clear(); });

  Future<void> _confirmarLote() async {
    for (final id in List<String>.from(_seleccionadas)) {
      await widget.svc.confirmarReservaWeb(widget.empresaId, id);
    }
    _salirModoSeleccion();
  }

  Future<void> _cancelarLote() async {
    for (final id in List<String>.from(_seleccionadas)) {
      await widget.svc.cancelarReservaWeb(widget.empresaId, id);
    }
    _salirModoSeleccion();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reserva>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final todas = snap.data ?? [];
        final filtradas = _filtrar(todas);
        final pendientes  = todas.where((r) => _estadoNorm(r.estado) == 'PENDIENTE').length;
        final confirmadas = todas.where((r) => _estadoNorm(r.estado) == 'CONFIRMADA').length;
        final hoy = todas.where((r) => _mismodia(r.fechaHora, DateTime.now())).length;
        final servicios = _serviciosUnicos(todas);

        return Stack(children: [
          Column(children: [
            _buildCabecera(pendientes, hoy, confirmadas),
            _buildCalendario(todas),
            _buildFiltros(servicios),
            const Divider(height: 1),
            Expanded(
              child: filtradas.isEmpty
                  ? _buildVacio()
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(12, 8, 12,
                          _modoSeleccion ? 80 : 20),
                      itemCount: filtradas.length,
                      itemBuilder: (_, i) {
                        final r = filtradas[i];
                        final prev = i > 0 ? filtradas[i - 1] : null;
                        final mostrarFecha = prev == null ||
                            !_mismodia(r.fechaHora, prev.fechaHora);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (mostrarFecha) _buildDiaLabel(r.fechaHora),
                            _buildReservaCard(r),
                            const SizedBox(height: 6),
                          ],
                        );
                      },
                    ),
            ),
          ]),
          // ── Barra de selección en lote ──────────────────────────────────
          if (_modoSeleccion)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildSeleccionBarra(),
            ),
        ]);
      },
    );
  }

  // ── Cabecera ─────────────────────────────────────────────────────────────────

  Widget _buildCabecera(int pendientes, int hoy, int confirmadas) {
    final url = 'https://fluixcrm.app/reservar/${widget.empresaId}';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Reservas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _color))),
          // Copiar URL
          _iconChip(Icons.link_rounded, 'URL', () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('URL copiada'), backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2)));
          }),
          const SizedBox(width: 6),
          // Seleccionar lote
          _iconChip(
            _modoSeleccion ? Icons.close_rounded : Icons.checklist_rounded,
            _modoSeleccion ? 'Cancelar' : 'Seleccionar',
            _modoSeleccion ? _salirModoSeleccion
                           : () => setState(() => _modoSeleccion = true),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _mostrarFormNuevaReserva(context),
            icon: const Icon(Icons.add_rounded, size: 14),
            label: const Text('Nueva'),
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _kpi(Icons.pending_actions_rounded, const Color(0xFFF59E0B), '$pendientes', 'Pendientes'),
          const SizedBox(width: 6),
          _kpi(Icons.today_rounded, _color, '$hoy', 'Hoy'),
          const SizedBox(width: 6),
          _kpi(Icons.check_circle_rounded, const Color(0xFF10B981), '$confirmadas', 'Confirmadas'),
        ]),
      ]),
    );
  }

  Widget _iconChip(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11,
                color: Color(0xFF475569), fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _kpi(IconData icon, Color c, String val, String lbl) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
          Text(lbl, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ])),
      ]),
    ),
  );

  // ── Calendario semanal ────────────────────────────────────────────────────────

  Widget _buildCalendario(List<Reserva> todas) {
    final hoy = DateTime.now();
    final finSemana = _semanaInicio.add(const Duration(days: 7));
    final mesLabel = '${_meses[_semanaInicio.month - 1]} ${_semanaInicio.year}';

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(children: [
        // Navegación semana
        Row(children: [
          IconButton(
            onPressed: _semanaAnterior,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(mesLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Color(0xFF334155)))),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _irAHoy,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Hoy', style: TextStyle(fontSize: 11, color: _color,
                fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _semanaSiguiente,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // Chips de día
        Row(children: List.generate(7, (i) {
          final dia = _semanaInicio.add(Duration(days: i));
          final esHoy = _mismodia(dia, hoy);
          final esSel = _diaSeleccionado != null && _mismodia(dia, _diaSeleccionado!);
          final count = todas.where((r) => _mismodia(r.fechaHora, dia)).length;
          final pendDia = todas.where((r) =>
              _mismodia(r.fechaHora, dia) &&
              _estadoNorm(r.estado) == 'PENDIENTE').length;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() =>
                  _diaSeleccionado = esSel ? null : dia),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: esSel ? _color : esHoy
                      ? _color.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: esSel ? _color : esHoy
                        ? _color.withValues(alpha: 0.3)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_dias[i], style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: esSel ? Colors.white
                          : esHoy ? _color
                          : const Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Text('${dia.day}', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: esSel ? Colors.white
                          : esHoy ? _color
                          : const Color(0xFF0F172A))),
                  const SizedBox(height: 3),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: esSel
                            ? Colors.white.withValues(alpha: 0.3)
                            : pendDia > 0
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$count', style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: esSel ? Colors.white
                              : pendDia > 0
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF15803D))),
                    )
                  else
                    const SizedBox(height: 14),
                ]),
              ),
            ),
          );
        })),
        if (_diaSeleccionado == null) ...[
          const SizedBox(height: 6),
          Text(
            '${_semanaInicio.day} ${_meses[_semanaInicio.month-1]} – '
            '${finSemana.subtract(const Duration(days:1)).day} '
            '${_meses[finSemana.subtract(const Duration(days:1)).month-1]}',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
        // ── Ocupación por horas (solo cuando hay día seleccionado) ─────────
        if (_diaSeleccionado != null) ...[
          const SizedBox(height: 8),
          _buildOcupacion(todas),
        ],
      ]),
    );
  }

  Widget _buildOcupacion(List<Reserva> todas) {
    const slots = [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];
    final dia = _diaSeleccionado!;
    final diaReservas = todas
        .where((r) => _mismodia(r.fechaHora, dia))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Ocupación', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8), letterSpacing: 0.5)),
      const SizedBox(height: 5),
      Row(children: slots.map((h) {
        final enEsaHora = diaReservas
            .where((r) => r.fechaHora.hour == h)
            .toList();
        final pendEnHora = enEsaHora
            .any((r) => _estadoNorm(r.estado) == 'PENDIENTE');
        final hayReserva = enEsaHora.isNotEmpty;
        return Expanded(child: Column(children: [
          Container(
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: hayReserva
                  ? (pendEnHora
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7))
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: hayReserva
                    ? (pendEnHora
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981))
                    : const Color(0xFFE2E8F0),
                width: 0.5,
              ),
            ),
            child: hayReserva
                ? Center(child: Text('${enEsaHora.length}',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: pendEnHora
                            ? const Color(0xFFB45309)
                            : const Color(0xFF15803D))))
                : null,
          ),
          const SizedBox(height: 2),
          Text('$h', style: const TextStyle(
              fontSize: 8, color: Color(0xFFCBD5E1))),
        ]));
      }).toList()),
    ]);
  }

  // ── Filtros de estado + servicio ──────────────────────────────────────────────

  Widget _buildFiltros(List<String> servicios) {
    const filtros = [
      ('todas', 'Todas'),
      ('PENDIENTE', 'Pendientes'),
      ('CONFIRMADA', 'Confirmadas'),
      ('CANCELADA', 'Canceladas'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Estado
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: filtros.map((f) {
            final sel = _filtroEstado == f.$1;
            return GestureDetector(
              onTap: () => setState(() => _filtroEstado = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? _color : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(f.$2, style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? Colors.white : const Color(0xFF64748B))),
              ),
            );
          }).toList()),
        ),
        // Servicio (solo si hay más de uno)
        if (servicios.length > 1) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chipServicio(null, 'Todos'),
              ...servicios.map((s) => _chipServicio(s, s)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _chipServicio(String? val, String label) {
    final sel = _filtroServicio == val;
    return GestureDetector(
      onTap: () => setState(() => _filtroServicio = val),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                     : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? const Color(0xFF7C3AED)
                       : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 11,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? const Color(0xFF7C3AED) : const Color(0xFF64748B))),
      ),
    );
  }

  // ── Label de día ──────────────────────────────────────────────────────────────

  Widget _buildDiaLabel(DateTime dt) {
    final hoy = DateTime.now();
    String label;
    if (_mismodia(dt, hoy)) {
      label = 'Hoy · ${dt.day} ${_meses[dt.month-1]}';
    } else if (_mismodia(dt, hoy.add(const Duration(days:1)))) {
      label = 'Mañana · ${dt.day} ${_meses[dt.month-1]}';
    } else {
      label = '${_diasLargo[dt.weekday-1]} ${dt.day} ${_meses[dt.month-1]}';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Text(label, style: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w700,
          color: _color, letterSpacing: 0.3)),
    );
  }

  // ── Tarjeta de reserva ────────────────────────────────────────────────────────

  // ── Color por origen ──────────────────────────────────────────────────────────
  static Color _origenColor(String? origen) => switch ((origen ?? '').toLowerCase()) {
    'web'      => const Color(0xFF3B82F6),
    'app'      => const Color(0xFF8B5CF6),
    'telefono' => const Color(0xFFF59E0B),
    'manual'   => const Color(0xFF94A3B8),
    _          => const Color(0xFF94A3B8),
  };

  static String _origenLabel(String? origen) => switch ((origen ?? '').toLowerCase()) {
    'web'      => 'Web',
    'app'      => 'App',
    'telefono' => 'Tel.',
    'manual'   => 'Man.',
    _          => '',
  };

  Widget _buildReservaCard(Reserva r) {
    final estado = _estadoNorm(r.estado);
    final (estColor, estBg, estLabel) = _estadoStyle(estado);
    final esPasada = r.fechaHora.isBefore(DateTime.now());
    final hora = '${r.fechaHora.hour.toString().padLeft(2,'0')}:'
        '${r.fechaHora.minute.toString().padLeft(2,'0')}';
    final origenC = _origenColor(r.origen);
    final seleccionada = _seleccionadas.contains(r.id);

    return Material(
      color: seleccionada
          ? _color.withValues(alpha: 0.06)
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _modoSeleccion
            ? () => _toggleSeleccion(r)
            : () => _mostrarDetalle(context, r),
        onLongPress: _modoSeleccion
            ? null
            : () {
                setState(() => _modoSeleccion = true);
                _toggleSeleccion(r);
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionada
                  ? _color.withValues(alpha: 0.4)
                  : estado == 'PENDIENTE' && !esPasada
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFE8EDF2),
            ),
          ),
          child: Row(children: [
            // ── Franja de color por origen ────────────────────────────────
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: esPasada
                    ? const Color(0xFFE2E8F0)
                    : origenC.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12)),
              ),
            ),
            const SizedBox(width: 10),
            // ── Hora ─────────────────────────────────────────────────────
            SizedBox(
              width: 40,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(hora, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: esPasada ? const Color(0xFFCBD5E1) : _color)),
                if (r.comensales > 0)
                  Text('${r.comensales}p', style: const TextStyle(
                      fontSize: 10, color: Color(0xFF94A3B8))),
              ]),
            ),
            Container(width: 1, height: 36,
                color: const Color(0xFFE8EDF2),
                margin: const EdgeInsets.symmetric(horizontal: 8)),
            // ── Info ──────────────────────────────────────────────────────
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(
                      r.clienteNombre.isNotEmpty ? r.clienteNombre : 'Sin nombre',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: esPasada
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A)))),
                  // Badge origen
                  if (_origenLabel(r.origen).isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: origenC.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_origenLabel(r.origen),
                          style: TextStyle(fontSize: 9,
                              fontWeight: FontWeight.w700, color: origenC)),
                    ),
                ]),
                Row(children: [
                  if (r.clienteTelefono.isNotEmpty) ...[
                    Text(r.clienteTelefono, style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 8),
                  ],
                  if (r.servicio.isNotEmpty)
                    Text(r.servicio, style: const TextStyle(
                        fontSize: 10, color: Color(0xFFCBD5E1))),
                ]),
              ]),
            )),
            // ── Derecha: estado + acciones ────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _modoSeleccion
                  ? Icon(
                      seleccionada
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 22,
                      color: seleccionada ? _color : const Color(0xFFCBD5E1),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: estBg, borderRadius: BorderRadius.circular(20)),
                        child: Text(estLabel, style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: estColor)),
                      ),
                      if (estado == 'PENDIENTE' && !esPasada) ...[
                        const SizedBox(height: 5),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _accionBtn(Icons.close_rounded, const Color(0xFFEF4444),
                              const Color(0xFFFEE2E2), () => _cancelar(r)),
                          const SizedBox(width: 5),
                          _accionBtn(Icons.check_rounded, const Color(0xFF10B981),
                              const Color(0xFFDCFCE7), () => _confirmar(r)),
                        ]),
                      ],
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _accionBtn(IconData icon, Color c, Color bg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: c),
        ),
      );

  Widget _buildSeleccionBarra() => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Text('${_seleccionadas.length} seleccionada${_seleccionadas.length != 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
              fontSize: 13)),
      const Spacer(),
      if (_seleccionadas.isNotEmpty) ...[
        _loteBtn(Icons.close_rounded, 'Cancelar', const Color(0xFFEF4444),
            _cancelarLote),
        const SizedBox(width: 8),
        _loteBtn(Icons.check_rounded, 'Confirmar', const Color(0xFF10B981),
            _confirmarLote),
      ],
    ]),
  );

  Widget _loteBtn(IconData icon, String label, Color c, VoidCallback onTap) =>
      FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: c,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _buildVacio() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.calendar_month_rounded, size: 52,
        color: _color.withValues(alpha: 0.18)),
    const SizedBox(height: 14),
    const Text('Sin reservas', style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
    const SizedBox(height: 6),
    Text(
      _diaSeleccionado != null
          ? 'No hay reservas para este día'
          : 'No hay reservas esta semana',
      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
    ),
  ]));

  // ── Acciones ─────────────────────────────────────────────────────────────────

  Future<void> _confirmar(Reserva r) async {
    await widget.svc.confirmarReservaWeb(widget.empresaId, r.id);
  }

  Future<void> _cancelar(Reserva r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar reserva',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text('¿Cancelar la reserva de ${r.clienteNombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await widget.svc.cancelarReservaWeb(widget.empresaId, r.id);
    }
  }

  void _mostrarDetalle(BuildContext context, Reserva r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DetalleReservaSheet(
          reserva: r, empresaId: widget.empresaId, color: _color,
          onConfirmar: () => _confirmar(r),
          onCancelar:  () => _cancelar(r)),
    );
  }

  void _mostrarFormNuevaReserva(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormNuevaReserva(
        empresaId: widget.empresaId,
        color: _color,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static String _estadoNorm(String? estado) =>
      (estado ?? 'PENDIENTE').toUpperCase();

  static (Color, Color, String) _estadoStyle(String estado) => switch (estado) {
    'CONFIRMADA' => (const Color(0xFF15803D), const Color(0xFFDCFCE7), 'Confirmada'),
    'CANCELADA'  => (const Color(0xFFB91C1C), const Color(0xFFFEE2E2), 'Cancelada'),
    'COMPLETADA' => (const Color(0xFF475569), const Color(0xFFF1F5F9), 'Completada'),
    _            => (const Color(0xFFB45309), const Color(0xFFFEF3C7), 'Pendiente'),
  };

  static String _formatFechaHora(DateTime dt) {
    final ahora = DateTime.now();
    final esHoy = dt.year == ahora.year && dt.month == ahora.month && dt.day == ahora.day;
    final esManana = dt.year == ahora.year && dt.month == ahora.month &&
        dt.day == ahora.add(const Duration(days:1)).day;
    final hora = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    if (esHoy)    return 'Hoy $hora';
    if (esManana) return 'Mañana $hora';
    return '${dt.day} ${m[dt.month - 1]} · $hora';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detalle de reserva (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _DetalleReservaSheet extends StatefulWidget {
  final Reserva reserva;
  final String empresaId;
  final Color color;
  final VoidCallback onConfirmar;
  final VoidCallback onCancelar;

  const _DetalleReservaSheet({
    required this.reserva,
    required this.empresaId,
    required this.color,
    required this.onConfirmar,
    required this.onCancelar,
  });

  @override
  State<_DetalleReservaSheet> createState() => _DetalleReservaSheetState();
}

class _DetalleReservaSheetState extends State<_DetalleReservaSheet> {
  late final TextEditingController _notaCtrl;
  bool _guardandoNota = false;

  @override
  void initState() {
    super.initState();
    _notaCtrl = TextEditingController(
        text: (widget.reserva.toMap()['nota_interna'] as String?) ?? '');
  }

  @override
  void dispose() { _notaCtrl.dispose(); super.dispose(); }

  Future<void> _guardarNota() async {
    setState(() => _guardandoNota = true);
    try {
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('reservas').doc(widget.reserva.id)
          .update({'nota_interna': _notaCtrl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nota guardada'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _guardandoNota = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reserva;
    final estado = (r.estado ?? 'PENDIENTE').toUpperCase();
    final origenC = _TabReservasWebState._origenColor(r.origen);
    final origenL = _TabReservasWebState._origenLabel(r.origen);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(r.clienteNombre.isNotEmpty ? r.clienteNombre : 'Reserva',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          if (origenL.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: origenC.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(origenL, style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: origenC)),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        Text(_TabReservasWebState._formatFechaHora(r.fechaHora),
            style: TextStyle(fontSize: 14, color: widget.color)),
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 10),
        _fila(Icons.people_rounded, 'Personas', '${r.comensales}'),
        if (r.servicio.isNotEmpty)
          _fila(Icons.restaurant_rounded, 'Servicio', r.servicio),
        if (r.clienteTelefono.isNotEmpty)
          _fila(Icons.phone_rounded, 'Teléfono', r.clienteTelefono),
        if (r.clienteEmail.isNotEmpty)
          _fila(Icons.email_rounded, 'Email', r.clienteEmail),
        if ((r.ubicacion ?? '').isNotEmpty)
          _fila(Icons.chair_rounded, 'Ubicación', r.ubicacion!),
        if ((r.alergenos ?? '') == 'si')
          _fila(Icons.warning_rounded, 'Alérgenos',
              r.alergenosDetalle ?? 'Sí, ver detalle',
              color: const Color(0xFFF59E0B)),
        if ((r.comentarios ?? '').isNotEmpty)
          _fila(Icons.notes_rounded, 'Notas del cliente', r.comentarios!),
        // ── Nota interna ─────────────────────────────────────────────────
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.lock_outline_rounded, size: 14,
              color: Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          const Text('Nota interna (solo la ve el negocio)',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: _notaCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Añade una nota privada…',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _guardandoNota ? null : _guardarNota,
            icon: _guardandoNota
                ? const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 14),
            label: const Text('Guardar nota'),
            style: TextButton.styleFrom(
              foregroundColor: widget.color,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (estado == 'PENDIENTE')
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(context); widget.onCancelar(); },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancelar reserva'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); widget.onConfirmar(); },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Confirmar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _fila(IconData icon, String label, String valor, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color ?? const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(
              fontSize: 13, color: Color(0xFF64748B))),
          Expanded(child: Text(valor, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF0F172A)))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulario nueva reserva manual
// ─────────────────────────────────────────────────────────────────────────────

class _FormNuevaReserva extends StatefulWidget {
  final String empresaId;
  final Color color;

  const _FormNuevaReserva({required this.empresaId, required this.color});

  @override
  State<_FormNuevaReserva> createState() => _FormNuevaReservaState();
}

class _FormNuevaReservaState extends State<_FormNuevaReserva> {
  final _nombreCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _notasCtrl    = TextEditingController();
  int    _comensales  = 2;
  DateTime _fecha     = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _hora     = const TimeOfDay(hour: 14, minute: 0);
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose(); _telefonoCtrl.dispose();
    _emailCtrl.dispose();  _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft,
          child: Text('Nueva reserva manual',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)))),
        const SizedBox(height: 16),
        _field(_nombreCtrl, 'Nombre del cliente'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_telefonoCtrl, 'Teléfono',
              tipo: TextInputType.phone)),
          const SizedBox(width: 10),
          Expanded(child: _field(_emailCtrl, 'Email',
              tipo: TextInputType.emailAddress)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context,
                    initialDate: _fecha,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _fecha = d);
              },
              child: _readonlyField(
                Icons.calendar_today_rounded,
                '${_fecha.day.toString().padLeft(2,'0')}/${_fecha.month.toString().padLeft(2,'0')}/${_fecha.year}',
                'Fecha',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _hora);
                if (t != null) setState(() => _hora = t);
              },
              child: _readonlyField(
                Icons.access_time_rounded,
                '${_hora.hour.toString().padLeft(2,'0')}:${_hora.minute.toString().padLeft(2,'0')}',
                'Hora',
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: _comensales > 1
                    ? () => setState(() => _comensales--)
                    : null,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
              Expanded(child: Center(child: Text('$_comensales',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => setState(() => _comensales++),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        _field(_notasCtrl, 'Notas (opcional)', maxLines: 2),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(
              backgroundColor: widget.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _guardando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Crear reserva',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {
    int maxLines = 1, TextInputType? tipo,
  }) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, keyboardType: tipo,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _readonlyField(IconData icon, String valor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardando = true);
    try {
      final fechaHora = DateTime(
          _fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('reservas')
          .add({
            'nombre_cliente':    nombre,
            'telefono_cliente':  _telefonoCtrl.text.trim(),
            'email_cliente':     _emailCtrl.text.trim(),
            'personas':          _comensales,
            'fecha_hora':        Timestamp.fromDate(fechaHora),
            'estado':            'PENDIENTE',
            'origen':            'manual',
            'comentarios':       _notasCtrl.text.trim(),
            'fecha_creacion':    FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

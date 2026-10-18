import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/modelos/config_reservas.dart';
import '../../../models/negocio_publico_model.dart' show NegocioPublico;
import '../../../core/widgets/flux_toast.dart';

// ─── Paleta ──────────────────────────────────────────────────────────────────
const _kAccent   = Color(0xFF00BFA5);
const _kRosa     = Color(0xFFE91E63);
const _kOro      = Color(0xFFFFB830);
const _kTexto    = Color(0xFF1E293B);
const _kMuted    = Color(0xFF64748B);
const _kHint     = Color(0xFF94A3B8);
const _kFondo    = Color(0xFFF4F6FB);
const _kBorde    = Color(0xFFDDE3ED);
const _kCard     = Colors.white;

// ─── Punto de entrada ─────────────────────────────────────────────────────────
Future<void> mostrarBookingSheet(
  BuildContext context,
  NegocioPublico negocio, {
  String? servicioId,
  String? servicioNombre,
  double? precio,
  int? duracion,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: MediaQuery.of(ctx).viewInsets,
      child: FractionallySizedBox(
        heightFactor: 0.90,
        child: _BookingSheet(
          negocio: negocio,
          servicioId: servicioId,
          servicioNombre: servicioNombre,
          precio: precio,
          duracion: duracion,
        ),
      ),
    ),
  );
}

// ─── Popup principal ──────────────────────────────────────────────────────────
class _BookingSheet extends StatefulWidget {
  final NegocioPublico negocio;
  final String? servicioId;
  final String? servicioNombre;
  final double? precio;
  final int? duracion;
  const _BookingSheet({
    required this.negocio,
    this.servicioId,
    this.servicioNombre,
    this.precio,
    this.duracion,
  });

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  // ── Estado ────────────────────────────────────────────────────────
  ConfigReservas? _config;
  bool _cargando = true;
  bool _guardando = false;
  int _paso = 0; // 0=fecha, 1=hora, 2=datos, 3=confirmado

  DateTime? _fecha;
  String?   _hora;
  late DateTime _mesVista; // mes que se muestra en el calendario
  String?   _empleadoId;
  String?   _empleadoNombre;
  int       _numPersonas = 2;
  String?   _zona;

  final _nombreCtrl  = TextEditingController();
  final _telCtrl     = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _notasCtrl   = TextEditingController();
  final _alergenosCtrl = TextEditingController();
  bool _tieneAlergenos = false;

  final Map<String, TextEditingController> _camposExtraCtrl = {};

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mesVista = DateTime(hoy.year, hoy.month);
    _cargarConfig();
    _rellenarUsuario();
  }

  Future<void> _cargarConfig() async {
    final empresaId = widget.negocio.empresaIdVinculada;
    ConfigReservas config;
    if (empresaId.isNotEmpty) {
      config = await ConfigReservas.cargar(empresaId);
    } else {
      // Sin empresa vinculada: inferir tipo por categoría
      config = ConfigReservas(
        tipo: _tipoDeCategoria(widget.negocio.categoria.name),
      );
    }
    // Crear controllers para campos extra
    for (final c in config.camposExtra) {
      _camposExtraCtrl[c.id] = TextEditingController();
    }
    if (mounted) setState(() { _config = config; _cargando = false; });
  }

  void _rellenarUsuario() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.displayName != null) _nombreCtrl.text = user.displayName!;
    if (user.email != null) _emailCtrl.text = user.email!;
    if (user.phoneNumber != null) _telCtrl.text = user.phoneNumber!;
  }

  TipoReserva _tipoDeCategoria(String cat) => switch (cat.toLowerCase()) {
    'restaurantes' || 'bares' || 'hoteles' => TipoReserva.mesa,
    'gimnasios'                             => TipoReserva.espacio,
    _                                       => TipoReserva.servicio,
  };

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _telCtrl, _emailCtrl, _notasCtrl, _alergenosCtrl]) c.dispose();
    for (final c in _camposExtraCtrl.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(color: _kCard,
            child: Center(child: Padding(padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(color: _kAccent)))),
      );
    }

    if (_paso == 3) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(color: _kCard,
            child: SingleChildScrollView(child: _buildConfirmado())),
      );
    }

    // Scaffold garantiza que body + bottomBar se distribuyen correctamente
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Scaffold(
        backgroundColor: _kCard,
        // Header fijo
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildHandle(),
            _buildCabecera(),
            _buildProgreso(),
            const Divider(height: 1, color: _kBorde),
          ]),
        ),
        // Contenido scrollable
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: _buildPaso(),
        ),
        // Botones fijos abajo
        bottomNavigationBar: _buildBotones(),
      ),
    );
  }

  // ── Handle + cabecera ─────────────────────────────────────────────
  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      width: 32, height: 3,
      decoration: BoxDecoration(color: _kBorde, borderRadius: BorderRadius.circular(2)),
    ),
  );

  Widget _buildCabecera() {
    final tipo = _config?.tipo ?? TipoReserva.generico;
    final titulo = switch (tipo) {
      TipoReserva.servicio  => widget.servicioNombre != null ? widget.servicioNombre! : 'Reservar cita',
      TipoReserva.mesa      => 'Reservar mesa',
      TipoReserva.espacio   => 'Reservar espacio',
      TipoReserva.generico  => 'Hacer una reserva',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(children: [
        Icon(_iconTipo(_config?.tipo), color: _kAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(color: _kTexto, fontSize: 14, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(widget.negocio.nombre, style: const TextStyle(color: _kMuted, fontSize: 11)),
        ])),
        IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.close_rounded, color: _kHint, size: 20),
            onPressed: () => Navigator.pop(context)),
      ]),
    );
  }

  IconData _iconTipo(TipoReserva? t) => switch (t) {
    TipoReserva.mesa    => Icons.restaurant_rounded,
    TipoReserva.espacio => Icons.meeting_room_rounded,
    _                   => Icons.calendar_today_rounded,
  };

  Widget _buildProgreso() {
    const labels = ['Fecha', 'Hora', 'Datos'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: List.generate(3, (i) {
        final done = _paso > i;
        final active = _paso == i;
        return Expanded(child: Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: done ? _kAccent : active ? _kAccent.withValues(alpha: 0.15) : _kFondo,
              shape: BoxShape.circle,
              border: Border.all(color: done || active ? _kAccent : _kBorde),
            ),
            child: Center(child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : Text('${i+1}', style: TextStyle(
                    color: active ? _kAccent : _kHint,
                    fontSize: 11, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(labels[i], style: TextStyle(
              color: active ? _kAccent : done ? _kTexto : _kHint,
              fontSize: 11, fontWeight: active || done ? FontWeight.w600 : FontWeight.w400))),
          if (i < 2) Expanded(child: Container(height: 1, color: _kBorde)),
        ]));
      })),
    );
  }

  // ── Paso activo ───────────────────────────────────────────────────
  Widget _buildPaso() {
    return switch (_paso) {
      0 => _buildPasoFecha(),
      1 => _buildPasoHora(),
      2 => _buildPasoDatos(),
      _ => const SizedBox.shrink(),
    };
  }

  // ── PASO 0: Calendario mensual ────────────────────────────────────
  Widget _buildPasoFecha() {
    final hoy       = DateTime.now();
    final minFecha  = hoy.add(Duration(hours: _config?.antelacionMinHoras ?? 2));
    final maxFecha  = hoy.add(Duration(days: _config?.antelacionMaxDias ?? 30));
    final diasDisp  = _config?.diasDisponibles ?? [1, 2, 3, 4, 5];

    final primerDia = DateTime(_mesVista.year, _mesVista.month, 1);
    final diasEnMes = DateTime(_mesVista.year, _mesVista.month + 1, 0).day;
    // weekday del día 1: 1=Lun…7=Dom → offset para alinear al lunes
    final offset    = (primerDia.weekday - 1) % 7;
    final totalCeldas = offset + diasEnMes;

    final meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio',
                   'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

    final puedeRetroceder = _mesVista.isAfter(DateTime(hoy.year, hoy.month));
    final puedeAvanzar    = DateTime(_mesVista.year, _mesVista.month + 1)
        .isBefore(DateTime(maxFecha.year, maxFecha.month + 1));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Cabecera mes ──────────────────────────────────────────────
      Row(children: [
        _navBtn(Icons.chevron_left_rounded, puedeRetroceder
            ? () => setState(() => _mesVista = DateTime(_mesVista.year, _mesVista.month - 1))
            : null),
        Expanded(child: Center(child: Text(
          '${meses[_mesVista.month - 1]} ${_mesVista.year}',
          style: const TextStyle(color: _kTexto, fontSize: 14, fontWeight: FontWeight.w700),
        ))),
        _navBtn(Icons.chevron_right_rounded, puedeAvanzar
            ? () => setState(() => _mesVista = DateTime(_mesVista.year, _mesVista.month + 1))
            : null),
      ]),
      const SizedBox(height: 8),

      // ── Cabecera días ─────────────────────────────────────────────
      Row(children: ['L','M','X','J','V','S','D'].map((d) => Expanded(
        child: Center(child: Text(d,
            style: const TextStyle(color: _kMuted, fontSize: 10, fontWeight: FontWeight.w600))),
      )).toList()),
      const SizedBox(height: 4),

      // ── Grid de días — Table con celdas compactas ─────────────────
      () {
        const cellH = 32.0;
        const circleSize = 28.0;
        final numFilas = ((offset + diasEnMes) / 7).ceil();
        final rows = <TableRow>[];

        for (int fila = 0; fila < numFilas; fila++) {
          final cells = <Widget>[];
          for (int col = 0; col < 7; col++) {
            final i = fila * 7 + col;
            final dayNum = i - offset + 1;

            if (dayNum < 1 || dayNum > diasEnMes) {
              cells.add(const SizedBox(height: cellH));
              continue;
            }

            final dia = DateTime(_mesVista.year, _mesVista.month, dayNum);
            final esHoy   = dia.year == hoy.year && dia.month == hoy.month && dia.day == hoy.day;
            final esSelec = _fecha != null && _fecha!.year == dia.year &&
                            _fecha!.month == dia.month && _fecha!.day == dia.day;
            final disponible =
                !dia.isBefore(DateTime(minFecha.year, minFecha.month, minFecha.day)) &&
                !dia.isAfter(maxFecha) &&
                diasDisp.contains(dia.weekday);

            Color bg; Color txt;
            if (esSelec)         { bg = _kAccent; txt = Colors.white; }
            else if (esHoy)      { bg = _kAccent.withValues(alpha: 0.12); txt = _kAccent; }
            else if (!disponible){ bg = Colors.transparent; txt = _kBorde; }
            else                 { bg = Colors.transparent; txt = _kTexto; }

            cells.add(GestureDetector(
              onTap: disponible ? () => setState(() { _fecha = dia; _hora = null; }) : null,
              child: SizedBox(height: cellH,
                child: Center(child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: circleSize, height: circleSize,
                  decoration: BoxDecoration(
                    color: bg, shape: BoxShape.circle,
                    border: esHoy && !esSelec ? Border.all(color: _kAccent, width: 1.5) : null,
                  ),
                  child: Center(child: Text('$dayNum', style: TextStyle(
                    color: txt, fontSize: 12,
                    fontWeight: esSelec || esHoy ? FontWeight.w700 : FontWeight.w400))),
                )),
              ),
            ));
          }
          rows.add(TableRow(children: cells));
        }
        return Table(defaultColumnWidth: const FlexColumnWidth(), children: rows);
      }(),

      // ── Fecha seleccionada ────────────────────────────────────────
      if (_fecha != null) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: _kAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              '${_diaSemanaLargo(_fecha!.weekday)}, ${_fecha!.day} de ${_mesLargo(_fecha!.month)} de ${_fecha!.year}',
              style: const TextStyle(color: _kAccent, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    ]);
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: onTap != null ? _kFondo : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: onTap != null ? _kBorde : Colors.transparent),
      ),
      child: Icon(icon, size: 20, color: onTap != null ? _kTexto : _kBorde),
    ),
  );

  static String _diaSemanaLargo(int d) =>
      const ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][d];

  static String _mesLargo(int m) =>
      const ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
              'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'][m];

  // ── PASO 1: Hora ──────────────────────────────────────────────────
  Widget _buildPasoHora() {
    final horas = _config?.horasDisponibles(_fecha!) ?? [];
    if (horas.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32),
          child: Text('No hay horas disponibles este día', style: TextStyle(color: _kMuted))));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('¿A qué hora?',
          style: TextStyle(color: _kTexto, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      // Grid 4 columnas — compacto y predecible
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.4,
        ),
        itemCount: horas.length,
        itemBuilder: (_, i) {
          final h = horas[i];
          final sel = _hora == h;
          return GestureDetector(
            onTap: () => setState(() => _hora = h),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: sel ? _kAccent : _kCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? _kAccent : _kBorde),
              ),
              child: Center(child: Text(h, style: TextStyle(
                color: sel ? Colors.white : _kTexto,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13))),
            ),
          );
        },
      ),

      // Elegir profesional (solo tipo servicio)
      if ((_config?.tipo == TipoReserva.servicio) &&
          (_config?.permitirElegirProfesional ?? true) &&
          widget.negocio.empresaIdVinculada.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Text('Profesional (opcional)',
            style: TextStyle(color: _kTexto, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _buildSelectorProfesional(),
      ],
    ]);
  }

  Widget _buildSelectorProfesional() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(widget.negocio.empresaIdVinculada)
          .collection('empleados')
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          // Opción "Sin preferencia"
          _profTile(null, null, 'Sin preferencia', 'Cualquier profesional disponible'),
          ...docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final nombre = d['nombre'] as String? ?? d['nombre_completo'] as String? ?? '';
            final cargo  = d['cargo'] as String? ?? d['puesto'] as String? ?? '';
            final avatar = d['avatar_url'] as String? ?? d['foto_url'] as String?;
            return _profTile(doc.id, avatar, nombre, cargo);
          }),
        ]);
      },
    );
  }

  Widget _profTile(String? id, String? avatar, String nombre, String sub) {
    final sel = _empleadoId == id;
    return GestureDetector(
      onTap: () => setState(() {
        _empleadoId = id;
        _empleadoNombre = id == null ? null : nombre;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _kAccent.withValues(alpha: 0.08) : _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _kAccent : _kBorde),
        ),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.12), shape: BoxShape.circle,
              image: avatar != null ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover) : null,
            ),
            child: avatar == null
                ? Center(child: Icon(id == null ? Icons.shuffle_rounded : Icons.person_outline_rounded,
                    color: _kAccent, size: 16)) : null),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: TextStyle(color: _kTexto, fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            if (sub.isNotEmpty)
              Text(sub, style: const TextStyle(color: _kMuted, fontSize: 11)),
          ])),
          if (sel) const Icon(Icons.check_circle_rounded, color: _kAccent, size: 18),
        ]),
      ),
    );
  }

  // ── PASO 2: Datos cliente ─────────────────────────────────────────
  Widget _buildPasoDatos() {
    final tipo = _config?.tipo ?? TipoReserva.generico;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tus datos de contacto',
          style: TextStyle(color: _kTexto, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      _campo(_nombreCtrl, 'Nombre *', 'Ej: María García', Icons.person_outline_rounded),
      const SizedBox(height: 10),
      _campo(_telCtrl, 'Teléfono *', '+34 612 345 678', Icons.phone_outlined,
          tipo: TextInputType.phone),
      const SizedBox(height: 10),
      _campo(_emailCtrl, 'Email (opcional)', 'tu@email.com', Icons.email_outlined,
          tipo: TextInputType.emailAddress),
      const SizedBox(height: 16),

      // ── Campos específicos por tipo ─────────────────────────────
      if (tipo == TipoReserva.mesa) ...[
        const Divider(color: _kBorde, height: 24),
        const Text('Detalles de la reserva',
            style: TextStyle(color: _kTexto, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        _buildSelectorPersonas(),
        const SizedBox(height: 14),
        _buildSelectorZona(),
        const SizedBox(height: 14),
        _buildAlergenosToggle(),
      ],

      if (tipo == TipoReserva.espacio) ...[
        const Divider(color: _kBorde, height: 24),
        _buildSelectorPersonas(),
      ],

      // ── Campos extra configurados por el negocio ────────────────
      if (_config != null && _config!.camposExtra.isNotEmpty) ...[
        const Divider(color: _kBorde, height: 24),
        ..._config!.camposExtra.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _campoExtra(c),
        )),
      ],

      // ── Notas generales ─────────────────────────────────────────
      const Divider(color: _kBorde, height: 24),
      TextField(
        controller: _notasCtrl, maxLines: 3,
        style: const TextStyle(color: _kTexto, fontSize: 13),
        decoration: _dec('Notas adicionales (opcional)', null),
      ),
    ]);
  }

  Widget _buildSelectorPersonas() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Número de personas', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        _btnPersona(Icons.remove_rounded, () { if (_numPersonas > 1) setState(() => _numPersonas--); }),
        Expanded(child: Center(child: Text('$_numPersonas persona${_numPersonas == 1 ? '' : 's'}',
            style: const TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.w700)))),
        _btnPersona(Icons.add_rounded, () => setState(() => _numPersonas++)),
      ]),
    ],
  );

  Widget _btnPersona(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 40, height: 40,
      decoration: BoxDecoration(border: Border.all(color: _kBorde), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: _kAccent, size: 20)),
  );

  Widget _buildSelectorZona() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Zona', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        _zonaChip('salon', 'Salón', Icons.chair_alt_rounded),
        const SizedBox(width: 8),
        _zonaChip('terraza', 'Terraza', Icons.deck_rounded),
        const SizedBox(width: 8),
        _zonaChip('barra', 'Barra', Icons.local_bar_rounded),
      ]),
    ],
  );

  Widget _zonaChip(String id, String label, IconData icon) {
    final sel = _zona == id;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _zona = sel ? null : id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _kAccent : _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _kAccent : _kBorde),
        ),
        child: Column(children: [
          Icon(icon, color: sel ? Colors.white : _kMuted, size: 18),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: sel ? Colors.white : _kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    ));
  }

  Widget _buildAlergenosToggle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('¿Algún alérgeno?', style: TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w600)),
          Text('Haremos todo lo posible para atenderte', style: TextStyle(color: _kMuted, fontSize: 11)),
        ])),
        Switch(value: _tieneAlergenos, onChanged: (v) => setState(() => _tieneAlergenos = v),
            activeColor: _kAccent, activeTrackColor: _kAccent.withValues(alpha: 0.25),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
      if (_tieneAlergenos) ...[
        const SizedBox(height: 8),
        TextField(controller: _alergenosCtrl, maxLines: 2,
            style: const TextStyle(color: _kTexto, fontSize: 13),
            decoration: _dec('Describe los alérgenos', Icons.warning_amber_rounded)),
      ],
    ],
  );

  Widget _campoExtra(CampoReservaExtra campo) {
    final ctrl = _camposExtraCtrl[campo.id] ?? TextEditingController();
    if (campo.tipo == 'checkbox') {
      return Row(children: [
        Expanded(child: Text(campo.label, style: const TextStyle(color: _kTexto, fontSize: 13))),
        Switch(value: ctrl.text == 'si',
            onChanged: (v) => setState(() => ctrl.text = v ? 'si' : 'no'),
            activeColor: _kAccent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]);
    }
    if (campo.tipo == 'selector' && campo.opciones != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(campo.label, style: const TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: campo.opciones!.map((o) {
          final sel = ctrl.text == o;
          return GestureDetector(
            onTap: () => setState(() => ctrl.text = o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? _kAccent : _kCard, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? _kAccent : _kBorde)),
              child: Text(o, style: TextStyle(color: sel ? Colors.white : _kTexto, fontSize: 12, fontWeight: FontWeight.w500))),
          );
        }).toList()),
      ]);
    }
    return _campo(ctrl, campo.label + (campo.obligatorio ? ' *' : ''),
        campo.placeholder ?? '', null,
        tipo: campo.tipo == 'numero' ? TextInputType.number : TextInputType.text);
  }

  // ── Pantalla de confirmado ────────────────────────────────────────
  Widget _buildConfirmado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildHandle(),
        const SizedBox(height: 24),
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: _kAccent, size: 38)),
        const SizedBox(height: 16),
        const Text('¡Reserva enviada!',
            style: TextStyle(color: _kTexto, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Te contactaremos en breve para confirmar tu reserva en ${widget.negocio.nombre}.',
            textAlign: TextAlign.center, style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _kFondo, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorde)),
          child: Column(children: [
            _resumenItem(Icons.calendar_today_rounded, 'Fecha',
                '${_diaSemana(_fecha!.weekday)}, ${_fecha!.day} de ${_mes(_fecha!.month)}'),
            _resumenItem(Icons.access_time_rounded, 'Hora', _hora ?? ''),
            if (_empleadoNombre != null)
              _resumenItem(Icons.person_outline_rounded, 'Profesional', _empleadoNombre!),
            if (widget.servicioNombre != null)
              _resumenItem(Icons.content_cut_rounded, 'Servicio', widget.servicioNombre!),
            if (_config?.tipo == TipoReserva.mesa)
              _resumenItem(Icons.people_outline_rounded, 'Personas', '$_numPersonas persona${_numPersonas == 1 ? '' : 's'}'),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
      ]),
    );
  }

  Widget _resumenItem(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 15, color: _kAccent),
      const SizedBox(width: 10),
      Text('$label: ', style: const TextStyle(color: _kMuted, fontSize: 12)),
      Expanded(child: Text(value, style: const TextStyle(color: _kTexto, fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );

  // ── Botones navegación ────────────────────────────────────────────
  Widget _buildBotones() {
    final puedeAvanzar = switch (_paso) {
      0 => _fecha != null,
      1 => _hora != null,
      2 => _nombreCtrl.text.trim().isNotEmpty && _telCtrl.text.trim().isNotEmpty,
      _ => false,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(children: [
        if (_paso > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _paso--),
              style: OutlinedButton.styleFrom(foregroundColor: _kMuted,
                  side: const BorderSide(color: _kBorde),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Atrás', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        if (_paso > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: puedeAvanzar ? () {
              if (_paso < 2) {
                setState(() => _paso++);
              } else {
                _guardarReserva();
              }
            } : null,
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent, foregroundColor: Colors.white,
              disabledBackgroundColor: _kAccent.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _guardando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_paso < 2 ? 'Continuar' : 'Confirmar reserva',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  // ── Guardar en Firestore ──────────────────────────────────────────
  Future<void> _guardarReserva() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final tipo = _config?.tipo ?? TipoReserva.generico;
      final uid  = FirebaseAuth.instance.currentUser?.uid;
      final empresaId = widget.negocio.empresaIdVinculada;
      final fechaHora = DateTime(_fecha!.year, _fecha!.month, _fecha!.day,
          int.parse(_hora!.split(':')[0]), int.parse(_hora!.split(':')[1]));

      final camposExtra = <String, dynamic>{};
      for (final c in (_config?.camposExtra ?? [])) {
        final v = _camposExtraCtrl[c.id]?.text.trim() ?? '';
        if (v.isNotEmpty) camposExtra[c.id] = v;
      }

      final reserva = ReservaUnificada(
        id: '',
        tipo: tipo,
        fechaHora: fechaHora,
        fecha: '${_fecha!.year}-${_fecha!.month.toString().padLeft(2,'0')}-${_fecha!.day.toString().padLeft(2,'0')}',
        hora: _hora!,
        fechaCreacion: DateTime.now(),
        negocioId: widget.negocio.id,
        negocioNombre: widget.negocio.nombre,
        empresaId: empresaId,
        clienteUid: uid,
        clienteNombre: _nombreCtrl.text.trim(),
        clienteEmail: _emailCtrl.text.trim(),
        clienteTelefono: _telCtrl.text.trim(),
        // Servicio
        servicioId: widget.servicioId,
        servicioNombre: widget.servicioNombre,
        empleadoId: _empleadoId,
        empleadoNombre: _empleadoNombre,
        duracionMinutos: widget.duracion,
        precio: widget.precio,
        // Mesa
        numPersonas: tipo == TipoReserva.mesa || tipo == TipoReserva.espacio ? _numPersonas : null,
        zona: _zona,
        alergenos: _tieneAlergenos ? 'si' : null,
        alergenosDetalle: _tieneAlergenos ? _alergenosCtrl.text.trim() : null,
        camposExtra: camposExtra,
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        estado: (_config?.requiereConfirmacion ?? false) ? 'pendiente' : 'confirmada',
      );

      final col = empresaId.isNotEmpty
          ? FirebaseFirestore.instance.collection('empresas').doc(empresaId).collection('reservas')
          : FirebaseFirestore.instance.collection('negocios_publicos').doc(widget.negocio.id).collection('reservas');

      await col.add(reserva.toMap());

      // Notificación al negocio
      if (empresaId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('notificaciones').doc(empresaId).collection('items')
            .add({
          'titulo': '📅 Nueva reserva',
          'cuerpo': '${_nombreCtrl.text.trim()} · ${_hora!} · ${_fecha!.day}/${_fecha!.month}',
          'tipo': 'reservaNueva',
          'modulo_destino': 'reservas',
          'leida': false,
          'fecha': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) setState(() { _guardando = false; _paso = 3; });
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        FluxToast.error(context, 'Error al reservar: $e');
      }
    }
  }

  // ── Helpers UI ────────────────────────────────────────────────────
  Widget _campo(TextEditingController ctrl, String label, String hint, IconData? icon,
      {TextInputType tipo = TextInputType.text}) =>
      TextField(
        controller: ctrl, keyboardType: tipo,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: _kTexto, fontSize: 13),
        decoration: _dec(hint, icon).copyWith(
            labelText: label,
            labelStyle: const TextStyle(color: _kMuted, fontSize: 12)),
      );

  InputDecoration _dec(String hint, IconData? icon) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: _kHint, fontSize: 13),
    filled: true, fillColor: _kFondo,
    prefixIcon: icon != null ? Icon(icon, color: _kAccent, size: 18) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _kBorde, width: 0.5)),
    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _kAccent, width: 1)),
    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide.none),
  );

  static String _diaSemana(int d) =>
      const ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][d];

  static String _mes(int m) =>
      const ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
               'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][m];
}

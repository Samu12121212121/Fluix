import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../domain/modelos/reserva.dart';
import '../../../services/contenido_web_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB RESERVAS WEB — gestión de reservas recibidas desde el formulario web
// Colección: empresas/{id}/reservas
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
  String _filtro = 'todas'; // 'todas' | 'PENDIENTE' | 'CONFIRMADA' | 'CANCELADA'

  Color get _color => widget.color ?? const Color(0xFF3B82F6);

  static const _filtros = [
    ('todas',       'Todas'),
    ('PENDIENTE',   'Pendientes'),
    ('CONFIRMADA',  'Confirmadas'),
    ('CANCELADA',   'Canceladas'),
  ];

  Stream<List<Reserva>> get _stream => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('reservas')
      .orderBy('fecha_hora', descending: false)
      .limit(300)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => Reserva.fromMap(d.data(), d.id))
          .toList());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reserva>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: Colors.red, fontSize: 13)));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final todas = snap.data ?? [];
        final pendientes  = todas.where((r) => _estadoNorm(r.estado) == 'PENDIENTE').length;
        final hoy = _reservasHoy(todas);
        final confirmadas = todas.where((r) => _estadoNorm(r.estado) == 'CONFIRMADA').length;

        final filtradas = _filtro == 'todas'
            ? todas
            : todas.where((r) => _estadoNorm(r.estado) == _filtro).toList();

        return Column(children: [
          _buildHeader(todas.length, pendientes, hoy, confirmadas),
          _buildFiltros(),
          const Divider(height: 1),
          Expanded(
            child: filtradas.isEmpty
                ? _buildVacio()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: filtradas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildReservaCard(filtradas[i]),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _buildHeader(int total, int pendientes, int hoy, int confirmadas) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reservas', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: _color)),
            const Text('Gestiona las reservas recibidas desde tu web',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormNuevaReserva(context),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Nueva'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _color, foregroundColor: Colors.white,
              elevation: 0, minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _kpiCard(Icons.pending_actions_rounded, const Color(0xFFF59E0B),
              '$pendientes', 'Pendientes'),
          const SizedBox(width: 10),
          _kpiCard(Icons.today_rounded, _color, '$hoy', 'Hoy'),
          const SizedBox(width: 10),
          _kpiCard(Icons.check_circle_rounded, const Color(0xFF10B981),
              '$confirmadas', 'Confirmadas'),
        ]),
      ]),
    );
  }

  Widget _kpiCard(IconData icon, Color iconColor, String valor, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8EDF2)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(valor, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
            Text(label, style: const TextStyle(
                fontSize: 11, color: Color(0xFF64748B))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _filtros.map((f) {
          final sel = _filtro == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _filtro = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? _color : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(f.$2, style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? Colors.white : const Color(0xFF64748B))),
            ),
          );
        }).toList()),
      ),
    );
  }

  Widget _buildReservaCard(Reserva r) {
    final estadoNorm = _estadoNorm(r.estado);
    final (estColor, estBg, estLabel) = _estadoStyle(estadoNorm);
    final esPasada = r.fechaHora.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: esPasada
                ? const Color(0xFFE2E8F0)
                : estadoNorm == 'PENDIENTE'
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: InkWell(
        onTap: () => _mostrarDetalle(context, r),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar inicial
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(
                  r.clienteNombre.isNotEmpty
                      ? r.clienteNombre[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: _color))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.clienteNombre.isNotEmpty ? r.clienteNombre : 'Sin nombre',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.access_time_rounded, size: 12,
                        color: esPasada
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(_formatFechaHora(r.fechaHora),
                        style: TextStyle(fontSize: 12,
                            color: esPasada
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF334155))),
                    const SizedBox(width: 10),
                    Icon(Icons.people_rounded, size: 12,
                        color: const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text('${r.comensales} pers.',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                  if (r.servicio.isNotEmpty && r.servicio != 'almuerzo') ...[
                    const SizedBox(height: 2),
                    Text(r.servicio,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ]),
              ),
              // Badge estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: estBg, borderRadius: BorderRadius.circular(20)),
                child: Text(estLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: estColor)),
              ),
            ]),
            // Acciones rápidas si está pendiente
            if (estadoNorm == 'PENDIENTE' && !esPasada) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(children: [
                if (r.clienteTelefono.isNotEmpty)
                  Text(r.clienteTelefono,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _cancelar(r),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFFFCDD2)),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _confirmar(r),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('Confirmar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildVacio() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.event_seat_rounded, size: 56, color: _color.withValues(alpha: 0.2)),
      const SizedBox(height: 16),
      Text(_filtro == 'todas' ? 'No hay reservas' : 'No hay reservas $_filtro'.toLowerCase(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: Color(0xFF334155))),
      const SizedBox(height: 6),
      const Text('Las reservas recibidas desde tu web aparecerán aquí',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          textAlign: TextAlign.center),
    ]));
  }

  // ── Acciones ────────────────────────────────────────────────────────────────

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
          reserva: r, color: _color,
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

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _estadoNorm(String? estado) =>
      (estado ?? 'PENDIENTE').toUpperCase();

  static (Color, Color, String) _estadoStyle(String estado) {
    switch (estado) {
      case 'CONFIRMADA':
        return (const Color(0xFF15803D), const Color(0xFFDCFCE7), 'Confirmada');
      case 'CANCELADA':
        return (const Color(0xFFB91C1C), const Color(0xFFFEE2E2), 'Cancelada');
      case 'COMPLETADA':
        return (const Color(0xFF475569), const Color(0xFFF1F5F9), 'Completada');
      default:
        return (const Color(0xFFB45309), const Color(0xFFFEF3C7), 'Pendiente');
    }
  }

  static int _reservasHoy(List<Reserva> todas) {
    final hoy = DateTime.now();
    return todas.where((r) =>
      r.fechaHora.year == hoy.year &&
      r.fechaHora.month == hoy.month &&
      r.fechaHora.day == hoy.day).length;
  }

  static String _formatFechaHora(DateTime dt) {
    final ahora = DateTime.now();
    final esHoy    = dt.year == ahora.year && dt.month == ahora.month && dt.day == ahora.day;
    final esManana = dt.year == ahora.year && dt.month == ahora.month && dt.day == ahora.day + 1;
    final hora = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    if (esHoy)    return 'Hoy $hora';
    if (esManana) return 'Mañana $hora';
    return '${dt.day} ${meses[dt.month - 1]} · $hora';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detalle de reserva (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _DetalleReservaSheet extends StatelessWidget {
  final Reserva reserva;
  final Color color;
  final VoidCallback onConfirmar;
  final VoidCallback onCancelar;

  const _DetalleReservaSheet({
    required this.reserva,
    required this.color,
    required this.onConfirmar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    final estado = (r.estado ?? 'PENDIENTE').toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(r.clienteNombre.isNotEmpty ? r.clienteNombre : 'Reserva',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text(_TabReservasWebState._formatFechaHora(r.fechaHora),
            style: TextStyle(fontSize: 14, color: color)),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
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
              r.alergenosDetalle ?? 'Sí, ver detalle', color: const Color(0xFFF59E0B)),
        if ((r.comentarios ?? '').isNotEmpty)
          _fila(Icons.notes_rounded, 'Notas', r.comentarios!),
        const SizedBox(height: 16),
        if (estado == 'PENDIENTE')
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(context); onCancelar(); },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancelar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); onConfirmar(); },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Confirmar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _fila(IconData icon, String label, String valor, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16,
            color: color ?? const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(
            fontSize: 13, color: Color(0xFF64748B))),
        Expanded(child: Text(valor, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: color ?? const Color(0xFF0F172A)))),
      ]),
    );
  }
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

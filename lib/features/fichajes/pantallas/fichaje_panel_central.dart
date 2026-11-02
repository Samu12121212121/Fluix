import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import 'fichajes_colors.dart';

// ── FichajeHeroCard ────────────────────────────────────────────────────────────

class FichajeHeroCard extends StatelessWidget {
  final Fichaje? misFichaje;
  final DateTime ahora;
  final bool fichando;
  final String empresaId;
  final FichajeService svc;
  final Future<void> Function(BuildContext) onFichar;
  final Future<void> Function(BuildContext) onFicharPausa;
  final VoidCallback onOlvisteFichar;

  const FichajeHeroCard({
    super.key,
    required this.misFichaje,
    required this.ahora,
    required this.fichando,
    required this.empresaId,
    required this.svc,
    required this.onFichar,
    required this.onFicharPausa,
    required this.onOlvisteFichar,
  });

  @override
  Widget build(BuildContext context) {
    final entrada = misFichaje?.entrada?.toDate().toLocal();
    final entradaStr =
        entrada != null ? DateFormat('HH:mm').format(entrada) : null;
    final trabajando = misFichaje != null && misFichaje!.salida == null;
    final enPausa = trabajando &&
        misFichaje!.pausas.isNotEmpty &&
        misFichaje!.pausas.any((p) => p.fin == null);
    final pausaDesdeStr = enPausa
        ? DateFormat('HH:mm').format(misFichaje!.pausas
            .lastWhere((p) => p.fin == null)
            .inicio
            .toDate()
            .toLocal())
        : null;

    return fichajeCard(
      child: Column(children: [
        Text(
          _fmtFecha(ahora),
          style: const TextStyle(fontSize: 14, color: kFSub),
        ),
        const SizedBox(height: 12),
        Text(
          DateFormat('HH:mm:ss').format(ahora),
          style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: kFText,
              letterSpacing: -2),
        ),
        const SizedBox(height: 10),
        if (entradaStr != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: enPausa
                    ? kFOrange.withValues(alpha: 0.12)
                    : kFGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: enPausa ? kFOrange : kFGreen,
                      shape: BoxShape.circle,
                    )),
                const SizedBox(width: 6),
                Text(
                  enPausa
                      ? 'En pausa desde ${pausaDesdeStr ?? entradaStr}'
                      : 'Trabajando desde $entradaStr',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enPausa ? kFOrange : kFGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          )
        else
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Sin fichar hoy',
                style: TextStyle(fontSize: 13, color: kFSub)),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: fichando ? null : () => onFichar(context),
            icon: fichando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(
                    misFichaje == null
                        ? Icons.login_rounded
                        : trabajando
                            ? Icons.logout_rounded
                            : Icons.login_rounded,
                    size: 20),
            label: Text(
              misFichaje == null
                  ? 'Fichar entrada'
                  : trabajando
                      ? 'Fichar salida'
                      : 'Fichar entrada',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  misFichaje != null && trabajando
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (trabajando || enPausa) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed:
                  fichando ? null : () => onFicharPausa(context),
              icon: Icon(
                  enPausa
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 18),
              label: Text(
                enPausa ? 'Reanudar jornada' : 'Iniciar pausa',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kFOrange,
                side: const BorderSide(color: kFOrange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton(
          onPressed: onOlvisteFichar,
          child: const Text('¿Olvidaste fichar entrada?',
              style: TextStyle(
                  fontSize: 12,
                  color: kFGreen,
                  decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 8),
        _JornadaTimeline(misFichaje: misFichaje, ahora: ahora,
            onVerJornada: onOlvisteFichar),
      ]),
    );
  }

  static String _fmtFecha(DateTime d) {
    const dias = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${dias[d.weekday - 1]}, ${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }
}

// ── JornadaTimeline (privado) ──────────────────────────────────────────────────

class _JornadaTimeline extends StatelessWidget {
  final Fichaje? misFichaje;
  final DateTime ahora;
  final VoidCallback onVerJornada;

  const _JornadaTimeline({
    required this.misFichaje,
    required this.ahora,
    required this.onVerJornada,
  });

  @override
  Widget build(BuildContext context) {
    final entrada = misFichaje?.entrada?.toDate().toLocal();
    final salida = misFichaje?.salida?.toDate().toLocal();
    final pausas = misFichaje?.pausas ?? [];
    final ultimaPausa = pausas.isNotEmpty ? pausas.last : null;
    final pausaStr = ultimaPausa != null
        ? DateFormat('HH:mm')
            .format(ultimaPausa.inicio.toDate().toLocal())
        : null;
    final reanuStr = ultimaPausa?.fin != null
        ? DateFormat('HH:mm')
            .format(ultimaPausa!.fin!.toDate().toLocal())
        : null;
    final pausaDurStr = ultimaPausa?.duracion != null
        ? '${ultimaPausa!.duracion!.inMinutes}m'
        : null;
    final salidaEstimada = entrada != null
        ? DateFormat('HH:mm')
            .format(entrada.add(const Duration(hours: 8)))
        : null;

    return Column(children: [
      const Divider(height: 24, color: kFBorder),
      Row(children: [
        const Text('Mi jornada de hoy',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kFText)),
        const Spacer(),
        TextButton(
          onPressed: onVerJornada,
          style: TextButton.styleFrom(
              foregroundColor: kFSub,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 12)),
          child: const Row(children: [
            Text('Ver jornada completa'),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward, size: 14),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _item(Icons.login_rounded, kFGreen,
              entrada != null ? DateFormat('HH:mm').format(entrada) : '--:--',
              'Entrada', true),
          _line(kFGreen),
          _item(Icons.coffee_rounded, kFOrange, pausaStr ?? '--:--',
              pausaDurStr != null ? 'Descanso\n$pausaDurStr' : 'Descanso',
              pausaStr != null),
          _line(reanuStr != null ? kFGreen : kFBorder),
          _item(Icons.play_arrow_rounded, kFGreen, reanuStr ?? '--:--',
              'Reanudación', reanuStr != null),
          _line(salida != null ? kFGreen : kFBorder),
          _item(
              Icons.logout_rounded,
              kFGray,
              salida != null
                  ? DateFormat('HH:mm').format(salida)
                  : salidaEstimada ?? '—',
              salida != null ? 'Salida' : 'Salida prev.',
              false),
        ]),
      ),
      const SizedBox(height: 8),
    ]);
  }

  static Widget _item(IconData icon, Color color, String time, String label,
      bool done) {
    return Column(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: done
              ? color.withValues(alpha: 0.12)
              : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
          border: Border.all(
              color: done ? color : kFBorder, width: 1.5),
        ),
        child: Icon(icon, size: 18, color: done ? color : kFGray),
      ),
      const SizedBox(height: 6),
      Text(time,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: kFText)),
      const SizedBox(height: 2),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 10, color: kFSub, height: 1.3)),
      if (done) ...[
        const SizedBox(height: 2),
        const Icon(Icons.check, size: 14, color: kFGreen),
      ],
    ]);
  }

  static Widget _line(Color color) => Container(
        width: 48,
        height: 2,
        margin: const EdgeInsets.only(bottom: 30),
        color: color,
      );
}

// ── FichajesTableWidget ────────────────────────────────────────────────────────

class FichajesTableWidget extends StatelessWidget {
  final List<Fichaje> fichajes;
  final bool esAdmin;
  final void Function(Fichaje) onVerDetalle;
  final void Function(String uid, String nombre)? onConfigJornada;

  const FichajesTableWidget({
    super.key,
    required this.fichajes,
    required this.esAdmin,
    required this.onVerDetalle,
    this.onConfigJornada,
  });

  static const _colHead = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: kFSub,
      letterSpacing: 0.5);

  @override
  Widget build(BuildContext context) {
    final hoy = DateFormat("d 'de' MMMM", 'es_ES').format(DateTime.now());
    return fichajeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Fichajes recientes',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kFText)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                border: Border.all(color: kFBorder),
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: kFSub),
              const SizedBox(width: 6),
              Text('Hoy, $hoy',
                  style: const TextStyle(fontSize: 12, color: kFSub)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16, color: kFSub),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.more_vert, size: 18, color: kFSub),
        ]),
        const SizedBox(height: 16),
        if (fichajes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
                child: Text('Sin fichajes hoy',
                    style: TextStyle(color: kFSub, fontSize: 13))),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 810,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: kFBorder))),
                  child: const Row(children: [
                    SizedBox(
                        width: 200,
                        child: Text('EMPLEADO', style: _colHead)),
                    SizedBox(
                        width: 80,
                        child: Text('ENTRADA', style: _colHead)),
                    SizedBox(
                        width: 80,
                        child: Text('SALIDA', style: _colHead)),
                    SizedBox(
                        width: 80,
                        child: Text('HORAS', style: _colHead)),
                    SizedBox(
                        width: 110,
                        child: Text('ESTADO', style: _colHead)),
                    SizedBox(
                        width: 130,
                        child: Text('UBICACIÓN', style: _colHead)),
                    SizedBox(
                        width: 100,
                        child: Text('DISPOSITIVO', style: _colHead)),
                    SizedBox(width: 30),
                  ]),
                ),
                ...fichajes.take(10).map((f) => _row(context, f)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _row(BuildContext context, Fichaje f) {
    final fmtH = DateFormat('HH:mm');
    final entH =
        f.entrada != null ? fmtH.format(f.entrada!.toDate().toLocal()) : '—';
    final salH =
        f.salida != null ? fmtH.format(f.salida!.toDate().toLocal()) : '—';
    final neto = f.tiempoNeto;
    final netoTxt = neto != null
        ? '${neto.inHours}h ${(neto.inMinutes % 60).toString().padLeft(2, '0')}m'
        : '—';
    final esTrabajando = f.salida == null;
    final enPausa = esTrabajando && f.pausas.any((p) => p.fin == null);
    final (badgeLabel, badgeColor) = enPausa
        ? ('En pausa', kFOrange)
        : esTrabajando
            ? ('Trabajando', kFGreen)
            : ('Finalizada', kFGray);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(children: [
        SizedBox(
          width: 200,
          child: Row(children: [
            CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE5E7EB),
                child: Text(
                    f.empleadoNombre.isNotEmpty
                        ? f.empleadoNombre[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: kFText))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.empleadoNombre,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kFText),
                        overflow: TextOverflow.ellipsis),
                    const Text('Empleado',
                        style: TextStyle(fontSize: 10, color: kFSub)),
                  ]),
            ),
          ]),
        ),
        SizedBox(
            width: 80,
            child: Text(entH,
                style: const TextStyle(fontSize: 12, color: kFText))),
        SizedBox(
            width: 80,
            child: Text(salH,
                style: const TextStyle(fontSize: 12, color: kFSub))),
        SizedBox(
            width: 80,
            child: Text(netoTxt,
                style: const TextStyle(fontSize: 12, color: kFText))),
        SizedBox(
          width: 110,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badgeLabel,
                style: TextStyle(
                    fontSize: 11,
                    color: badgeColor,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(
            width: 130,
            child: Text('—',
                style: TextStyle(fontSize: 12, color: kFSub))),
        SizedBox(width: 100, child: _dispWidget(f.dispositivoId)),
        if (esAdmin)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 16, color: kFSub),
            constraints: const BoxConstraints(minWidth: 30),
            padding: EdgeInsets.zero,
            onSelected: (v) {
              if (v == 'detalle') onVerDetalle(f);
              if (v == 'jornada') {
                onConfigJornada?.call(f.empleadoId, f.empleadoNombre);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'detalle',
                  child: ListTile(
                      leading: Icon(Icons.edit_note_rounded, size: 18),
                      title: Text('Ver / corregir',
                          style: TextStyle(fontSize: 13)),
                      dense: true,
                      contentPadding: EdgeInsets.zero)),
              PopupMenuItem(
                  value: 'jornada',
                  child: ListTile(
                      leading: Icon(Icons.schedule_outlined,
                          size: 18, color: kFGreen),
                      title: Text('Editar jornada',
                          style:
                              TextStyle(fontSize: 13, color: kFGreen)),
                      dense: true,
                      contentPadding: EdgeInsets.zero)),
            ],
          )
        else
          InkWell(
            onTap: () => onVerDetalle(f),
            child: const SizedBox(
                width: 30,
                child: Icon(Icons.more_horiz, size: 16, color: kFSub)),
          ),
      ]),
    );
  }

  static Widget _dispWidget(String dispositivoId) {
    final isKiosk = dispositivoId.startsWith('kiosk_') ||
        dispositivoId.startsWith('tablet_');
    final label = isKiosk
        ? 'Kiosk'
        : dispositivoId == 'app' ||
                dispositivoId.startsWith('personal_')
            ? 'App'
            : dispositivoId;
    return Row(children: [
      Icon(
          isKiosk
              ? Icons.tablet_android_outlined
              : Icons.phone_android_outlined,
          size: 14,
          color: kFSub),
      const SizedBox(width: 4),
      Flexible(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: kFSub),
              overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// ── FichajesMobileList ─────────────────────────────────────────────────────────

class FichajesMobileList extends StatelessWidget {
  final List<Fichaje> fichajes;
  final bool esAdmin;
  final void Function(Fichaje) onVerDetalle;
  final void Function(String uid, String nombre)? onConfigJornada;

  const FichajesMobileList({
    super.key,
    required this.fichajes,
    required this.esAdmin,
    required this.onVerDetalle,
    this.onConfigJornada,
  });

  @override
  Widget build(BuildContext context) {
    final hoy = DateFormat("d 'de' MMMM", 'es_ES').format(DateTime.now());
    return fichajeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Fichajes hoy — $hoy',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kFText)),
          const Spacer(),
          Text('${fichajes.length} registros',
              style: const TextStyle(fontSize: 11, color: kFSub)),
        ]),
        const SizedBox(height: 10),
        if (fichajes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
                child: Text('Sin fichajes hoy',
                    style: TextStyle(color: kFSub, fontSize: 13))),
          )
        else
          ...fichajes.take(12).map((f) => _card(context, f)),
      ]),
    );
  }

  Widget _card(BuildContext context, Fichaje f) {
    final fmtH = DateFormat('HH:mm');
    final entH =
        f.entrada != null ? fmtH.format(f.entrada!.toDate().toLocal()) : '—';
    final salH =
        f.salida != null ? fmtH.format(f.salida!.toDate().toLocal()) : '—';
    final neto = f.tiempoNeto;
    final netoTxt = neto != null
        ? '${neto.inHours}h ${(neto.inMinutes % 60).toString().padLeft(2, '0')}m'
        : '—';
    final enPausa =
        f.salida == null && f.pausas.any((p) => p.fin == null);
    final trabajando = f.salida == null;
    final (label, color) = enPausa
        ? ('En pausa', kFOrange)
        : trabajando
            ? ('Trabajando', kFGreen)
            : ('Finalizada', kFGray);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE5E7EB),
          child: Text(
              f.empleadoNombre.isNotEmpty
                  ? f.empleadoNombre[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kFText)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.empleadoNombre,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kFText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  _tag(Icons.login_rounded, entH, kFGreen),
                  _tag(Icons.logout_rounded, salH, kFGray),
                  _tag(Icons.timer_outlined, netoTxt, kFSub),
                ]),
              ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ),
        if (esAdmin)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                size: 18, color: kFSub),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            onSelected: (v) {
              if (v == 'detalle') onVerDetalle(f);
              if (v == 'jornada') {
                onConfigJornada?.call(f.empleadoId, f.empleadoNombre);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'detalle',
                  child: ListTile(
                      leading: Icon(Icons.edit_note_rounded, size: 18),
                      title: Text('Ver / corregir fichaje',
                          style: TextStyle(fontSize: 13)),
                      dense: true,
                      contentPadding: EdgeInsets.zero)),
              PopupMenuItem(
                  value: 'jornada',
                  child: ListTile(
                      leading: Icon(Icons.schedule_outlined,
                          size: 18, color: kFGreen),
                      title: Text('Editar jornada laboral',
                          style:
                              TextStyle(fontSize: 13, color: kFGreen)),
                      dense: true,
                      contentPadding: EdgeInsets.zero)),
            ],
          )
        else
          IconButton(
            onPressed: () => onVerDetalle(f),
            icon: const Icon(Icons.chevron_right_rounded,
                size: 18, color: kFSub),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ]),
    );
  }

  static Widget _tag(IconData icon, String text, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(text,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500)),
      ]);
}

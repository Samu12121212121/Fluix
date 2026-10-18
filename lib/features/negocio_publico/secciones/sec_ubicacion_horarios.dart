import 'package:flutter/material.dart';
import '../negocio_theme.dart';
import '../../../models/negocio_publico_model.dart';

Widget _card({required bool d, required IconData icon, required Color c, required String title, String? sub, required Widget child}) {
  return Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kCard(d), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorde(d), width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: c, size: 15)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: kTexto(d), fontWeight: FontWeight.bold, fontSize: 13)),
          if (sub != null) Text(sub, style: TextStyle(color: kMuted(d), fontSize: 10)),
        ])),
      ]),
      Divider(color: kBorde(d), height: 18),
      child,
    ]),
  );
}

Widget _lbl(bool d, String t) => Padding(padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: TextStyle(color: kAccent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3)));

Widget _field(bool d, TextEditingController c, String hint, {int? maxL, TextInputType? type}) => TextField(
  controller: c, maxLines: maxL, keyboardType: type,
  style: TextStyle(color: kTexto(d), fontSize: 13), decoration: kDec(d, hint),
);

Widget _toggle(bool d, String lbl, bool val, Function(bool) fn) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(children: [
    Expanded(child: Text(lbl, style: TextStyle(color: kTexto(d), fontSize: 13))),
    Switch(value: val, onChanged: fn, activeColor: kAccent, activeTrackColor: kAccent.withValues(alpha: 0.25), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
  ]),
);

// ════════════════════════════════════════════════════════════════════════════
// UBICACIÓN
// ════════════════════════════════════════════════════════════════════════════
Widget buildSeccionUbicacion(BuildContext ctx, {
  required bool dark,
  required TextEditingController calleCtrl,
  required TextEditingController numeroCtrl,
  required TextEditingController cpCtrl,
  required TextEditingController localidadCtrl,
  required TextEditingController provinciaCtrl,
  required TextEditingController indicacionesCtrl,
  required TextEditingController zonaServicioCtrl,
  required double? latitud,
  required double? longitud,
  required double radioAtencionKm,
  required bool mostrarDireccion,
  required void Function(double?) onLatChanged,
  required void Function(double?) onLngChanged,
  required void Function(double) onRadioChanged,
  required void Function(bool) onMostrarDireccionChanged,
}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _card(d: dark, icon: Icons.location_on_outlined, c: const Color(0xFFFF9800), title: 'Dirección Completa', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'CALLE'), _field(dark, calleCtrl, 'Ej: Calle Mayor'),
        ])),
        const SizedBox(width: 10),
        Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'NÚM.'), _field(dark, numeroCtrl, '1', type: TextInputType.number),
        ])),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'C.P.'), _field(dark, cpCtrl, '19001', type: TextInputType.number),
        ])),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'LOCALIDAD'), _field(dark, localidadCtrl, 'Guadalajara'),
        ])),
      ]),
      const SizedBox(height: 10),
      _lbl(dark, 'PROVINCIA'), _field(dark, provinciaCtrl, 'Guadalajara'),
    ])),

    _card(d: dark, icon: Icons.my_location_rounded, c: const Color(0xFFFF9800), title: 'Coordenadas GPS', sub: 'Para mostrar tu ubicación exacta en el mapa', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'LATITUD'),
          TextFormField(
            initialValue: latitud?.toString() ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: TextStyle(color: kTexto(dark), fontSize: 13),
            decoration: kDec(dark, 'Ej: 40.634'),
            onChanged: (v) => onLatChanged(double.tryParse(v)),
          ),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(dark, 'LONGITUD'),
          TextFormField(
            initialValue: longitud?.toString() ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: TextStyle(color: kTexto(dark), fontSize: 13),
            decoration: kDec(dark, 'Ej: -3.166'),
            onChanged: (v) => onLngChanged(double.tryParse(v)),
          ),
        ])),
      ]),
      const SizedBox(height: 10),
      if (latitud != null && longitud != null)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFF9800).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFFFF9800), size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text('GPS: ${latitud.toStringAsFixed(4)}, ${longitud.toStringAsFixed(4)}', style: TextStyle(color: kTexto(dark), fontSize: 11))),
          ]),
        ),
    ])),

    _card(d: dark, icon: Icons.explore_outlined, c: kAccent, title: 'Zona de Servicio', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(dark, 'INDICACIONES PARA LLEGAR'),
      _field(dark, indicacionesCtrl, 'Ej: Frente al Ayuntamiento, entrada por la calle lateral...', maxL: 4),
      const SizedBox(height: 10),
      _lbl(dark, 'ZONA DE SERVICIO'),
      _field(dark, zonaServicioCtrl, 'Ej: Guadalajara capital y alrededores'),
      const SizedBox(height: 12),
      _lbl(dark, 'RADIO DE ATENCIÓN (km)'),
      Row(children: [
        Expanded(child: Slider(
          value: radioAtencionKm.clamp(1, 200), min: 1, max: 200, divisions: 39,
          activeColor: kAccent, inactiveColor: kBorde(dark),
          onChanged: onRadioChanged,
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
          child: Text('${radioAtencionKm.toInt()} km', style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      _toggle(dark, 'Mostrar dirección en ficha pública', mostrarDireccion, onMostrarDireccionChanged),
    ])),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// HORARIOS
// ════════════════════════════════════════════════════════════════════════════
const _kDias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

Widget buildSeccionHorarios(BuildContext ctx, {
  required bool dark,
  required Map<int, HorarioDia> horarios,
  required bool turnosPartidos,
  required bool atencionConCita,
  required bool atencionSinCita,
  required TextEditingController zonaHorariaCtrl,
  required void Function(Map<int, HorarioDia>) onHorariosChanged,
  required void Function(bool) onTurnosPartidosChanged,
  required void Function(bool) onAtencionConCitaChanged,
  required void Function(bool) onAtencionSinCitaChanged,
  required void Function(String, {bool error}) snack,
}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _card(d: dark, icon: Icons.schedule_outlined, c: const Color(0xFF9B59B6), title: 'Horario Semanal', sub: 'Los clientes ven estos horarios en tu perfil', child: Column(children: [
      _toggle(dark, 'Turnos partidos (mañana y tarde)', turnosPartidos, onTurnosPartidosChanged),
      const SizedBox(height: 8),
      ...List.generate(7, (i) => _DiaRow(
        dark: dark, dia: i, h: horarios[i] ?? HorarioDia(abierto: false),
        turnosPartidos: turnosPartidos, ctx: ctx,
        onChanged: (h) { final m = {...horarios}; m[i] = h; onHorariosChanged(m); },
      )),
    ])),
    _card(d: dark, icon: Icons.event_available_rounded, c: const Color(0xFF9B59B6), title: 'Modalidades de Atención', child: Column(children: [
      _toggle(dark, 'Atención con cita previa', atencionConCita, onAtencionConCitaChanged),
      _toggle(dark, 'Atención sin cita (walk-in)', atencionSinCita, onAtencionSinCitaChanged),
      const SizedBox(height: 8),
      _lbl(dark, 'ZONA HORARIA'),
      _field(dark, zonaHorariaCtrl, 'Europe/Madrid'),
    ])),
    _card(d: dark, icon: Icons.block_outlined, c: kRojo, title: 'Cierre Temporal', sub: 'Avisa a tus clientes cuando estés cerrado', child: Column(children: [
      Container(
        padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: kMuted(dark), size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text('Activa "Cierre temporal" para mostrar un aviso hasta la fecha que elijas.', style: TextStyle(color: kMuted(dark), fontSize: 11, height: 1.4))),
        ]),
      ),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () async {
          final picked = await showDatePicker(context: ctx,
            initialDate: DateTime.now().add(const Duration(days: 7)),
            firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (picked != null) snack('Cierre temporal hasta ${picked.day}/${picked.month}/${picked.year}');
        },
        icon: const Icon(Icons.lock_outline_rounded, color: kRojo, size: 15),
        label: const Text('Configurar cierre temporal', style: TextStyle(color: kRojo, fontSize: 12)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: kRojo.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
      )),
    ])),
  ]);
}

class _DiaRow extends StatelessWidget {
  final bool dark; final int dia; final HorarioDia h; final bool turnosPartidos;
  final BuildContext ctx; final void Function(HorarioDia) onChanged;
  const _DiaRow({required this.dark, required this.dia, required this.h, required this.turnosPartidos, required this.ctx, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 7), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: kCard2(dark), borderRadius: BorderRadius.circular(9)),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 76, child: Text(_kDias[dia], style: TextStyle(color: h.abierto ? kTexto(dark) : kMuted(dark), fontSize: 12, fontWeight: FontWeight.w500))),
          Switch(value: h.abierto, activeColor: kAccent, activeTrackColor: kAccent.withValues(alpha: 0.25), inactiveTrackColor: kBorde(dark),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => onChanged(HorarioDia(abierto: v, horaApertura: h.horaApertura ?? '09:00', horaCierre: h.horaCierre ?? '20:00', horaAperturaTarde: h.horaAperturaTarde, horaCierreTarde: h.horaCierreTarde))),
          if (h.abierto) ...[
            Expanded(child: _HoraBtn(hora: h.horaApertura ?? '09:00', dark: dark, ctx: ctx, onPick: (t) => onChanged(HorarioDia(abierto: true, horaApertura: t, horaCierre: h.horaCierre, horaAperturaTarde: h.horaAperturaTarde, horaCierreTarde: h.horaCierreTarde)))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('–', style: TextStyle(color: kMuted(dark)))),
            Expanded(child: _HoraBtn(hora: h.horaCierre ?? '20:00', dark: dark, ctx: ctx, onPick: (t) => onChanged(HorarioDia(abierto: true, horaApertura: h.horaApertura, horaCierre: t, horaAperturaTarde: h.horaAperturaTarde, horaCierreTarde: h.horaCierreTarde)))),
          ] else
            Padding(padding: const EdgeInsets.only(left: 4), child: Text('Cerrado', style: TextStyle(color: kMuted(dark), fontSize: 11))),
        ]),
        if (h.abierto && turnosPartidos) Padding(padding: const EdgeInsets.only(top: 5), child: Row(children: [
          SizedBox(width: 76, child: Text('  Tarde', style: TextStyle(color: kMuted(dark), fontSize: 10))),
          Expanded(child: _HoraBtn(hora: h.horaAperturaTarde ?? '16:00', dark: dark, ctx: ctx, onPick: (t) => onChanged(HorarioDia(abierto: true, horaApertura: h.horaApertura, horaCierre: h.horaCierre, horaAperturaTarde: t, horaCierreTarde: h.horaCierreTarde)))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('–', style: TextStyle(color: kMuted(dark)))),
          Expanded(child: _HoraBtn(hora: h.horaCierreTarde ?? '20:00', dark: dark, ctx: ctx, onPick: (t) => onChanged(HorarioDia(abierto: true, horaApertura: h.horaApertura, horaCierre: h.horaCierre, horaAperturaTarde: h.horaAperturaTarde, horaCierreTarde: t)))),
        ])),
      ]),
    ));
  }
}

class _HoraBtn extends StatelessWidget {
  final String hora; final bool dark; final BuildContext ctx; final void Function(String) onPick;
  const _HoraBtn({required this.hora, required this.dark, required this.ctx, required this.onPick});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final parts = hora.split(':');
      final t = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
        builder: (c2, child) => Theme(data: dark ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: kAccent)) : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: kAccent)), child: child!),
      );
      if (t != null) onPick('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: kCard(dark), borderRadius: BorderRadius.circular(7), border: Border.all(color: kBorde(dark))),
      child: Text(hora, textAlign: TextAlign.center, style: TextStyle(color: kTexto(dark), fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );
}

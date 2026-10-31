import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';

class DialogFichajesEmpleado extends StatelessWidget {
  final String empresaId, empleadoId, empleadoNombre;
  final DateTime mes;
  final FichajeService svc;
  final VoidCallback onCorregido;

  const DialogFichajesEmpleado({
    super.key,
    required this.empresaId,
    required this.empleadoId,
    required this.empleadoNombre,
    required this.mes,
    required this.svc,
    required this.onCorregido,
  });

  @override
  Widget build(BuildContext context) {
    final mesTxt = DateFormat('MMMM yyyy', 'es_ES').format(mes);
    return AlertDialog(
      title: Text(empleadoNombre),
      content: SizedBox(
        width: double.maxFinite,
        height: 340,
        child: FutureBuilder<List<Fichaje>>(
          future: svc.fichajesMes(empresaId: empresaId, mes: mes),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final todos = (snap.data ?? [])
                .where((f) => f.empleadoId == empleadoId)
                .toList();
            final Map<String, Fichaje> efectivos = {};
            for (final f in todos) {
              final actual = efectivos[f.fecha];
              if (actual == null) {
                efectivos[f.fecha] = f;
              } else if (f.esCorreccion && !actual.esCorreccion) {
                efectivos[f.fecha] = f;
              }
            }
            final lista = efectivos.values.toList()
              ..sort((a, b) => a.fecha.compareTo(b.fecha));
            if (lista.isEmpty) {
              return Center(
                child: Text('Sin fichajes en ${mesTxt.toLowerCase()}',
                    style: const TextStyle(color: Colors.grey)),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (c, i) {
                final f = lista[i];
                final fmtH = DateFormat('HH:mm');
                final fmtD = DateFormat('EEE d MMM', 'es_ES');
                final fecha = DateTime.parse(f.fecha);
                final entH =
                    f.entrada != null ? fmtH.format(f.entrada!.toDate().toLocal()) : '—';
                final salH =
                    f.salida != null ? fmtH.format(f.salida!.toDate().toLocal()) : '—';
                final neto = f.tiempoNeto;
                final nTxt = neto != null
                    ? '${neto.inHours}h ${(neto.inMinutes % 60).toString().padLeft(2, '0')}m'
                    : '—';
                return ListTile(
                  dense: true,
                  title: Text(fmtD.format(fecha),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('$entH → $salH  ·  $nTxt',
                      style: const TextStyle(fontSize: 12)),
                  leading: f.esCorreccion
                      ? const Icon(Icons.edit_note, color: Colors.orange, size: 18)
                      : const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () async {
                      await showDialog(
                        context: c,
                        builder: (_) => DialogEditarFichaje(
                          empresaId: empresaId,
                          fichaje: f,
                          svc: svc,
                        ),
                      );
                      if (c.mounted) Navigator.pop(c);
                      onCorregido();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class DialogEditarFichaje extends StatefulWidget {
  final String empresaId;
  final Fichaje fichaje;
  final FichajeService svc;

  const DialogEditarFichaje({
    super.key,
    required this.empresaId,
    required this.fichaje,
    required this.svc,
  });

  @override
  State<DialogEditarFichaje> createState() => _DialogEditarFichajeState();
}

class _DialogEditarFichajeState extends State<DialogEditarFichaje> {
  late TimeOfDay _entrada, _salida;
  final _motivoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.fichaje.entrada?.toDate().toLocal() ?? DateTime.now();
    final s = widget.fichaje.salida?.toDate().toLocal() ?? DateTime.now();
    _entrada = TimeOfDay(hour: e.hour, minute: e.minute);
    _salida = TimeOfDay(hour: s.hour, minute: s.minute);
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool esEntrada) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: esEntrada ? _entrada : _salida,
    );
    if (picked != null) {
      setState(() => esEntrada ? _entrada = picked : _salida = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmtD = DateFormat("EEEE d 'de' MMMM", 'es_ES');
    final fecha = DateTime.parse(widget.fichaje.fecha);
    return AlertDialog(
      title: Text('Corregir fichaje — ${fmtD.format(fecha)}',
          style: const TextStyle(fontSize: 15)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.fichaje.empleadoNombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _TimeButton(label: 'Entrada', time: _entrada,
              onTap: () => _pickTime(true))),
          const SizedBox(width: 12),
          Expanded(child: _TimeButton(label: 'Salida', time: _salida,
              onTap: () => _pickTime(false))),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo de corrección *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.note_alt_outlined),
          ),
          maxLines: 2,
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar corrección'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      FluxToast.error(context, 'El motivo es obligatorio');
      return;
    }
    setState(() => _guardando = true);
    try {
      final fechaBase = DateTime.parse(widget.fichaje.fecha);
      await widget.svc.corregirFichaje(
        empresaId: widget.empresaId,
        fichajeOriginalId: widget.fichaje.id,
        motivo: motivo,
        corregidoPorUid: FirebaseAuth.instance.currentUser?.uid ?? 'desconocido',
        nuevaEntrada: Timestamp.fromDate(DateTime(fechaBase.year, fechaBase.month,
            fechaBase.day, _entrada.hour, _entrada.minute)),
        nuevaSalida: Timestamp.fromDate(DateTime(fechaBase.year, fechaBase.month,
            fechaBase.day, _salida.hour, _salida.minute)),
        nuevasPausas: widget.fichaje.pausas,
      );
      if (mounted) {
        Navigator.pop(context);
        FluxToast.exito(context, 'Corrección guardada');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        FluxToast.error(context, 'Error: $e');
      }
    }
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('$hh:$mm',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

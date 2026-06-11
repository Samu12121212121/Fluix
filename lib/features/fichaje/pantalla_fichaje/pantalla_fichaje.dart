import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../fichajes/modelos/fichaje.dart';
import '../../fichajes/servicios/fichaje_service.dart';
import 'mis_horas_mes_section.dart';

const Color _azulPrimario = Color(0xFF1565C0);

class PantallaFichaje extends StatefulWidget {
  final bool embedido;
  const PantallaFichaje({super.key, this.embedido = false});

  @override
  State<PantallaFichaje> createState() => _PantallaFichajeState();
}

class _PantallaFichajeState extends State<PantallaFichaje> {
  final _svc = FichajeService();

  String? _uid;
  String? _empresaId;
  String? _nombreEmpleado;

  Timer? _timer;
  DateTime _ahora = DateTime.now();

  bool _cargandoEntrada = false;
  bool _cargandoSalida = false;
  bool _cargandoPausa = false;

  @override
  void initState() {
    super.initState();
    _cargarSesion();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarSesion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    setState(() {
      _uid = user.uid;
      _empresaId = doc.data()?['empresa_id'] as String?;
      _nombreEmpleado =
          (doc.data()?['nombre'] as String?) ?? user.displayName ?? '';
    });
  }

  Future<void> _ficharEntrada() async {
    final empresaId = _empresaId;
    final uid = _uid;
    if (empresaId == null || uid == null) return;

    setState(() => _cargandoEntrada = true);
    try {
      await _svc.ficharEntrada(
        empresaId: empresaId,
        empleadoId: uid,
        empleadoNombre: _nombreEmpleado ?? '',
        dispositivoId: 'personal_$uid',
      );
      if (!mounted) return;
      final hora = DateFormat('HH:mm').format(DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.login_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Text('Entrada registrada a las $hora'),
        ]),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al fichar entrada: $e'),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _cargandoEntrada = false);
    }
  }

  Future<void> _ficharSalida() async {
    final empresaId = _empresaId;
    final uid = _uid;
    if (empresaId == null || uid == null) return;

    setState(() => _cargandoSalida = true);
    try {
      await _svc.ficharSalida(
        empresaId: empresaId,
        empleadoId: uid,
      );
      if (!mounted) return;
      final hora = DateFormat('HH:mm').format(DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.logout_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Text('Salida registrada a las $hora'),
        ]),
        backgroundColor: _azulPrimario,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al fichar salida: $e'),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _cargandoSalida = false);
    }
  }

  Future<void> _ficharPausa(bool esInicio) async {
    final empresaId = _empresaId;
    final uid = _uid;
    if (empresaId == null || uid == null) return;

    setState(() => _cargandoPausa = true);
    try {
      if (esInicio) {
        await _svc.iniciarPausa(empresaId: empresaId, empleadoId: uid);
      } else {
        await _svc.finalizarPausa(empresaId: empresaId, empleadoId: uid);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            esInicio ? 'Pausa iniciada' : 'Vuelta de pausa registrada'),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red[700],
      ));
    } finally {
      if (mounted) setState(() => _cargandoPausa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empresaId = _empresaId ?? '';
    final uid = _uid ?? '';
    final listo = empresaId.isNotEmpty && uid.isNotEmpty;

    return Scaffold(
      appBar: widget.embedido
          ? null
          : AppBar(
              title: const Row(children: [
                Icon(Icons.access_time_filled_rounded, size: 22),
                SizedBox(width: 8),
                Text('Control Horario',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
              backgroundColor: _azulPrimario,
              foregroundColor: Colors.white,
            ),
      body: listo
          ? StreamBuilder<Fichaje?>(
              stream: _svc.fichajeHoyStream(empresaId, uid),
              builder: (context, snap) {
                final fichaje = snap.data;
                final estado =
                    fichaje?.estado ?? EstadoFichaje.sinFichar;

                final enPausa = estado == EstadoFichaje.enPausa;
                final trabajando = estado == EstadoFichaje.trabajando;
                final cerrado = estado == EstadoFichaje.cerrado;

                final entradaDeshabilitada = _cargandoEntrada ||
                    _cargandoSalida ||
                    fichaje != null;
                final salidaDeshabilitada = _cargandoEntrada ||
                    _cargandoSalida ||
                    fichaje == null ||
                    cerrado ||
                    enPausa;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderFichaje(ahora: _ahora, fichaje: fichaje),
                      const SizedBox(height: 20),

                      _BotonFichar(
                        label: 'Fichar Entrada',
                        icono: Icons.login_rounded,
                        color: Colors.green[700]!,
                        colorFondo: Colors.green[50]!,
                        deshabilitado: entradaDeshabilitada,
                        cargando: _cargandoEntrada,
                        onTap: _ficharEntrada,
                      ),
                      const SizedBox(height: 8),

                      if (trabajando || enPausa)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AnimatedOpacity(
                            opacity: _cargandoPausa ? 0.4 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: _cargandoPausa
                                  ? null
                                  : () => _ficharPausa(!enPausa),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _cargandoPausa
                                    ? Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              enPausa
                                                  ? Icons.play_arrow_rounded
                                                  : Icons.pause_rounded,
                                              color: Colors.orange[700],
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            enPausa
                                                ? 'Volver de pausa'
                                                : 'Iniciar pausa',
                                            style: TextStyle(
                                              color: Colors.orange[700],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),

                      _BotonFichar(
                        label: 'Fichar Salida',
                        icono: Icons.logout_rounded,
                        color: _azulPrimario,
                        colorFondo: const Color(0xFFE3F0FF),
                        deshabilitado: salidaDeshabilitada,
                        cargando: _cargandoSalida,
                        onTap: _ficharSalida,
                      ),
                      const SizedBox(height: 24),

                      _SeccionFichajesHoy(fichaje: fichaje),
                      const SizedBox(height: 16),

                      MisHorasMesSection(
                        empresaId: empresaId,
                        empleadoId: uid,
                      ),
                    ],
                  ),
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

// ── HEADER ────────────────────────────────────────────────────────────────────

class _HeaderFichaje extends StatelessWidget {
  final DateTime ahora;
  final Fichaje? fichaje;

  const _HeaderFichaje({required this.ahora, this.fichaje});

  @override
  Widget build(BuildContext context) {
    final fechaTxt =
        DateFormat("EEEE, d 'de' MMMM", 'es_ES').format(ahora);
    final horaTxt = DateFormat('HH:mm').format(ahora);
    final fmtH = DateFormat('HH:mm');

    String? estadoTxt;
    IconData? estadoIcono;
    if (fichaje != null) {
      switch (fichaje!.estado) {
        case EstadoFichaje.trabajando:
          final h = fichaje!.entrada != null
              ? fmtH.format(fichaje!.entrada!.toDate().toLocal())
              : '—';
          estadoTxt = 'Entrada a las $h';
          estadoIcono = Icons.login_rounded;
        case EstadoFichaje.enPausa:
          final ultima =
              fichaje!.pausas.isNotEmpty ? fichaje!.pausas.last : null;
          final h =
              ultima != null ? fmtH.format(ultima.inicio.toDate().toLocal()) : '—';
          estadoTxt = 'Pausa desde las $h';
          estadoIcono = Icons.pause_rounded;
        case EstadoFichaje.cerrado:
          final h = fichaje!.salida != null
              ? fmtH.format(fichaje!.salida!.toDate().toLocal())
              : '—';
          estadoTxt = 'Salida a las $h';
          estadoIcono = Icons.logout_rounded;
        default:
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fechaTxt,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            horaTxt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: -2,
            ),
          ),
          if (estadoTxt != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(estadoIcono!, color: Colors.white, size: 13),
                const SizedBox(width: 5),
                Text(estadoTxt,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── BOTÓN FICHAR ──────────────────────────────────────────────────────────────

class _BotonFichar extends StatelessWidget {
  final String label;
  final IconData icono;
  final Color color;
  final Color colorFondo;
  final bool deshabilitado;
  final bool cargando;
  final VoidCallback onTap;

  const _BotonFichar({
    required this.label,
    required this.icono,
    required this.color,
    required this.colorFondo,
    required this.deshabilitado,
    required this.cargando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: deshabilitado ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: deshabilitado ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: cargando
              ? Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: color),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorFondo,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icono, color: color, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: color),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── SECCIÓN FICHAJES DEL DÍA ──────────────────────────────────────────────────

class _SeccionFichajesHoy extends StatelessWidget {
  final Fichaje? fichaje;

  const _SeccionFichajesHoy({required this.fichaje});

  @override
  Widget build(BuildContext context) {
    final fmtH = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Fichajes de hoy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a2e),
            ),
          ),
        ),
        if (fichaje == null)
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 36, horizontal: 24),
              child: Column(
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 52, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No hay fichajes hoy',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Pulsa "Fichar Entrada" para empezar',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            ),
          )
        else
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            child: Column(
              children: [
                if (fichaje!.entrada != null)
                  _FilaEvento(
                    icono: Icons.login_rounded,
                    color: Colors.green[700]!,
                    colorFondo: Colors.green[50]!,
                    titulo: 'Entrada',
                    hora: fmtH.format(fichaje!.entrada!.toDate().toLocal()),
                  ),
                ...fichaje!.pausas.expand((p) => [
                      const Divider(height: 1, indent: 56),
                      _FilaEvento(
                        icono: Icons.pause_rounded,
                        color: Colors.orange[700]!,
                        colorFondo: Colors.orange[50]!,
                        titulo: 'Inicio pausa',
                        hora: fmtH.format(p.inicio.toDate().toLocal()),
                      ),
                      if (p.fin != null) ...[
                        const Divider(height: 1, indent: 56),
                        _FilaEvento(
                          icono: Icons.play_arrow_rounded,
                          color: Colors.orange[700]!,
                          colorFondo: Colors.orange[50]!,
                          titulo: 'Fin pausa',
                          hora: fmtH.format(p.fin!.toDate().toLocal()),
                        ),
                      ],
                    ]),
                if (fichaje!.salida != null) ...[
                  const Divider(height: 1, indent: 56),
                  _FilaEvento(
                    icono: Icons.logout_rounded,
                    color: _azulPrimario,
                    colorFondo: const Color(0xFFE3F0FF),
                    titulo: 'Salida',
                    hora: fmtH.format(fichaje!.salida!.toDate().toLocal()),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _FilaEvento extends StatelessWidget {
  final IconData icono;
  final Color color;
  final Color colorFondo;
  final String titulo;
  final String hora;

  const _FilaEvento({
    required this.icono,
    required this.color,
    required this.colorFondo,
    required this.titulo,
    required this.hora,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: colorFondo,
        child: Icon(icono, color: color, size: 20),
      ),
      title: Text(titulo,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(hora,
          style: const TextStyle(fontSize: 13, color: Colors.grey)),
    );
  }
}

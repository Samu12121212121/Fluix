                    if (duracion == null && salida == null)
                      Text(
import 'dart:async';

                        style: TextStyle(
                          fontSize: 12,
import 'package:flutter/material.dart';
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,

import '../../../domain/modelos/fichaje.dart';
                        ),
                      ),
                    if (tieneGps) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.location_on_rounded,
                          size: 12, color: Colors.grey[400]),
                    ],
                  ],
                ),
                trailing: salida == null
                    ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
  final _svc = FichajeService();

  // Sesión
  String? _uid;
  String? _empresaId;
  String? _nombreEmpleado;
                  ),
  // Reloj en tiempo real
  Timer? _timer;
  DateTime _ahora = DateTime.now();

  // Estado de carga de cada botón
  bool _cargandoEntrada = false;
  bool _cargandoSalida = false;
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
    _cargarSesion();
    // Actualizar hora cada minuto
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
                  ),
                )
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
        );
  // ── Cargar datos del usuario logado ────────────────────────────────────────
  Future<void> _cargarSesion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
                    color: Colors.black.withOpacity(0.05),
    if (!mounted) return;
    setState(() {
      _uid = user.uid;
      _empresaId = doc.data()?['empresa_id'] as String?;
      _nombreEmpleado = (doc.data()?['nombre'] as String?) ?? user.displayName ?? '';
    });
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F0FF),
  // ── GPS opcional, timeout 5 s ──────────────────────────────────────────────
  Future<Position?> _obtenerUbicacion() async {
                  child: const Icon(Icons.access_time_rounded,
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }
                    fontSize: 14,
  // ── Acción de fichaje ──────────────────────────────────────────────────────
  Future<void> _fichar(TipoFichaje tipo) async {
    final empresaId = _empresaId;
    final uid = _uid;
    if (empresaId == null || uid == null) return;

    if (tipo == TipoFichaje.entrada) {
      setState(() => _cargandoEntrada = true);
    } else {
      setState(() => _cargandoSalida = true);
    }

    try {
      final pos = await _obtenerUbicacion();
                        '${duracion.inHours}h ${duracion.inMinutes % 60}min trabajadas',
      if (tipo == TipoFichaje.entrada) {
        await _svc.ficharEntrada(
          empresaId: empresaId,
          empleadoId: uid,
          empleadoNombre: _nombreEmpleado ?? '',
          latitud: pos?.latitude,
          longitud: pos?.longitude,
        );
      } else {
        await _svc.ficharSalida(
          empresaId: empresaId,
          empleadoId: uid,
          empleadoNombre: _nombreEmpleado ?? '',
          latitud: pos?.latitude,
          longitud: pos?.longitude,
        );
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),

      if (!mounted) return;
      final hora = DateFormat('HH:mm').format(DateTime.now());
      final label = tipo == TipoFichaje.entrada ? 'Entrada' : 'Salida';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
          .where('empleado_id', isEqualTo: _uid)
              tipo == TipoFichaje.entrada
                  ? Icons.login_rounded
                  : Icons.logout_rounded,
          .orderBy('entrada', descending: true)
          .snapshots(),
            const SizedBox(width: 8),
            Text('$label registrada a las $hora'),
          ]),
          backgroundColor:
              tipo == TipoFichaje.entrada ? Colors.green[700] : _azulPrimario,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
          return Center(
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al fichar: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cargandoEntrada = false;
          _cargandoSalida = false;
        });
      }
    }
                const SizedBox(height: 8),
                Text(
  // ── BUILD ──────────────────────────────────────────────────────────────────
                  'Sin fichajes hoy',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
    final empresaId = _empresaId ?? '';
    final uid = _uid ?? '';
    final listo = empresaId.isNotEmpty && uid.isNotEmpty;

                ),
              ],
            ),
          );
        }
        return ListView.builder(
        title: const Row(children: [
          Icon(Icons.access_time_filled_rounded, size: 22),
          SizedBox(width: 8),
          Text('Control Horario',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
    required Color colorFondo,
      body: listo
          ? StreamBuilder<RegistroFichaje?>(
              stream: _svc.ultimoFichajeHoy(empresaId, uid),
              builder: (context, snapUltimo) {
                final ultimo = snapUltimo.data;
                final estaEnEntrada = ultimo?.tipo == TipoFichaje.entrada;
                final hayFichajes = ultimo != null;

                final entradaDeshabilitada =
                    _cargandoEntrada || _cargandoSalida || estaEnEntrada;
                final salidaDeshabilitada =
                    _cargandoEntrada ||
                    _cargandoSalida ||
                    !hayFichajes ||
                    ultimo?.tipo == TipoFichaje.salida;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header con gradiente azul
                      _HeaderFichaje(ahora: _ahora, ultimoFichaje: ultimo),
                      const SizedBox(height: 20),
        padding: const EdgeInsets.symmetric(vertical: 20),
                      // Botón Entrada
                      _BotonFichar(
                        label: 'Fichar Entrada',
                        icono: Icons.login_rounded,
                        color: Colors.green[700]!,
                        colorFondo: Colors.green[50]!,
                        deshabilitado: entradaDeshabilitada,
                        cargando: _cargandoEntrada,
                        onTap: () => _fichar(TipoFichaje.entrada),
                      ),
                      const SizedBox(height: 12),

                      // Botón Salida
                      _BotonFichar(
                        label: 'Fichar Salida',
                        icono: Icons.logout_rounded,
                        color: _azulPrimario,
                        colorFondo: const Color(0xFFE3F0FF),
                        deshabilitado: salidaDeshabilitada,
                        cargando: _cargandoSalida,
                        onTap: () => _fichar(TipoFichaje.salida),
                      ),
                      const SizedBox(height: 24),

                      // Fichajes del día
                      _SeccionFichajesHoy(
                        empresaId: empresaId,
                        uid: uid,
                        svc: _svc,
                      ),
                    ],
                  ),
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 10),
            Text(
}
              label,
// ── HEADER GRADIENTE ──────────────────────────────────────────────────────────

class _HeaderFichaje extends StatelessWidget {
  final DateTime ahora;
  final RegistroFichaje? ultimoFichaje;

  const _HeaderFichaje({required this.ahora, this.ultimoFichaje});

  @override
  Widget build(BuildContext context) {
    final fechaTxt =
        DateFormat("EEEE, d 'de' MMMM", 'es_ES').format(ahora);
    final horaTxt = DateFormat('HH:mm').format(ahora);

    String? ultimoTxt;
    if (ultimoFichaje != null) {
      final h = DateFormat('HH:mm').format(ultimoFichaje!.timestamp);
      final tipo =
          ultimoFichaje!.tipo == TipoFichaje.entrada ? 'Entrada' : 'Salida';
      ultimoTxt = 'Último: $tipo a las $h';
    }
            ),
          ],
      decoration: BoxDecoration(
        gradient: const LinearGradient(
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../services/fichaje_service.dart';
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],

      padding: const EdgeInsets.all(24),

  @override
  State<PantallaFichaje> createState() => _PantallaFichajeState();
          Text(fechaTxt,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13)),
  String? _ultimoTipo; // 'entrada' o 'salida'
  DateTime? _ultimaHora;
            horaTxt,
  final _fichajeService = FichajeService();
  bool _cargando = false;
              fontSize: 48,
  DateTime? _ultimaHora;
              letterSpacing: -2,
  }

          if (ultimoTxt != null) ...[
            const SizedBox(height: 10),

              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        .collection('empresas')
                color: Colors.white.withValues(alpha: 0.18),
    _cargarUltimoFichaje();
        .limit(1)
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  ultimoFichaje!.tipo == TipoFichaje.entrada
                      ? Icons.login_rounded
                      : Icons.logout_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(ultimoTxt,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ]),
      setState(() {
        _ultimoTipo = tieneSalida ? 'salida' : 'entrada';
  Future<void> _fichar(String tipo) async {
    setState(() => _cargando = true);
      });
    }
}
        );
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
                color: Colors.black.withValues(alpha: 0.06),
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
                      strokeWidth: 2.5,
                      color: color,
                    ),
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
                        color: color,
                      ),
                    ),
                  ],
                ),
          // Header azul con fecha y estado
          _buildHeaderEstado(),

          // Botones fichar
}

// ── SECCIÓN FICHAJES DEL DÍA ──────────────────────────────────────────────────

class _SeccionFichajesHoy extends StatelessWidget {
  final String empresaId;
  final String uid;
  final FichajeService svc;
          Padding(
  const _SeccionFichajesHoy({
    required this.empresaId,
    required this.uid,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
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
        StreamBuilder<List<RegistroFichaje>>(
          stream: svc.fichajesDelDia(empresaId, uid, DateTime.now()),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child:
                    Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              );
            }

            final lista = snap.data ?? [];

            if (lista.isEmpty) {
              return Card(
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
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Pulsa "Fichar Entrada" para empezar',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lista.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (context, i) {
                  final f = lista[i];
                  final esEntrada = f.tipo == TipoFichaje.entrada;
                  final hora =
                      DateFormat('HH:mm').format(f.timestamp);
          children: [
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: esEntrada
                          ? Colors.green[50]
                          : const Color(0xFFE3F2FD),
                      child: Icon(
                        esEntrada
                            ? Icons.login_rounded
                            : Icons.logout_rounded,
                        color: esEntrada
                            ? Colors.green[700]
                            : const Color(0xFF1565C0),
                        size: 20,
                      ),
                    ),
                    title: Row(children: [
                      Text(
                        esEntrada ? 'Entrada' : 'Salida',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
          // Botones fichar
                      if (f.editadoPorAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Editado',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ]),
                    subtitle: Text(hora,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey)),
                    trailing: f.latitud != null
                        ? Tooltip(
                            message: 'Ubicación registrada',
                            child: Icon(Icons.location_on_rounded,
                                color: Colors.blue[400], size: 18),
                          )
                        : null,
                  );
                },
              ),
            );
          },
        ),
      ],
                Icon(Icons.access_time_outlined,
                    size: 48, color: Colors.grey[300]),
  Widget _buildHeaderEstado() {

    final ahora = DateTime.now();
    final fechaFormateada =
    DateFormat("EEEE, d 'de' MMMM", 'es_ES').format(ahora);
    final horaFormateada = DateFormat('HH:mm').format(ahora);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding:
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
                leading: Container(
                  width: 44,
                  height: 44,
                ),
                title: Text(
                  entrada != null
                      ? 'Entrada ${DateFormat('HH:mm').format(entrada)}'
                      '${salida != null ? '  →  Salida ${DateFormat('HH:mm').format(salida)}' : ''}'
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
          Text(
            fechaFormateada,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
            horaFormateada,
                  children: [
                    if (duracion != null)
              fontSize: 36,
              letterSpacing: 1,
                        style: TextStyle(
          if (_ultimoTipo != null && _ultimaHora != null) ...[
            const SizedBox(height: 8),
                        ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      Text(
                        'En curso...',
                color: Colors.white.withOpacity(0.15),
                          fontSize: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _ultimoTipo == 'entrada'
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Último fichaje: ${_ultimoTipo == 'entrada' ? 'Entrada' : 'Salida'} '
                        'a las ${DateFormat('HH:mm').format(_ultimaHora!)}',
                  ),
                ],
              ),
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Activo',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                    : const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 20),
              ),
            );
          },
        );
      },
    );
  }
}
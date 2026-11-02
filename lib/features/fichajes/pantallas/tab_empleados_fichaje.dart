import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'dialog_alta_empleado.dart';
import 'dialog_configurar_pin.dart';
import 'fichajes_colors.dart';

class TabEmpleadosFichaje extends StatefulWidget {
  final String empresaId;

  const TabEmpleadosFichaje({super.key, required this.empresaId});

  @override
  State<TabEmpleadosFichaje> createState() => _TabEmpleadosFichajeState();
}

class _TabEmpleadosFichajeState extends State<TabEmpleadosFichaje> {
  final _svc = FichajeService();
  String _busq = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _usuariosStream =>
      FirebaseFirestore.instance
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .snapshots();

  Stream<Map<String, EmpleadoFichaje>> get _fichajeMapStream =>
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('empleados_fichaje')
          .snapshots()
          .map((s) =>
              {for (final d in s.docs) d.id: EmpleadoFichaje.fromFirestore(d)});

  void _configurarPIN(
      String uid, String nombre, EmpleadoFichaje? fichaje) {
    showDialog(
      context: context,
      builder: (_) => DialogConfigurarPin(
        uid: uid,
        nombre: nombre,
        pinActual: fichaje?.pin,
        jornadaActual: fichaje?.jornadaDiaria ?? 480,
        horarioEntrada: fichaje?.horarioEntrada,
        horarioSalida: fichaje?.horarioSalida,
        diasLaborables: fichaje?.diasLaborables,
        empresaId: widget.empresaId,
        svc: _svc,
      ),
    );
  }

  Future<void> _toggleActivo(EmpleadoFichaje emp) async {
    try {
      await _svc.actualizarEmpleado(
        empresaId: widget.empresaId,
        uid: emp.uid,
        activo: !emp.activo,
      );
      if (mounted) {
        if (emp.activo) {
          FluxToast.aviso(context, 'Empleado desactivado');
        } else {
          FluxToast.exito(context, 'Empleado activado');
        }
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: kFBorder)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Empleados',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kFText)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => DialogAltaEmpleado(
                  empresaId: widget.empresaId,
                  svc: _svc,
                ),
              ),
              icon: const Icon(Icons.person_add_outlined, size: 14),
              label: const Text('Dar de alta',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kFGreen,
                side: const BorderSide(color: kFGreen),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _busq = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Buscar empleado...',
              hintStyle: const TextStyle(fontSize: 13, color: kFSub),
              prefixIcon: const Icon(Icons.search, size: 18, color: kFSub),
              filled: true,
              fillColor: kFBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kFBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kFBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kFGreen)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              isDense: true,
            ),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<Map<String, EmpleadoFichaje>>(
          stream: _fichajeMapStream,
          builder: (context, fichajeSnap) {
            final fichajeMap = fichajeSnap.data ?? {};
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usuariosStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: kFGreen));
                }
                final docs = (snap.data?.docs ?? [])
                    .where((d) => d.data()['estado'] != 'baja')
                    .where((d) {
                      if (_busq.isEmpty) return true;
                      final n = ((d.data()['nombre'] as String?) ?? '')
                          .toLowerCase();
                      return n.contains(_busq);
                    })
                    .toList()
                  ..sort((a, b) =>
                      ((a.data()['nombre'] as String?) ?? '')
                          .compareTo((b.data()['nombre'] as String?) ?? ''));

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                            _busq.isEmpty
                                ? 'Sin empleados'
                                : 'Sin resultados',
                            style: const TextStyle(
                                color: kFSub, fontSize: 15)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final uid = doc.id;
                    final nombre =
                        (data['nombre'] as String?) ?? 'Sin nombre';
                    final rol = (data['rol'] as String?) ??
                        (data['puesto'] as String?) ??
                        '';
                    final fichaje = fichajeMap[uid];
                    final tienePIN = fichaje != null;
                    final pinActivo = tienePIN && fichaje.activo;
                    final ini = nombre.isNotEmpty
                        ? nombre[0].toUpperCase()
                        : '?';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kFBorder),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(children: [
                        Stack(children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: pinActivo
                                ? kFGreen.withValues(alpha: 0.12)
                                : const Color(0xFFF3F4F6),
                            child: Text(ini,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        pinActivo ? kFGreen : kFSub)),
                          ),
                          if (tienePIN)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                      color: pinActivo ? kFGreen : kFGray,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2))),
                            ),
                        ]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: kFText)),
                              if (rol.isNotEmpty)
                                Text(rol,
                                    style: const TextStyle(
                                        fontSize: 11, color: kFSub)),
                              const SizedBox(height: 4),
                              if (tienePIN)
                                Row(children: [
                                  const Icon(Icons.pin_outlined,
                                      size: 12, color: kFSub),
                                  const SizedBox(width: 3),
                                  Text('PIN: ${fichaje.pin}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: kFSub,
                                          letterSpacing: 1.5)),
                                  const SizedBox(width: 8),
                                  Text(
                                      'Jornada: ${fichaje.jornadaDiaria ~/ 60}h',
                                      style: const TextStyle(
                                          fontSize: 11, color: kFSub)),
                                ])
                              else
                                const Text('Sin PIN configurado',
                                    style: TextStyle(
                                        fontSize: 11, color: kFOrange)),
                            ],
                          ),
                        ),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: pinActivo
                                      ? kFGreen.withValues(alpha: 0.1)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tienePIN
                                      ? (pinActivo ? 'Activo' : 'Inactivo')
                                      : 'Sin PIN',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: pinActivo ? kFGreen : kFGray),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tienePIN) ...[
                                      _empBtn(
                                        icon: pinActivo
                                            ? Icons.person_off_outlined
                                            : Icons.person_add_outlined,
                                        color: pinActivo ? kFOrange : kFGreen,
                                        tooltip: pinActivo
                                            ? 'Desactivar'
                                            : 'Activar',
                                        onTap: () => _toggleActivo(fichaje),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    _empBtn(
                                      icon: tienePIN
                                          ? Icons.edit_outlined
                                          : Icons.add_rounded,
                                      color: kFSub,
                                      tooltip: tienePIN
                                          ? 'Editar'
                                          : 'Configurar PIN',
                                      onTap: () => _configurarPIN(
                                          uid, nombre, fichaje),
                                    ),
                                  ]),
                            ]),
                      ]),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _empBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}

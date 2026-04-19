        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
import 'package:flutter/material.dart';
import '../../../models/vacacion_model.dart';
import '../../../services/vacaciones_service.dart';
import '../../../services/cobertura_equipo_service.dart';
import '../../../core/utils/permisos_service.dart';
import '../widgets/calendario_vacaciones_widget.dart';
import '../widgets/cobertura_semanal_widget.dart';
import 'nueva_solicitud_form.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DE VACACIONES Y AUSENCIAS
// ═══════════════════════════════════════════════════════════════════════════════

class VacacionesScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const VacacionesScreen({super.key, required this.empresaId, this.sesion});

  @override
  State<VacacionesScreen> createState() => _VacacionesScreenState();
}

class _VacacionesScreenState extends State<VacacionesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final VacacionesService _svc = VacacionesService();
  final CoberturaEquipoService _cobSvc = CoberturaEquipoService();
  String? _filtroEmpleadoId;
  TipoAusencia? _filtroTipo;

  bool get _esPropietario =>
      widget.sesion?.esPropietario ??
      (PermisosService().sesion?.esPropietario ?? false);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Cabecera desplazable ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF26A69A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.beach_access, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vacaciones y Ausencias',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
  // PESTAÑA CALENDARIO
                  Tab(icon: Icon(Icons.list_alt), text: 'Solicitudes'),

  Widget _buildCalendario() {
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildCalendario(),
                    _buildListaSolicitudes(),
                  ],
                ),
              ),
            ],
          )),
        ],
    return CalendarioVacacionesWidget(
      empresaId: widget.empresaId,
      sesion: widget.sesion,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PESTAÑA LISTA SOLICITUDES
      ),

                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        // Aplicar filtros
        if (_filtroTipo != null) {
          solicitudes =
    ),
        }
        if (_filtroEmpleadoId != null) {
          solicitudes = solicitudes
              .where((s) => s.empleadoId == _filtroEmpleadoId)
              .toList();
  // ═══════════════════════════════════════════════════════════════════════════

        return Column(
              mainAxisSize: MainAxisSize.min,
            // Filtros
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chipFiltro('Todos', _filtroTipo == null, () {
                      setState(() => _filtroTipo = null);
                    }),
                    ...TipoAusencia.values.map(
                      (t) => _chipFiltro(t.etiqueta, _filtroTipo == t, () {
                        setState(() => _filtroTipo = t);
                      }),
                    ),
                  ],
                ),
          children: [
            ),
            Expanded(
        ),
                padding: const EdgeInsets.all(16),
                itemCount: solicitudes.length,
                itemBuilder: (context, i) =>
                    _tarjetaSolicitud(solicitudes[i], solicitudes),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tarjetaSolicitud(
      SolicitudVacaciones s, List<SolicitudVacaciones> todas) {
    final color = _colorTipo(s.tipo);

    // Calcular solapamiento local (empleados aprobados en el mismo período)
    int solapados = 0;
    if (_esPropietario && s.estado == EstadoSolicitud.solicitado) {
      final ids = todas
          .where((o) =>
              o.id != s.id &&
              o.estado == EstadoSolicitud.aprobado &&
              o.fechaInicio
                  .isBefore(s.fechaFin.add(const Duration(days: 1))) &&
              o.fechaFin
                  .isAfter(s.fechaInicio.subtract(const Duration(days: 1))))
          .map((o) => o.empleadoId)
          .toSet();
      solapados = ids.length;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _verDetalle(s),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.empleadoNombre ?? 'Empleado',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        // Badge solapamiento ⚠️
                        if (solapados > 0) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 12,
                                    color: Colors.orange.shade700),
                                const SizedBox(width: 3),
                                Text(
                                  '$solapados también ausente${solapados > 1 ? 's' : ''}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _colorEstado(s.estado)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.estado.etiqueta,
                            style: TextStyle(
                              color: _colorEstado(s.estado),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.tipo.etiqueta} · ${s.diasNaturales} días',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                    Text(
                      '${_formatFecha(s.fechaInicio)} → ${_formatFecha(s.fechaFin)}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                    if (s.descuentoSalario > 0)
                      Text(
                        'Descuento: -${s.descuentoSalario.toStringAsFixed(2)} €',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (_esPropietario &&
                  s.estado == EstadoSolicitud.solicitado)
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 22),
                      tooltip: 'Aprobar',
                      onPressed: () => _aprobar(s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: Colors.red, size: 22),
                      tooltip: 'Rechazar',
                      onPressed: () => _rechazar(s),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  void _nuevaSolicitud() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => NuevaSolicitudForm(empresaId: widget.empresaId),
    );
    if (mounted) setState(() {});
  }

  Future<void> _aprobar(SolicitudVacaciones s) async {
    // ── Verificar solapamiento antes de aprobar ──────────────────────────────
    ResultadoSolapamiento? overlap;
    try {
      overlap = await _svc.detectarSolapamiento(
        widget.empresaId,
        s.fechaInicio,
        s.fechaFin,
        excluirEmpleadoId: s.empleadoId,
      );
    } catch (_) {
      overlap = null;
    }

    if (overlap != null && overlap.esConflicto && mounted) {
      final o = overlap;
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text('Posible conflicto de cobertura',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: Text(
            '⚠️ ${o.empleadosAusentes} empleado${o.empleadosAusentes > 1 ? 's' : ''} '
            'ya están ausentes en este período '
            '(${o.porcentaje.toStringAsFixed(0)} % del equipo).\n\n'
            '${o.nombresAusentes.take(3).join(', ')}'
            '${o.nombresAusentes.length > 3 ? '...' : ''}\n\n'
            '¿Deseas aprobar igualmente?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white),
              child: const Text('Aprobar igualmente'),
            ),
          ],
        ),
      );
      if (continuar != true) return;
    }

    // ── Aprobar ──────────────────────────────────────────────────────────────
    try {
      await _svc.aprobarSolicitud(widget.empresaId, s.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Solicitud aprobada'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rechazar(SolicitudVacaciones s) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Rechazar solicitud'),
          content: TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(labelText: 'Motivo (opcional)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Rechazar')),
          ],
        );
      },
    );
    if (motivo == null) return;
    try {
      await _svc.rechazarSolicitud(widget.empresaId, s.id,
          motivo: motivo.isNotEmpty ? motivo : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Solicitud rechazada'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _verDetalle(SolicitudVacaciones s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tipo.etiqueta),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empleado: ${s.empleadoNombre ?? s.empleadoId}'),
            Text(
                'Período: ${_formatFecha(s.fechaInicio)} — ${_formatFecha(s.fechaFin)}'),
            Text('Días naturales: ${s.diasNaturales}'),
            Text('Días laborables: ${s.diasLaborables}'),
            Text('Estado: ${s.estado.etiqueta}'),
            if (s.subtipo != null) Text('Subtipo: ${s.subtipo!.etiqueta}'),
            if (s.descuentoSalario > 0)
              Text(
                  'Descuento: ${s.descuentoSalario.toStringAsFixed(2)} €',
                  style: const TextStyle(color: Colors.red)),
            if (s.motivoRechazo != null && s.motivoRechazo!.isNotEmpty) ...[
              const Divider(),
              Text('Motivo de rechazo:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                      fontSize: 13)),
              Text(s.motivoRechazo!,
                  style: const TextStyle(fontSize: 13)),
            ],
            if (s.notas != null && s.notas!.isNotEmpty)
              Text('Notas: ${s.notas}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSemaforo(int disponibles, int total) {
    final porcentaje = total > 0 ? (disponibles / total) * 100.0 : 100.0;
    Color color;
    if (porcentaje > 60) {
      color = Colors.green;
    } else if (porcentaje > 30) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    return Icon(Icons.circle, color: color, size: 12);
  }

  Color _colorTipo(TipoAusencia tipo) {
    switch (tipo) {
      case TipoAusencia.vacaciones:
        return Colors.teal;
      case TipoAusencia.ausenciaJustificada:
        return Colors.orange;
      case TipoAusencia.ausenciaInjustificada:
        return Colors.red;
      case TipoAusencia.permisoRetribuido:
        return Colors.orange;
      case TipoAusencia.bajaMedica:
        return Colors.blue;
    }
  }

  Color _colorEstado(EstadoSolicitud estado) {
    switch (estado) {
      case EstadoSolicitud.solicitado:
        return Colors.orange;
      case EstadoSolicitud.aprobado:
        return Colors.green;
      case EstadoSolicitud.rechazado:
        return Colors.red;
    }
  }

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _chipFiltro(String label, bool activo, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: activo,
          selectedColor: const Color(0xFF00796B).withValues(alpha: 0.15),
          onSelected: (_) => onTap(),
        ),
      );
}











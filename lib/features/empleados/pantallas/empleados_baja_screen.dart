import 'package:flutter/material.dart';
import 'package:planeag_flutter/services/baja_empleado_service.dart';
import '../../../core/widgets/flux_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// POPUP: EMPLEADOS DADOS DE BAJA
// Uso: EmpleadosBajaPopup.mostrar(context, empresaId: '...')
// ═══════════════════════════════════════════════════════════════════════════════

const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF8F9FA);

class EmpleadosBajaPopup {
  static Future<void> mostrar(BuildContext context,
      {required String empresaId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _EmpleadosBajaSheet(empresaId: empresaId),
    );
  }
}

class _EmpleadosBajaSheet extends StatelessWidget {
  final String empresaId;
  const _EmpleadosBajaSheet({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sick_outlined, color: _kRed, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Empleados de baja',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: _kText)),
                  Text('Historial y reversión de bajas',
                      style: TextStyle(fontSize: 11, color: _kSub)),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: _kSub, size: 20),
              ),
            ]),
          ),

          const Divider(height: 1, color: _kBorder),

          // Contenido
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: BajaEmpleadoService().empleadosDadosDeBaja(empresaId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kBlue));
                }
                final empleados = snap.data ?? [];
                if (empleados.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_outlined, size: 56,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No hay empleados dados de baja',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: empleados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _TarjetaBaja(
                    empleado: empleados[i],
                    empresaId: empresaId,
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Tarjeta de empleado de baja ──────────────────────────────────────────────

class _TarjetaBaja extends StatelessWidget {
  final Map<String, dynamic> empleado;
  final String empresaId;
  const _TarjetaBaja({required this.empleado, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final nombre         = empleado['nombre'] as String? ?? 'Empleado';
    final causaBaja      = empleado['causa_baja_etiqueta'] as String? ?? '—';
    final fechaBajaTs    = empleado['fecha_baja'];
    final fechaBaja      = fechaBajaTs != null
        ? (fechaBajaTs.toDate() as DateTime) : null;
    final fmtFecha       = fechaBaja != null
        ? '${fechaBaja.day.toString().padLeft(2, '0')}/'
          '${fechaBaja.month.toString().padLeft(2, '0')}/'
          '${fechaBaja.year}'
        : '—';
    final bajaRevertida  = empleado['baja_revertida'] as bool? ?? false;
    final ini            = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _kRed.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(ini,
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold, color: _kRed)),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: _kText)),
                ),
                if (bajaRevertida)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.25)),
                    ),
                    child: const Text('Revertida',
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w600, color: _kBlue)),
                  ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 11, color: _kSub),
                const SizedBox(width: 4),
                Text('Baja: $fmtFecha',
                    style: const TextStyle(fontSize: 11, color: _kSub)),
                const SizedBox(width: 10),
                const Icon(Icons.label_outline_rounded, size: 11, color: _kSub),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(causaBaja,
                      style: const TextStyle(fontSize: 11, color: _kSub),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              if (empleado['finiquito_id'] != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.receipt_long_outlined, size: 11, color: _kSub),
                  const SizedBox(width: 4),
                  Text('Finiquito: ${empleado['finiquito_id']}',
                      style: const TextStyle(fontSize: 10, color: _kSub)),
                ]),
              ],
            ],
          )),

          // Botón revertir
          if (!bajaRevertida)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: 'Revertir baja',
                child: InkWell(
                  onTap: () => _confirmarReversion(context, empleado),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.undo_rounded,
                        color: _kBlue, size: 18),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _confirmarReversion(
      BuildContext context, Map<String, dynamic> emp) async {
    final motivoCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              decoration: const BoxDecoration(
                color: _kBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.undo_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Revertir baja',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('¿Reactivar a ${emp['nombre']}?',
                        style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                ),
              ]),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _kRed.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: _kRed),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'El empleado recuperará el acceso a la app y todos sus módulos.',
                        style: TextStyle(fontSize: 12, color: _kText),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Motivo de la reversión',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: _kText)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: motivoCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: _kText),
                  decoration: InputDecoration(
                    hintText: 'Ej: Error administrativo, recontratación...',
                    hintStyle: const TextStyle(color: _kSub, fontSize: 12),
                    filled: true, fillColor: _kBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBlue, width: 2)),
                    isDense: true,
                  ),
                ),
              ]),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSub,
                      side: const BorderSide(color: _kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.undo_rounded, size: 15),
                    label: const Text('Sí, revertir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await BajaEmpleadoService().revertirBaja(
        empresaId: empresaId,
        empleadoId: emp['id'] as String,
        motivo: motivoCtrl.text.trim().isNotEmpty
            ? motivoCtrl.text.trim()
            : 'Reversión manual',
      );
      motivoCtrl.dispose();
      if (context.mounted) {
        FluxToast.exito(context, 'Baja revertida. El empleado tiene acceso de nuevo.');
      }
    } catch (e) {
      motivoCtrl.dispose();
      if (context.mounted) {
        FluxToast.error(context, 'Error al revertir la baja: $e');
      }
    }
  }
}

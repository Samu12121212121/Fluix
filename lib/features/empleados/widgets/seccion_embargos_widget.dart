import 'package:flutter/material.dart';
import '../../../models/embargo_model.dart';
import '../../../services/nominas_service.dart';
import '../../../services/embargo_calculator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN EMBARGOS JUDICIALES
// ─────────────────────────────────────────────────────────────────────────────

class SeccionEmbargos extends StatefulWidget {
  final String empleadoId;
  final String nombreEmpleado;

  const SeccionEmbargos({
    super.key,
    required this.empleadoId,
    required this.nombreEmpleado,
  });

  @override
  State<SeccionEmbargos> createState() => _SeccionEmbargosState();
}

class _SeccionEmbargosState extends State<SeccionEmbargos> {
  final _svc = NominasService();
  static const _colorPrimario = Color(0xFFB71C1C);

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _colorPrimario.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel, color: _colorPrimario, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Embargos judiciales',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _colorPrimario)),
                        Text(widget.nombreEmpleado,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: _colorPrimario, size: 28),
                    onPressed: () => _abrirFormulario(null),
                    tooltip: 'Añadir embargo',
                  ),
                ]),
              ),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55),
                child: StreamBuilder<List<Embargo>>(
                  stream: _svc.streamEmbargos(widget.empleadoId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()));
                    }
                    final embargos = snap.data ?? [];
                    if (embargos.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.gavel, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Sin embargos registrados',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                          const SizedBox(height: 6),
                          Text('El empleado no tiene embargos judiciales activos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        ]),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: embargos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) => _buildTarjetaEmbargo(embargos[i]),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Base legal: art. 607 LEC. El SMI de referencia 2026 '
                        'es 1.381,20 €/mes. El embargo se aplica sobre el '
                        'salario neto (después de SS e IRPF).',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaEmbargo(Embargo emb) {
    final vigente = emb.vigenteEn(DateTime.now());
    final color = vigente ? _colorPrimario : Colors.grey;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.gavel, color: color, size: 18),
      ),
      title: Text(emb.organismo,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
              color: vigente ? Colors.black87 : Colors.grey[500])),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Exp: ${emb.expediente}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(
          'Desde: ${_fmtDate(emb.fechaInicio)}'
          '${emb.fechaFin != null ? '  ·  Hasta: ${_fmtDate(emb.fechaFin!)}' : ''}',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        if (emb.importeMensualMaximo != null)
          Text('Tope judicial: ${emb.importeMensualMaximo!.toStringAsFixed(2)} €/mes',
              style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w500)),
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(vigente ? 'Activo' : 'Inactivo',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (v) async {
            if (v == 'editar') _abrirFormulario(emb);
            if (v == 'toggle') await _svc.guardarEmbargo(widget.empleadoId, emb.copyWith(activo: !emb.activo));
            if (v == 'eliminar') _confirmarEliminar(emb);
            if (v == 'calcular') _mostrarCalculo(emb);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'calcular',
                child: ListTile(leading: Icon(Icons.calculate, color: Colors.blue, size: 18),
                    title: Text('Ver cálculo LEC', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'editar',
                child: ListTile(leading: Icon(Icons.edit, size: 18),
                    title: Text('Editar', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'toggle',
                child: ListTile(
                    leading: Icon(emb.activo ? Icons.pause_circle : Icons.play_circle,
                        size: 18, color: emb.activo ? Colors.orange : Colors.green),
                    title: Text(emb.activo ? 'Suspender' : 'Reactivar',
                        style: const TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'eliminar',
                child: ListTile(leading: Icon(Icons.delete, color: Colors.red, size: 18),
                    title: Text('Eliminar', style: TextStyle(fontSize: 13, color: Colors.red)),
                    contentPadding: EdgeInsets.zero)),
          ],
        ),
      ]),
    );
  }

  void _abrirFormulario(Embargo? embargo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FormularioEmbargo(empleadoId: widget.empleadoId, embargo: embargo),
    );
  }

  void _confirmarEliminar(Embargo emb) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar embargo'),
        content: Text('¿Eliminar el embargo de "${emb.organismo}" (exp. ${emb.expediente})?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await _svc.eliminarEmbargo(widget.empleadoId, emb.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarCalculo(Embargo emb) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.calculate, color: Color(0xFFB71C1C)),
          SizedBox(width: 8),
          Text('Tabla art. 607 LEC', style: TextStyle(fontSize: 15)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Embargo: ${emb.organismo}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text('Exp: ${emb.expediente}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            if (emb.importeMensualMaximo != null)
              Text('Tope judicial: ${emb.importeMensualMaximo!.toStringAsFixed(2)} €',
                  style: TextStyle(color: Colors.orange[700], fontSize: 12)),
            const Divider(),
            const Text('Simulación sobre netos típicos:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            ...[1200.0, 1500.0, 2000.0, 2500.0, 3000.0, 4000.0].map((neto) {
              final maxLec = EmbargoCalculator.calcularMaximoEmbargable(neto);
              final efectivo = EmbargoCalculator.calcularEmbargoMes(neto,
                  importeMensualMaximo: emb.importeMensualMaximo);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  SizedBox(width: 70,
                      child: Text('${neto.toStringAsFixed(0)} €',
                          style: TextStyle(color: Colors.grey[700], fontSize: 11))),
                  Expanded(child: Row(children: [
                    Text('Máx LEC: ${maxLec.toStringAsFixed(2)} €',
                        style: const TextStyle(fontSize: 11)),
                    if (efectivo != maxLec) ...[
                      const Text(' → ', style: TextStyle(fontSize: 11)),
                      Text('Tope: ${efectivo.toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w600)),
                    ],
                  ])),
                ]),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO EMBARGO
// ─────────────────────────────────────────────────────────────────────────────

class FormularioEmbargo extends StatefulWidget {
  final String empleadoId;
  final Embargo? embargo;

  const FormularioEmbargo({super.key, required this.empleadoId, this.embargo});

  @override
  State<FormularioEmbargo> createState() => _FormularioEmbargoState();
}

class _FormularioEmbargoState extends State<FormularioEmbargo> {
  final _svc = NominasService();
  final _formKey = GlobalKey<FormState>();
  static const _colorPrimario = Color(0xFFB71C1C);

  late final _organismoCtrl = TextEditingController(text: widget.embargo?.organismo ?? '');
  late final _expedienteCtrl = TextEditingController(text: widget.embargo?.expediente ?? '');
  late final _topeCtrl = TextEditingController(
      text: widget.embargo?.importeMensualMaximo?.toStringAsFixed(2) ?? '');
  late DateTime _fechaInicio = widget.embargo?.fechaInicio ?? DateTime.now();
  late DateTime? _fechaFin = widget.embargo?.fechaFin;
  late bool _activo = widget.embargo?.activo ?? true;
  bool _guardando = false;

  @override
  void dispose() {
    _organismoCtrl.dispose();
    _expedienteCtrl.dispose();
    _topeCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final tope = _topeCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_topeCtrl.text.trim().replaceAll(',', '.'));
      final embargo = Embargo(
        id: widget.embargo?.id ?? '',
        organismo: _organismoCtrl.text.trim(),
        expediente: _expedienteCtrl.text.trim(),
        importeMensualMaximo: tope,
        activo: _activo,
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
      );
      await _svc.guardarEmbargo(widget.empleadoId, embargo);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.embargo == null ? '✅ Embargo registrado' : '✅ Embargo actualizado'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _colorPrimario.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.gavel, color: _colorPrimario, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.embargo == null ? 'Registrar embargo judicial' : 'Editar embargo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _colorPrimario),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _organismoCtrl,
                      decoration: _inputDecor('Organismo emisor *',
                          hint: 'Juzgado de Primera Instancia nº X de ...', icon: Icons.account_balance),
                      validator: (v) => (v?.trim().isEmpty ?? true) ? 'Campo obligatorio' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _expedienteCtrl,
                      decoration: _inputDecor('Número de expediente / autos *',
                          hint: 'Ej: 123/2026', icon: Icons.numbers),
                      validator: (v) => (v?.trim().isEmpty ?? true) ? 'Campo obligatorio' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _topeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecor('Tope mensual fijado por el juzgado (€)',
                          hint: 'Dejar vacío = sin tope (tabla LEC completa)', icon: Icons.euro),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaInicio,
                              firstDate: DateTime(2015),
                              lastDate: DateTime(2030),
                              locale: const Locale('es', 'ES'),
                            );
                            if (picked != null) setState(() => _fechaInicio = picked);
                          },
                          child: _buildCampoFecha('Fecha inicio *', _fmtDate(_fechaInicio)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaFin ?? DateTime.now(),
                              firstDate: DateTime(2015),
                              lastDate: DateTime(2035),
                              locale: const Locale('es', 'ES'),
                            );
                            if (picked != null) setState(() => _fechaFin = picked);
                          },
                          child: Stack(children: [
                            _buildCampoFecha('Fecha fin',
                                _fechaFin != null ? _fmtDate(_fechaFin!) : 'Sin fecha de fin'),
                            if (_fechaFin != null)
                              Positioned(
                                right: 8, top: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _fechaFin = null),
                                  child: const Icon(Icons.clear, size: 14, color: Colors.grey),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      value: _activo,
                      onChanged: (v) => setState(() => _activo = v),
                      title: const Text('Embargo activo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        _activo ? 'Se aplicará en las próximas nóminas' : 'Suspendido — no se aplicará',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      activeThumbColor: _colorPrimario,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(_guardando ? 'Guardando...' :
                            (widget.embargo == null ? 'Registrar embargo' : 'Guardar cambios')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _colorPrimario,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampoFecha(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 12, color: _colorPrimario),
          const SizedBox(width: 4),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      ]),
    );
  }

  InputDecoration _inputDecor(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _colorPrimario, width: 1.5)),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../domain/modelos/factura_recurrente.dart';
import '../../../services/factura_recurrente_service.dart';

class TabFacturasRecurrentes extends StatefulWidget {
  final String empresaId;
  const TabFacturasRecurrentes({super.key, required this.empresaId});

  @override
  State<TabFacturasRecurrentes> createState() => _TabFacturasRecurrentesState();
}

class _TabFacturasRecurrentesState extends State<TabFacturasRecurrentes> {
  final _svc = FacturaRecurrenteService();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _nombre => FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<List<FacturaRecurrente>>(
        stream: _svc.listar(widget.empresaId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final lista = snap.data ?? [];
          if (lista.isEmpty) return _emptyState();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _tarjeta(lista[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva recurrente'),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
  }

  Widget _tarjeta(FacturaRecurrente fr) {
    final proxima = fr.proximaEmision;
    final vence = fr.fechaFin;
    final vencida = vence != null && DateTime.now().isAfter(vence);
    final hoy = DateFormat('dd MMM', 'es').format(DateTime.now());
    final esHoy = DateFormat('dd MMM', 'es').format(proxima) == hoy;
    final pasada = proxima.isBefore(DateTime.now().subtract(const Duration(hours: 1)));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !fr.activa ? const Color(0xFFE2E8F0)
              : pasada ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (fr.activa ? const Color(0xFF6366F1) : Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.repeat_rounded,
                color: fr.activa ? const Color(0xFF6366F1) : Colors.grey, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fr.descripcion,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(fr.clienteNombre,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fr.importeConIva.toStringAsFixed(2)} €',
                style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16,
                  color: fr.activa ? const Color(0xFF6366F1) : Colors.grey,
                )),
            _badgePeriodo(fr.periodo),
          ]),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(children: [
          _infoChip(
            Icons.schedule_rounded,
            esHoy ? 'Hoy' : DateFormat('dd MMM yyyy', 'es').format(proxima),
            pasada && fr.activa ? const Color(0xFFEF4444) : const Color(0xFF64748B),
          ),
          if (vence != null) ...[
            const SizedBox(width: 8),
            _infoChip(
              Icons.event_busy_rounded,
              'Hasta ${DateFormat('dd MMM yyyy', 'es').format(vence)}',
              vencida ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
            ),
          ],
          const Spacer(),
          // Toggle activa
          GestureDetector(
            onTap: () => _svc.toggleActiva(widget.empresaId, fr),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: fr.activa
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(fr.activa ? 'Activa' : 'Pausada',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: fr.activa ? const Color(0xFF10B981) : Colors.grey,
                  )),
            ),
          ),
          const SizedBox(width: 6),
          // Emitir ahora
          if (fr.activa)
            TextButton.icon(
              onPressed: () => _emitirAhora(fr),
              icon: const Icon(Icons.send_rounded, size: 14),
              label: const Text('Emitir', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          // Eliminar
          IconButton(
            onPressed: () => _confirmarEliminar(fr),
            icon: const Icon(Icons.delete_outline, size: 18),
            color: const Color(0xFFEF4444),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ],
  );

  Widget _badgePeriodo(PeriodoRecurrencia p) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(p.etiqueta,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: Color(0xFF6366F1))),
  );

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.repeat_rounded, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('Sin documentos recurrentes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Text('Configura facturas mensuales para alquileres,\nsuscripciones o servicios fijos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Crear primera recurrente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    ),
  );

  // ── Acciones ──────────────────────────────────────────────────────────────

  Future<void> _emitirAhora(FacturaRecurrente fr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Emitir factura'),
        content: Text(
          'Se generará la factura de "${fr.descripcion}" '
          'por ${fr.importeConIva.toStringAsFixed(2)} € para ${fr.clienteNombre}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white),
            child: const Text('Emitir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _svc.emitirAhora(
        empresaId: widget.empresaId, fr: fr,
        usuarioId: _uid, usuarioNombre: _nombre,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Factura generada correctamente'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _confirmarEliminar(FacturaRecurrente fr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar recurrente'),
        content: Text('¿Eliminar "${fr.descripcion}"?\nNo afecta a las facturas ya generadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await _svc.eliminar(widget.empresaId, fr.id);
  }

  void _abrirFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioRecurrente(
        empresaId: widget.empresaId,
        svc: _svc,
      ),
    );
  }
}

// ── Formulario nueva recurrente ───────────────────────────────────────────────

class _FormularioRecurrente extends StatefulWidget {
  final String empresaId;
  final FacturaRecurrenteService svc;
  const _FormularioRecurrente({required this.empresaId, required this.svc});

  @override
  State<_FormularioRecurrente> createState() => _FormularioRecurrenteState();
}

class _FormularioRecurrenteState extends State<_FormularioRecurrente> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _clienteCtrl = TextEditingController();
  final _nifCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _importeCtrl = TextEditingController();
  PeriodoRecurrencia _periodo = PeriodoRecurrencia.mensual;
  DateTime _inicio = DateTime.now();
  DateTime? _fin;
  double _iva = 21;
  bool _guardando = false;

  @override
  void dispose() {
    _descCtrl.dispose(); _clienteCtrl.dispose(); _nifCtrl.dispose();
    _emailCtrl.dispose(); _importeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9, minChildSize: 0.6, maxChildSize: 0.97, expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Text('Nueva factura recurrente',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: Form(
            key: _formKey,
            child: ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
              _campo('Descripción', _descCtrl, 'Alquiler local, Suscripción...', requerido: true),
              const SizedBox(height: 12),
              _campo('Cliente', _clienteCtrl, 'Nombre del cliente', requerido: true),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _campo('NIF/CIF', _nifCtrl, 'B12345678')),
                const SizedBox(width: 12),
                Expanded(child: _campo('Email', _emailCtrl, 'cliente@email.com',
                    keyboardType: TextInputType.emailAddress)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _campo('Importe (sin IVA)', _importeCtrl, '0.00',
                    requerido: true, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _dropdownIva()),
              ]),
              const SizedBox(height: 12),
              _dropdownPeriodo(),
              const SizedBox(height: 12),
              _selectorFecha('Primera emisión', _inicio,
                  (d) => setState(() => _inicio = d)),
              const SizedBox(height: 12),
              _selectorFechaOpcional('Fecha fin (opcional)', _fin,
                  (d) => setState(() => _fin = d)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _guardando
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar recurrente',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, String hint,
      {bool requerido = false, TextInputType keyboardType = TextInputType.text}) =>
      TextFormField(
        controller: ctrl, keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label, hintText: hint, isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: requerido ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
      );

  Widget _dropdownIva() => DropdownButtonFormField<double>(
    value: _iva,
    decoration: InputDecoration(labelText: 'IVA %', isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
    items: const [
      DropdownMenuItem(value: 0, child: Text('0%')),
      DropdownMenuItem(value: 4, child: Text('4%')),
      DropdownMenuItem(value: 10, child: Text('10%')),
      DropdownMenuItem(value: 21, child: Text('21%')),
    ],
    onChanged: (v) => setState(() => _iva = v ?? 21),
  );

  Widget _dropdownPeriodo() => DropdownButtonFormField<PeriodoRecurrencia>(
    value: _periodo,
    decoration: InputDecoration(labelText: 'Periodicidad', isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
    items: PeriodoRecurrencia.values.map((p) =>
        DropdownMenuItem(value: p, child: Text(p.etiqueta))).toList(),
    onChanged: (v) => setState(() => _periodo = v ?? PeriodoRecurrencia.mensual),
  );

  Widget _selectorFecha(String label, DateTime fecha, void Function(DateTime) onChanged) =>
      InkWell(
        onTap: () async {
          final d = await showDatePicker(context: context,
              initialDate: fecha, firstDate: DateTime(2020), lastDate: DateTime(2030));
          if (d != null) onChanged(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const Spacer(),
            Text(DateFormat('dd/MM/yyyy').format(fecha),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _selectorFechaOpcional(String label, DateTime? fecha, void Function(DateTime?) onChanged) =>
      InkWell(
        onTap: () async {
          final d = await showDatePicker(context: context,
              initialDate: fecha ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime(2020), lastDate: DateTime(2035));
          onChanged(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const Spacer(),
            if (fecha != null) ...[
              Text(DateFormat('dd/MM/yyyy').format(fecha),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
              ),
            ] else
              const Text('Sin fecha', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ]),
        ),
      );

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await widget.svc.crear(
        empresaId: widget.empresaId,
        descripcion: _descCtrl.text.trim(),
        clienteNombre: _clienteCtrl.text.trim(),
        clienteNif: _nifCtrl.text.trim().isEmpty ? null : _nifCtrl.text.trim(),
        clienteEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        importe: double.parse(_importeCtrl.text.trim().replaceAll(',', '.')),
        iva: _iva,
        periodo: _periodo,
        fechaInicio: _inicio,
        fechaFin: _fin,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

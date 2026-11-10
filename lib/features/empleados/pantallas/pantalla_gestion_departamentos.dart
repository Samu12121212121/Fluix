import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/modelos/departamento_empresa.dart';
import '../../../services/roles_departamentos_service.dart';
import '../../../core/widgets/fluix_app_bar.dart';

const _kBlue = Color(0xFF3B82F6);
const _kRed  = Color(0xFFEF4444);

class PantallaGestionDepartamentos extends StatelessWidget {
  final String empresaId;
  const PantallaGestionDepartamentos({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final svc  = RolesDepartamentosService();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg   = dark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: const FluixAppBar(titulo: 'Departamentos', showLeading: true),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kBlue,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo departamento'),
        onPressed: () => _abrirFormulario(context, svc, null),
      ),
      body: StreamBuilder<List<DepartamentoEmpresa>>(
        stream: svc.departamentosStream(empresaId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final depts = snap.data ?? [];
          if (depts.isEmpty) return _buildVacio(context, svc, dark);

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: depts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _DeptCard(
              dept: depts[i],
              empresaId: empresaId,
              depts: depts,
              onEditar: () => _abrirFormulario(context, svc, depts[i]),
              onEliminar: () => _confirmarEliminar(context, svc, depts[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVacio(BuildContext ctx, RolesDepartamentosService svc, bool dark) =>
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_tree_outlined, size: 64,
            color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.15)),
        const SizedBox(height: 12),
        Text('Sin departamentos', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
            color: dark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => _abrirFormulario(ctx, svc, null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Crear primer departamento'),
          style: FilledButton.styleFrom(backgroundColor: _kBlue),
        ),
      ]));

  void _abrirFormulario(BuildContext ctx, RolesDepartamentosService svc,
      DepartamentoEmpresa? dept) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FormularioDept(
          empresaId: empresaId, svc: svc, dept: dept),
    );
  }

  Future<void> _confirmarEliminar(BuildContext ctx,
      RolesDepartamentosService svc, DepartamentoEmpresa dept) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar departamento'),
        content: Text('¿Eliminar "${dept.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await svc.eliminarDepartamento(empresaId, dept.id);
  }
}

class _DeptCard extends StatelessWidget {
  final DepartamentoEmpresa dept;
  final String empresaId;
  final List<DepartamentoEmpresa> depts;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _DeptCard({
    required this.dept, required this.empresaId, required this.depts,
    required this.onEditar, required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surf = dark ? const Color(0xFF1E293B) : Colors.white;
    final bord = dark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final paddingLeft = dept.padreId != null ? 16.0 : 0.0;
    final padreNombre = dept.padreId != null
        ? depts.where((d) => d.id == dept.padreId).map((d) => d.nombre).firstOrNull
        : null;

    return Padding(
      padding: EdgeInsets.only(left: paddingLeft),
      child: Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bord),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_tree_outlined, color: _kBlue, size: 20),
          ),
          title: Text(dept.nombre,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                  color: dark ? Colors.white : Colors.black87)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (padreNombre != null)
              Text('Sub-departamento de $padreNombre',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (dept.jefeNombre != null)
              Text('Responsable: ${dept.jefeNombre}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
            if (dept.descripcion != null && dept.descripcion!.isNotEmpty)
              Text(dept.descripcion!,
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          ]),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18,
                color: Colors.grey), onPressed: onEditar, padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
            IconButton(icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: _kRed), onPressed: onEliminar,
                padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
      ),
    );
  }
}

// ── Formulario ───────────────────────────────────────────────────────────────

class _FormularioDept extends StatefulWidget {
  final String empresaId;
  final RolesDepartamentosService svc;
  final DepartamentoEmpresa? dept;
  const _FormularioDept(
      {required this.empresaId, required this.svc, this.dept});

  @override
  State<_FormularioDept> createState() => _FormularioDeptState();
}

class _FormularioDeptState extends State<_FormularioDept> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _descCtrl;
  String? _padreId;
  String? _jefeUid;
  String? _jefeNombre;
  List<DepartamentoEmpresa> _depts = [];
  List<Map<String, dynamic>> _empleados = [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.dept?.nombre ?? '');
    _descCtrl   = TextEditingController(text: widget.dept?.descripcion ?? '');
    _padreId    = widget.dept?.padreId;
    _jefeUid    = widget.dept?.jefeUid;
    _jefeNombre = widget.dept?.jefeNombre;
    _cargar();
  }

  Future<void> _cargar() async {
    final db = FirebaseFirestore.instance;
    final [deptsSnap, empsSnap] = await Future.wait([
      widget.svc.getDepartamentos(widget.empresaId),
      db.collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('activo', isEqualTo: true)
          .get()
          .then((s) => s.docs
              .map((d) => {'uid': d.id, 'nombre': d.data()['nombre'] ?? ''})
              .toList()),
    ]);
    if (mounted) setState(() {
      _depts    = (deptsSnap as List<DepartamentoEmpresa>)
          .where((d) => d.id != (widget.dept?.id ?? ''))
          .toList();
      _empleados = (empsSnap as List<Map<String, dynamic>>)
          .cast<Map<String, dynamic>>();
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    try {
      final d = DepartamentoEmpresa(
        id:          widget.dept?.id ?? '',
        nombre:      _nombreCtrl.text.trim(),
        descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        jefeUid:     _jefeUid,
        jefeNombre:  _jefeNombre,
        padreId:     _padreId,
        creadoAt:    widget.dept?.creadoAt ?? DateTime.now(),
      );
      if (widget.dept == null) {
        await widget.svc.crearDepartamento(widget.empresaId, d);
      } else {
        await widget.svc.actualizarDepartamento(widget.empresaId, d);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0,
          MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(children: [
            Text(widget.dept == null ? 'Nuevo departamento' : 'Editar departamento',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Flexible(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _field(_nombreCtrl, 'Nombre *', Icons.business_outlined),
            const SizedBox(height: 10),
            _field(_descCtrl, 'Descripción (opcional)', Icons.notes_outlined),
            const SizedBox(height: 10),
            // Padre
            _dropdown<String?>(
              label: 'Departamento padre (opcional)',
              icon: Icons.account_tree_outlined,
              value: _padreId,
              items: [
                const DropdownMenuItem(value: null, child: Text('— Ninguno —')),
                ..._depts.map((d) => DropdownMenuItem(
                    value: d.id, child: Text(d.nombre))),
              ],
              onChanged: (v) => setState(() => _padreId = v),
            ),
            const SizedBox(height: 10),
            // Jefe
            _dropdown<String?>(
              label: 'Responsable / Jefe',
              icon: Icons.person_outlined,
              value: _jefeUid,
              items: [
                const DropdownMenuItem(value: null, child: Text('— Sin asignar —')),
                ..._empleados.map((e) => DropdownMenuItem(
                    value: e['uid'] as String,
                    child: Text(e['nombre'] as String))),
              ],
              onChanged: (v) {
                final nombre = _empleados
                    .where((e) => e['uid'] == v)
                    .map((e) => e['nombre'] as String)
                    .firstOrNull;
                setState(() { _jefeUid = v; _jefeNombre = nombre; });
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: _guardando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: Colors.white))
                  : const Text('Guardar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          filled: true, fillColor: const Color(0xFFF8F9FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
      );

  Widget _dropdown<T>({
    required String label, required IconData icon, required T value,
    required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged,
  }) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey),
      filled: true, fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      isDense: true,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value, isExpanded: true,
        style: const TextStyle(fontSize: 13.5, color: Colors.black87),
        items: items, onChanged: onChanged,
      ),
    ),
  );
}

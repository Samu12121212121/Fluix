import 'package:flutter/material.dart';
import '../../../domain/modelos/rol_empresa.dart';
import '../../../services/roles_departamentos_service.dart';
import '../../../core/widgets/fluix_app_bar.dart';

const _kBlue  = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kRed   = Color(0xFFEF4444);

class PantallaGestionRoles extends StatelessWidget {
  final String empresaId;
  const PantallaGestionRoles({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final svc  = RolesDepartamentosService();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg   = dark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: const FluixAppBar(titulo: 'Roles de la empresa', showLeading: true),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kBlue,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo rol'),
        onPressed: () => _abrirFormulario(context, svc, null),
      ),
      body: StreamBuilder<List<RolEmpresa>>(
        stream: svc.rolesStream(empresaId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final roles = snap.data ?? [];
          if (roles.isEmpty) {
            return _buildVacio(context, svc, dark);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _RolCard(
              rol: roles[i],
              onEditar: () => _abrirFormulario(context, svc, roles[i]),
              onEliminar: () => _confirmarEliminar(context, svc, roles[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVacio(BuildContext ctx, RolesDepartamentosService svc, bool dark) =>
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.badge_outlined, size: 64,
            color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.15)),
        const SizedBox(height: 12),
        Text('Sin roles definidos', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
            color: dark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 6),
        const Text('Crea roles para organizar la jerarquía',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => _abrirFormulario(ctx, svc, null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Crear primer rol'),
          style: FilledButton.styleFrom(backgroundColor: _kBlue),
        ),
      ]));

  void _abrirFormulario(
      BuildContext ctx, RolesDepartamentosService svc, RolEmpresa? rol) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FormularioRol(
        empresaId: empresaId, svc: svc, rol: rol),
    );
  }

  Future<void> _confirmarEliminar(
      BuildContext ctx, RolesDepartamentosService svc, RolEmpresa rol) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar rol'),
        content: Text('¿Eliminar "${rol.nombre}"? '
            'Los empleados asignados a este rol mantendrán su nivel numérico.'),
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
    if (ok == true) await svc.eliminarRol(empresaId, rol.id);
  }
}

class _RolCard extends StatelessWidget {
  final RolEmpresa rol;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _RolCard(
      {required this.rol, required this.onEditar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final dark  = Theme.of(context).brightness == Brightness.dark;
    final surf  = dark ? const Color(0xFF1E293B) : Colors.white;
    final bord  = dark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final color = _hexColor(rol.color);
    final permsActivos = rol.permisos.entries
        .where((e) => e.value)
        .map((e) => kPermisosDisponibles[e.key] ?? e.key)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bord),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(child: Text('${rol.nivel}',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 14))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(rol.nombre, style: TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 14, color: dark ? Colors.white : Colors.black87)),
              if (rol.descripcion != null && rol.descripcion!.isNotEmpty)
                Text(rol.descripcion!, style: const TextStyle(
                    fontSize: 11.5, color: Colors.grey)),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18,
                color: Colors.grey), onPressed: onEditar, padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
            const SizedBox(width: 6),
            IconButton(icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: _kRed), onPressed: onEliminar,
                padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
        if (permsActivos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 6, runSpacing: 4,
              children: permsActivos.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Text(p, style: TextStyle(fontSize: 11, color: color,
                    fontWeight: FontWeight.w500)),
              )).toList(),
            ),
          ),
      ]),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) { return _kBlue; }
  }
}

// ── Formulario ───────────────────────────────────────────────────────────────

class _FormularioRol extends StatefulWidget {
  final String empresaId;
  final RolesDepartamentosService svc;
  final RolEmpresa? rol;
  const _FormularioRol(
      {required this.empresaId, required this.svc, this.rol});

  @override
  State<_FormularioRol> createState() => _FormularioRolState();
}

class _FormularioRolState extends State<_FormularioRol> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _descCtrl;
  late int _nivel;
  late String _color;
  late Map<String, bool> _permisos;
  bool _guardando = false;

  static const _colores = [
    '#3B82F6', '#10B981', '#F59E0B', '#EF4444',
    '#8B5CF6', '#EC4899', '#06B6D4', '#64748B',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.rol;
    _nombreCtrl = TextEditingController(text: r?.nombre ?? '');
    _descCtrl   = TextEditingController(text: r?.descripcion ?? '');
    _nivel  = r?.nivel  ?? 3;
    _color  = r?.color  ?? '#3B82F6';
    _permisos = r != null
        ? Map<String, bool>.from(r.permisos)
        : {for (final k in kPermisosDisponibles.keys) k: false};
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
      final rolData = RolEmpresa(
        id:          widget.rol?.id ?? '',
        nombre:      _nombreCtrl.text.trim(),
        descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        nivel:       _nivel,
        color:       _color,
        permisos:    _permisos,
        creadoAt:    widget.rol?.creadoAt ?? DateTime.now(),
      );
      if (widget.rol == null) {
        await widget.svc.crearRol(widget.empresaId, rolData);
      } else {
        await widget.svc.actualizarRol(widget.empresaId, rolData);
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
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(children: [
            Text(widget.rol == null ? 'Nuevo rol' : 'Editar rol',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Flexible(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _field(_nombreCtrl, 'Nombre del rol *', Icons.badge_outlined),
            const SizedBox(height: 10),
            _field(_descCtrl, 'Descripción (opcional)', Icons.notes_outlined),
            const SizedBox(height: 14),
            // Nivel
            const Text('Nivel jerárquico',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            const SizedBox(height: 6),
            Row(children: List.generate(5, (i) {
              final n = i + 1;
              final sel = _nivel == n;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _nivel = n),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: sel ? _kBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? _kBlue : const Color(0xFFE5E7EB)),
                    ),
                    child: Center(child: Text('$n',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : Colors.grey))),
                  ),
                ),
              );
            })),
            const SizedBox(height: 4),
            const Text('1 = máxima autoridad (Director)   5 = menor (Junior)',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 14),
            // Color
            const Text('Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: _colores.map((c) {
              Color col;
              try { col = Color(int.parse('FF${c.replaceAll('#', '')}', radix: 16)); }
              catch (_) { col = _kBlue; }
              final sel = _color == c;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: col, shape: BoxShape.circle,
                    border: sel ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: sel ? [BoxShadow(color: col.withValues(alpha: 0.5),
                        blurRadius: 6)] : null,
                  ),
                  child: sel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            // Permisos
            const Text('Permisos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            const SizedBox(height: 6),
            ...kPermisosDisponibles.entries.map((e) => SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.value,
                  style: const TextStyle(fontSize: 13)),
              value: _permisos[e.key] ?? false,
              activeColor: _kBlue,
              onChanged: (v) =>
                  setState(() => _permisos[e.key] = v),
            )),
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
                  : const Text('Guardar rol',
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
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
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
}

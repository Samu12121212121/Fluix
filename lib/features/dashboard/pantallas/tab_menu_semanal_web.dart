import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/contenido_web_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB MENÚ SEMANAL WEB — gestión del menú del día por días de la semana
// Colección: empresas/{id}/menu_semanal
// ═════════════════════════════════════════════════════════════════════════════

const _kDias = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

class TabMenuSemanalWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color? color;

  const TabMenuSemanalWeb({
    super.key,
    required this.empresaId,
    required this.svc,
    this.color,
  });

  @override
  State<TabMenuSemanalWeb> createState() => _TabMenuSemanalWebState();
}

class _TabMenuSemanalWebState extends State<TabMenuSemanalWeb> {
  late final Stream<List<Map<String, dynamic>>> _stream;

  Color get _color => widget.color ?? const Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _stream = widget.svc.obtenerMenuSemanal(widget.empresaId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: Colors.red)));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final dias = snap.data ?? [];
        final activos = dias.where((d) => d['activo'] as bool? ?? true).length;

        return Column(children: [
          _buildHeader(dias.length, activos),
          const Divider(height: 1),
          Expanded(
            child: dias.isEmpty
                ? _buildVacio()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: dias.length,
                    itemBuilder: (_, i) => _buildDiaCard(dias[i]),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _buildHeader(int total, int activos) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Menú Semanal', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: _color)),
          const Text('Gestiona el menú del día de cada jornada',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
        const Spacer(),
        if (total > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$activos activos',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981))),
          ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _abrirEditor(null),
          icon: const Icon(Icons.add_rounded, size: 15),
          label: const Text('Añadir día'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _color, foregroundColor: Colors.white,
            elevation: 0, minimumSize: const Size(0, 38),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _buildDiaCard(Map<String, dynamic> dia) {
    final id       = dia['id'] as String? ?? '';
    final nombre   = dia['dia'] as String? ?? '';
    final activo   = dia['activo'] as bool? ?? true;
    final precio   = dia['precio'];
    final primeros = (dia['primeros'] as List?)?.cast<String>() ?? [];
    final segundos = (dia['segundos'] as List?)?.cast<String>() ?? [];
    final postres  = (dia['postres'] as List?)?.cast<String>() ?? [];
    final bebida   = dia['bebida'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: activo ? const Color(0xFFE8EDF2) : const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(children: [
        // Cabecera del día
        InkWell(
          onTap: () => _abrirEditor(dia),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: activo
                      ? _color.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.restaurant_rounded, size: 20,
                    color: activo ? _color : const Color(0xFFCBD5E1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_capitalize(nombre), style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: activo ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
                  if (precio != null)
                    Text('${precio}€ · menú completo',
                        style: TextStyle(fontSize: 12,
                            color: activo ? _color : const Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w600)),
                ]),
              ),
              Switch(
                value: activo,
                activeColor: const Color(0xFF10B981),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: id.isEmpty ? null : (v) =>
                    widget.svc.toggleDiaMenuActivo(widget.empresaId, id, v),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFFCBD5E1)),
                onPressed: id.isEmpty ? null : () => _confirmarBorrar(id, nombre),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
        ),
        // Detalle de platos si hay contenido
        if ((primeros + segundos + postres).isNotEmpty) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (primeros.isNotEmpty)
                Expanded(child: _seccionPlatos('Primeros', primeros, activo)),
              if (primeros.isNotEmpty && (segundos.isNotEmpty || postres.isNotEmpty))
                const SizedBox(width: 12),
              if (segundos.isNotEmpty)
                Expanded(child: _seccionPlatos('Segundos', segundos, activo)),
              if (segundos.isNotEmpty && postres.isNotEmpty)
                const SizedBox(width: 12),
              if (postres.isNotEmpty)
                Expanded(child: _seccionPlatos('Postre', postres, activo)),
            ]),
          ),
          if (bebida.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(children: [
                Icon(Icons.local_bar_rounded, size: 13,
                    color: activo ? _color : const Color(0xFFCBD5E1)),
                const SizedBox(width: 6),
                Expanded(child: Text(bebida, style: TextStyle(
                    fontSize: 12, color: activo
                        ? const Color(0xFF475569)
                        : const Color(0xFFCBD5E1)))),
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _seccionPlatos(String titulo, List<String> platos, bool activo) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: activo ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
          letterSpacing: .5)),
      const SizedBox(height: 4),
      ...platos.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text('• $p', style: TextStyle(
            fontSize: 12,
            color: activo ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      )),
    ]);
  }

  Widget _buildVacio() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.restaurant_rounded, size: 56, color: _color.withValues(alpha: 0.2)),
      const SizedBox(height: 16),
      const Text('Sin menú semanal todavía',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
              color: Color(0xFF334155))),
      const SizedBox(height: 6),
      const Text('Añade los días de la semana con sus platos',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () => _abrirEditor(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir primer día'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]));
  }

  Future<void> _confirmarBorrar(String id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminar "$nombre"',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: const Text('Se eliminará este día del menú semanal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.svc.eliminarDiaMenu(widget.empresaId, id);
    }
  }

  void _abrirEditor(Map<String, dynamic>? dia) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditorDiaMenu(
        dia: dia,
        color: _color,
        onGuardar: (data) async {
          await widget.svc.guardarDiaMenu(widget.empresaId, data);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor de un día del menú
// ─────────────────────────────────────────────────────────────────────────────

class _EditorDiaMenu extends StatefulWidget {
  final Map<String, dynamic>? dia;
  final Color color;
  final Future<void> Function(Map<String, dynamic>) onGuardar;

  const _EditorDiaMenu({this.dia, required this.color, required this.onGuardar});

  @override
  State<_EditorDiaMenu> createState() => _EditorDiaMenuState();
}

class _EditorDiaMenuState extends State<_EditorDiaMenu> {
  String  _dia       = _kDias.first;
  final _precioCtrl  = TextEditingController();
  final _bebidaCtrl  = TextEditingController();
  final _notaCtrl    = TextEditingController();
  // Listas de platos como texto libre — un TextField por sección
  final _primerosCtrl  = TextEditingController();
  final _segundosCtrl  = TextEditingController();
  final _postresCtrl   = TextEditingController();
  bool _activo   = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dia;
    if (d != null) {
      _dia         = d['dia'] as String? ?? _kDias.first;
      _activo      = d['activo'] as bool? ?? true;
      final precio = d['precio'];
      _precioCtrl.text  = precio != null ? precio.toString() : '';
      _bebidaCtrl.text  = d['bebida'] as String? ?? '';
      _notaCtrl.text    = d['nota'] as String? ?? '';
      final primeros = (d['primeros'] as List?)?.cast<String>() ?? [];
      final segundos = (d['segundos'] as List?)?.cast<String>() ?? [];
      final postres  = (d['postres']  as List?)?.cast<String>() ?? [];
      _primerosCtrl.text = primeros.join('\n');
      _segundosCtrl.text = segundos.join('\n');
      _postresCtrl.text  = postres.join('\n');
    }
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    _bebidaCtrl.dispose();
    _notaCtrl.dispose();
    _primerosCtrl.dispose();
    _segundosCtrl.dispose();
    _postresCtrl.dispose();
    super.dispose();
  }

  List<String> _parsePlatos(String texto) =>
      texto.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Text(widget.dia == null ? 'Nuevo día de menú' : 'Editar menú',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 18),
        // Selector de día
        Row(children: [
          const Text('Día', style: TextStyle(fontSize: 13,
              color: Color(0xFF475569), fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _dia,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              items: _kDias.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(d[0].toUpperCase() + d.substring(1)))).toList(),
              onChanged: (v) { if (v != null) setState(() => _dia = v); },
            ),
          ),
          const SizedBox(width: 12),
          _field(_precioCtrl, 'Precio €',
              tipo: const TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              width: 90),
        ]),
        const SizedBox(height: 16),
        // Platos por sección
        _seccionPlatos('Primeros', _primerosCtrl,
            'Ej:\nEnsalada mixta\nGazpacho andaluz'),
        const SizedBox(height: 12),
        _seccionPlatos('Segundos', _segundosCtrl,
            'Ej:\nPollo asado con patatas\nMerluza a la plancha'),
        const SizedBox(height: 12),
        _seccionPlatos('Postre', _postresCtrl,
            'Ej:\nFlan casero\nFruta del tiempo'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bebidaCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Bebida incluida (opcional)',
            hintText: 'Ej: Agua, vino o cerveza incluida',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notaCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Nota adicional (opcional)',
            hintText: 'Ej: Menú disponible de lunes a viernes 13:00–16:00 h',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          const Text('Activo esta semana',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155))),
          const Spacer(),
          Switch(
            value: _activo,
            activeColor: const Color(0xFF10B981),
            onChanged: (v) => setState(() => _activo = v),
          ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(
              backgroundColor: widget.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _guardando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.dia == null ? 'Añadir menú' : 'Guardar cambios',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _seccionPlatos(String titulo, TextEditingController ctrl, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: widget.color)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        maxLines: 3,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          helperText: 'Un plato por línea',
          helperStyle: const TextStyle(fontSize: 10),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label, {
    TextInputType? tipo,
    List<TextInputFormatter>? formatters,
    double? width,
  }) {
    final field = TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
    return width != null ? SizedBox(width: width, child: field) : field;
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final precio = double.tryParse(
          _precioCtrl.text.replaceAll(',', '.').replaceAll('€', '').trim());
      final data = <String, dynamic>{
        if (widget.dia?['id'] != null) 'id': widget.dia!['id'],
        'dia':      _dia,
        'activo':   _activo,
        'primeros': _parsePlatos(_primerosCtrl.text),
        'segundos': _parsePlatos(_segundosCtrl.text),
        'postres':  _parsePlatos(_postresCtrl.text),
        if (_bebidaCtrl.text.trim().isNotEmpty) 'bebida': _bebidaCtrl.text.trim(),
        if (_notaCtrl.text.trim().isNotEmpty)   'nota':   _notaCtrl.text.trim(),
        if (precio != null) 'precio': precio,
        if (widget.dia?['orden'] != null) 'orden': widget.dia!['orden'],
      };
      await widget.onGuardar(data);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

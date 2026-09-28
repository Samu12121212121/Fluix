import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Buscador de clientes reutilizable para cualquier TPV.
/// Muestra un botón "Añadir cliente" cuando no hay cliente seleccionado,
/// y el nombre del cliente con opción de quitar cuando sí lo hay.
class ClienteBuscadorTpv extends StatefulWidget {
  final String empresaId;
  final String? clienteNombre;
  final String? clienteId;
  final ValueChanged<Map<String, dynamic>> onSeleccionado;
  final VoidCallback onLimpiar;
  final Color colorPrimario;
  /// Si false, no muestra la opción "Crear nuevo cliente".
  /// En el TPV solo se seleccionan clientes existentes.
  final bool permitirCrearNuevo;

  const ClienteBuscadorTpv({
    super.key,
    required this.empresaId,
    required this.onSeleccionado,
    required this.onLimpiar,
    this.clienteNombre,
    this.clienteId,
    this.colorPrimario = const Color(0xFF3B82F6),
    this.permitirCrearNuevo = false,
  });

  @override
  State<ClienteBuscadorTpv> createState() => _ClienteBuscadorTpvState();
}

class _ClienteBuscadorTpvState extends State<ClienteBuscadorTpv> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  List<Map<String, dynamic>> _todos      = [];
  List<Map<String, dynamic>> _resultados = [];
  bool _abierto       = false;
  bool _buscando      = false;
  bool _cargadoTodos  = false;
  Timer? _debounce;

  static const _kBorder = Color(0xFFE5E7EB);
  static const _kSub    = Color(0xFF6B7280);
  static const _kFg     = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        if (!_cargadoTodos) _cargarTodos();
        if (_ctrl.text.isEmpty) {
          setState(() => _resultados = List.from(_todos));
        }
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _resultados = []);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _cargarTodos() async {
    setState(() => _buscando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('clientes')
          .orderBy('nombre')
          .limit(60)
          .get();
      if (mounted) {
        final lista = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        setState(() {
          _todos = lista;
          _cargadoTodos = true;
          if (_ctrl.text.isEmpty) _resultados = List.from(lista);
          _buscando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _onChanged(String valor) {
    _debounce?.cancel();
    if (valor.isEmpty) {
      setState(() => _resultados = List.from(_todos));
      return;
    }
    final local = _todos.where((c) {
      final n = ((c['nombre'] ?? '') as String).toLowerCase();
      final t = ((c['telefono'] ?? '') as String).toLowerCase();
      final v = valor.toLowerCase();
      return n.contains(v) || t.contains(v);
    }).toList();
    setState(() => _resultados = local);

    if (local.length < 3 && valor.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        setState(() => _buscando = true);
        final q = FirebaseFirestore.instance.collection('empresas')
            .doc(widget.empresaId).collection('clientes');
        var snap = await q
            .where('nombre_lower', isGreaterThanOrEqualTo: valor.toLowerCase())
            .where('nombre_lower', isLessThan: '${valor.toLowerCase()}z')
            .limit(10).get();
        if (snap.docs.isEmpty) {
          snap = await q
              .where('nombre', isGreaterThanOrEqualTo: valor)
              .where('nombre', isLessThan: '${valor}z')
              .limit(10).get();
        }
        final remotos = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        final ids = local.map((c) => c['id']).toSet();
        if (mounted) {
          setState(() {
            _resultados = [...local, ...remotos.where((c) => !ids.contains(c['id']))];
            _buscando = false;
          });
        }
      });
    }
  }

  void _seleccionar(Map<String, dynamic> cliente) {
    widget.onSeleccionado(cliente);
    _ctrl.clear();
    setState(() { _resultados = []; _abierto = false; });
    _focus.unfocus();
  }

  Future<void> _crearNuevo(String nombre) async {
    final nombreCtrl = TextEditingController(text: nombre);
    final teleCtrl   = TextEditingController();
    final emailCtrl  = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo cliente', style: TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nombreCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre *',
                prefixIcon: Icon(Icons.person_outline, size: 16)),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: teleCtrl,
            decoration: const InputDecoration(labelText: 'Teléfono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined, size: 16)),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: 'Email (opcional)',
                prefixIcon: Icon(Icons.email_outlined, size: 16)),
            keyboardType: TextInputType.emailAddress,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nombreFinal = nombreCtrl.text.trim();
    if (nombreFinal.isEmpty) return;
    try {
      final tele  = teleCtrl.text.trim();
      final email = emailCtrl.text.trim();
      final ref = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('clientes').add({
        'nombre': nombreFinal,
        'nombre_lower': nombreFinal.toLowerCase(),
        if (tele.isNotEmpty)  'telefono': tele,
        if (email.isNotEmpty) 'correo':   email,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      final nuevoCliente = {
        'id': ref.id,
        'nombre': nombreFinal,
        if (tele.isNotEmpty)  'telefono': tele,
        if (email.isNotEmpty) 'correo':   email,
      };
      _todos = [..._todos, nuevoCliente];
      _seleccionar(nuevoCliente);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creando cliente: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Cliente ya seleccionado ──────────────────────────────────────────────
    if (widget.clienteNombre != null && !_abierto) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.colorPrimario.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.colorPrimario.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
                color: widget.colorPrimario.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: Center(child: Text(
              widget.clienteNombre![0].toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: widget.colorPrimario),
            )),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.clienteNombre!,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kFg),
              overflow: TextOverflow.ellipsis)),
          GestureDetector(
            onTap: widget.onLimpiar,
            child: Icon(Icons.close, size: 16, color: _kSub),
          ),
        ]),
      );
    }

    // ── Sin cliente — botón toggle o buscador abierto ────────────────────────
    if (!_abierto) {
      return Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _abierto = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Row(children: [
                Icon(Icons.person_search_outlined, size: 15, color: _kSub),
                const SizedBox(width: 8),
                Text('Añadir cliente', style: TextStyle(fontSize: 12, color: _kSub)),
              ]),
            ),
          ),
        ),
        if (widget.permitirCrearNuevo) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _crearNuevo(''),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.person_add_outlined, size: 15, color: Colors.green),
            ),
          ),
        ],
      ]);
    }

    // ── Buscador abierto ─────────────────────────────────────────────────────
    return Column(children: [
      TextField(
        controller: _ctrl,
        focusNode: _focus,
        autofocus: true,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar cliente…',
          hintStyle: const TextStyle(fontSize: 12, color: _kSub),
          prefixIcon: const Icon(Icons.search, size: 15, color: _kSub),
          suffixIcon: _buscando
              ? const SizedBox(width: 16, height: 16,
                  child: Padding(padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14, color: _kSub),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _resultados = List.from(_todos));
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    )
                  : IconButton(
                      icon: const Icon(Icons.close, size: 14, color: _kSub),
                      onPressed: () => setState(() { _abierto = false; _ctrl.clear(); }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.colorPrimario, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true, filled: true, fillColor: const Color(0xFFF9FAFB),
        ),
        style: const TextStyle(fontSize: 12, color: _kFg),
      ),
      if (_resultados.isNotEmpty || (_ctrl.text.length >= 2 && !_buscando)) ...[
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              ..._resultados.take(5).map((c) {
                final nombre   = c['nombre'] as String? ?? '';
                final telefono = c['telefono'] as String? ?? '';
                return InkWell(
                  onTap: () => _seleccionar(c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                            color: widget.colorPrimario.withValues(alpha: 0.12),
                            shape: BoxShape.circle),
                        child: Center(child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: widget.colorPrimario),
                        )),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nombre, style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600, color: _kFg)),
                        if (telefono.isNotEmpty)
                          Text(telefono, style: const TextStyle(fontSize: 10, color: _kSub)),
                      ])),
                    ]),
                  ),
                );
              }),
              if (_resultados.length > 5)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('+${_resultados.length - 5} más — escribe para filtrar',
                      style: const TextStyle(fontSize: 10, color: _kSub,
                          fontStyle: FontStyle.italic)),
                ),
              if (widget.permitirCrearNuevo &&
                  _ctrl.text.length >= 2 &&
                  !_resultados.any((c) => ((c['nombre'] ?? '') as String)
                      .toLowerCase() == _ctrl.text.trim().toLowerCase()))
                InkWell(
                  onTap: () => _crearNuevo(_ctrl.text.trim()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(children: [
                      Container(width: 28, height: 28,
                          decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.person_add_outlined,
                              size: 15, color: Colors.green)),
                      const SizedBox(width: 8),
                      Text('Crear "${_ctrl.text.trim()}"',
                          style: const TextStyle(fontSize: 12, color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    ]);
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado de seleccionar un cliente (existente o recién creado).
class ClienteSeleccionado {
  final String id;
  final String nombre;
  final String? telefono;
  final String? correo;

  const ClienteSeleccionado({
    required this.id,
    required this.nombre,
    this.telefono,
    this.correo,
  });
}

/// Widget reutilizable de búsqueda de clientes con opción de crear uno rápido.
/// Uso: en formularios de nueva factura, nuevo pedido, nueva cita.
class ClienteSelectorRapido extends StatefulWidget {
  final String empresaId;
  final String? valorInicial;
  final void Function(ClienteSeleccionado cliente) onSeleccionado;
  final String hint;

  const ClienteSelectorRapido({
    super.key,
    required this.empresaId,
    this.valorInicial,
    required this.onSeleccionado,
    this.hint = 'Buscar o crear cliente...',
  });

  @override
  State<ClienteSelectorRapido> createState() => _ClienteSelectorRapidoState();
}

class _ClienteSelectorRapidoState extends State<ClienteSelectorRapido> {
  late TextEditingController _ctrl;
  final _focus = FocusNode();
  List<QueryDocumentSnapshot>? _resultados;
  bool _mostrarLista = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.valorInicial);
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _mostrarLista = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _buscar(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().isEmpty) {
        setState(() {
          _resultados = null;
          _mostrarLista = false;
        });
        return;
      }

      final q = query.toLowerCase();
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .where('estado_fusionado', isEqualTo: false)
          .orderBy('nombre')
          .get();

      final filtrados = snap.docs.where((doc) {
        final d = doc.data();
        final nombre = (d['nombre'] ?? '').toString().toLowerCase();
        final tel = (d['telefono'] ?? '').toString().toLowerCase();
        final correo = (d['correo'] ?? '').toString().toLowerCase();
        return nombre.contains(q) || tel.contains(q) || correo.contains(q);
      }).toList();

      if (mounted) {
        setState(() {
          _resultados = filtrados;
          _mostrarLista = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _buscar,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.person_search, size: 20),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {
                        _resultados = null;
                        _mostrarLista = false;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF00796B)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (_mostrarLista && _resultados != null) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                // Resultados existentes
                ..._resultados!.take(5).map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          const Color(0xFF00796B).withValues(alpha: 0.1),
                      child: Text(
                        ((d['nombre'] ?? 'C') as String)[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF00796B),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      d['nombre'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      d['telefono'] ?? d['correo'] ?? '',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    onTap: () {
                      final sel = ClienteSeleccionado(
                        id: doc.id,
                        nombre: d['nombre'] ?? '',
                        telefono: d['telefono'],
                        correo: d['correo'],
                      );
                      _ctrl.text = sel.nombre;
                      setState(() => _mostrarLista = false);
                      widget.onSeleccionado(sel);
                    },
                  );
                }),

                // Opción crear rápido
                if (_ctrl.text.trim().isNotEmpty)
                  ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF00796B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_add,
                          size: 16, color: Color(0xFF00796B)),
                    ),
                    title: Text(
                      'Crear "${_ctrl.text.trim()}" rápido',
                      style: const TextStyle(
                        color: Color(0xFF00796B),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Solo nombre, teléfono y email',
                      style: TextStyle(fontSize: 10),
                    ),
                    onTap: () => _abrirCreacionRapida(context),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _abrirCreacionRapida(BuildContext context) {
    setState(() => _mostrarLista = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrearClienteRapidoSheet(
        empresaId: widget.empresaId,
        nombreInicial: _ctrl.text.trim(),
        onCreado: (cliente) {
          _ctrl.text = cliente.nombre;
          widget.onSeleccionado(cliente);
        },
      ),
    );
  }
}

// ── BOTTOM SHEET CREAR CLIENTE RÁPIDO ─────────────────────────────────────────

class CrearClienteRapidoSheet extends StatefulWidget {
  final String empresaId;
  final String nombreInicial;
  final void Function(ClienteSeleccionado cliente) onCreado;

  const CrearClienteRapidoSheet({
    super.key,
    required this.empresaId,
    required this.nombreInicial,
    required this.onCreado,
  });

  @override
  State<CrearClienteRapidoSheet> createState() =>
      _CrearClienteRapidoSheetState();
}

class _CrearClienteRapidoSheetState extends State<CrearClienteRapidoSheet> {
  late TextEditingController _nombreCtrl;
  final _telCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreInicial);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes');

      final doc = await ref.add({
        'nombre': _nombreCtrl.text.trim(),
        'telefono': _telCtrl.text.trim(),
        'correo': _correoCtrl.text.trim(),
        'direccion': '',
        'localidad': '',
        'notas': '',
        'etiquetas': <String>[],
        'activo': true,
        'total_gastado': 0.0,
        'numero_reservas': 0,
        'fecha_registro': DateTime.now().toIso8601String(),
        'estado_cliente': 'contacto',
        'ficha_incompleta': true,
        'no_contactar': false,
        'estado_fusionado': false,
      });

      final cliente = ClienteSeleccionado(
        id: doc.id,
        nombre: _nombreCtrl.text.trim(),
        telefono: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        correo:
            _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCreado(cliente);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cliente creado rápidamente'),
            backgroundColor: Color(0xFF00796B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add,
                      color: Color(0xFF00796B), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente rápido',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Solo datos mínimos — completa la ficha después',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nombreCtrl,
              autofocus: true,
              decoration: _deco('Nombre *', Icons.person),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telCtrl,
              decoration: _deco('Teléfono', Icons.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _correoCtrl,
              decoration: _deco('Email', Icons.email),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _guardando ? 'Creando...' : 'Crear y seleccionar',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00796B)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}


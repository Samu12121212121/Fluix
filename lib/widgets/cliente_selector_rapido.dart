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
  List<QueryDocumentSnapshot> _todosClientes = [];
  List<QueryDocumentSnapshot>? _resultados;
  bool _mostrarLista = false;
  bool _cargandoClientes = false;
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
      } else {
        // Al recibir foco, cargar clientes y mostrar lista
        _cargarTodosClientes();
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

  Future<void> _cargarTodosClientes() async {
    if (_todosClientes.isNotEmpty) {
      // Ya están cargados, solo mostrar
      setState(() {
        _resultados = _todosClientes;
        _mostrarLista = true;
      });
      return;
    }

    setState(() => _cargandoClientes = true);
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .where('estado_fusionado', isEqualTo: false)
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .limit(100)
          .get();

      if (mounted) {
        setState(() {
          _todosClientes = snap.docs;
          _resultados = snap.docs;
          _mostrarLista = true;
          _cargandoClientes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoClientes = false);
      }
    }
  }

  void _buscar(String query) {
    _debounce?.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _resultados = _todosClientes;
        _mostrarLista = _todosClientes.isNotEmpty;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final q = query.toLowerCase();
      
      // Si ya tenemos clientes cargados, filtrar localmente
      if (_todosClientes.isNotEmpty) {
        final filtrados = _todosClientes.where((doc) {

          final d = doc.data() as Map<String, dynamic>;
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
      } else {
        // Si no hay clientes cargados, buscar en Firestore
        final snap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('clientes')
            .where('estado_fusionado', isEqualTo: false)
            .where('activo', isEqualTo: true)
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            _focus.requestFocus();
            if (!_mostrarLista) {
              _cargarTodosClientes();
            }
          },
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: _buscar,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.person_search, size: 20),
              suffixIcon: _cargandoClientes
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_ctrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() {
                                _resultados = _todosClientes;
                                _mostrarLista = _todosClientes.isNotEmpty;
                              });
                            },
                          ),
                        Icon(
                          _mostrarLista
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
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
        ),
        if (_mostrarLista && _resultados != null) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00796B).withOpacity(0.2)),
              ),
              child: _resultados!.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_off, size: 32, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No se encontraron clientes',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          if (_ctrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _abrirCreacionRapida(context),
                              icon: const Icon(Icons.person_add, size: 16),
                              label: const Text('Crear nuevo cliente'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00796B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        // Encabezado con contador
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            '${_resultados!.length} cliente${_resultados!.length != 1 ? 's' : ''} disponible${_resultados!.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Divider(height: 8),
                        
                        // Lista de clientes
                        ..._resultados!.take(20).map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final nombre = d['nombre'] ?? '';
                          final telefono = d['telefono'] ?? '';
                          final correo = d['correo'] ?? '';
                          final iniciales = nombre.isNotEmpty
                              ? (nombre.split(' ').take(2).map((n) => n[0]).join()).toUpperCase()
                              : 'C';
                          
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  const Color(0xFF00796B).withValues(alpha: 0.1),
                              child: Text(
                                iniciales,
                                style: const TextStyle(
                                  color: Color(0xFF00796B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: telefono.isNotEmpty || correo.isNotEmpty
                                ? Text(
                                    telefono.isNotEmpty ? telefono : correo,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                : null,
                            trailing: const Icon(Icons.check_circle_outline,
                                size: 18, color: Color(0xFF00796B)),
                            onTap: () {
                              final sel = ClienteSeleccionado(
                                id: doc.id,
                                nombre: nombre,
                                telefono: telefono.isEmpty ? null : telefono,
                                correo: correo.isEmpty ? null : correo,
                              );
                              _ctrl.text = sel.nombre;
                              setState(() => _mostrarLista = false);
                              widget.onSeleccionado(sel);
                            },
                          );
                        }),

                        // Opción crear rápido
                        if (_ctrl.text.trim().isNotEmpty) ...[
                          const Divider(height: 8),
                          ListTile(
                            dense: true,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF00796B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person_add,
                                  size: 18, color: Color(0xFF00796B)),
                            ),
                            title: Text(
                              'Crear "${_ctrl.text.trim()}"',
                              style: const TextStyle(
                                color: Color(0xFF00796B),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: const Text(
                              'Clic para crear nuevo cliente',
                              style: TextStyle(fontSize: 10),
                            ),
                            onTap: () => _abrirCreacionRapida(context),
                          ),
                        ],
                      ],
                    ),
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


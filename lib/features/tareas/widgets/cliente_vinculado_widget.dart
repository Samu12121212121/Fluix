import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Chip que muestra el cliente vinculado a una tarea con navegación directa.
class ClienteVinculadoWidget extends StatelessWidget {
  final String empresaId;
  final String clienteId;
  final VoidCallback? onTap;

  const ClienteVinculadoWidget({
    super.key,
    required this.empresaId,
    required this.clienteId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .doc(clienteId)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 32,
            width: 100,
            child: Center(child: LinearProgressIndicator()),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final nombre = data['nombre'] as String? ?? 'Cliente';

        return ActionChip(
          avatar: const CircleAvatar(
            backgroundColor: Color(0xFF00796B),
            radius: 12,
            child: Icon(Icons.person, color: Colors.white, size: 14),
          ),
          label: Text(
            nombre,
            style: const TextStyle(
                color: Color(0xFF00796B), fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.08),
          side: const BorderSide(color: Color(0xFF00796B)),
          onPressed: onTap,
          tooltip: 'Ver ficha del cliente',
        );
      },
    );
  }
}

/// Widget rápido de selección de cliente para el formulario.
class SelectorClienteWidget extends StatefulWidget {
  final String empresaId;
  final String? clienteIdSeleccionado;
  final ValueChanged<String?> onChanged;

  const SelectorClienteWidget({
    super.key,
    required this.empresaId,
    required this.clienteIdSeleccionado,
    required this.onChanged,
  });

  @override
  State<SelectorClienteWidget> createState() => _SelectorClienteWidgetState();
}

class _SelectorClienteWidgetState extends State<SelectorClienteWidget> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    if (widget.clienteIdSeleccionado != null) {
      return Row(
        children: [
          Expanded(
            child: ClienteVinculadoWidget(
              empresaId: widget.empresaId,
              clienteId: widget.clienteIdSeleccionado!,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
            onPressed: () => widget.onChanged(null),
            tooltip: 'Desvincular cliente',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar y vincular cliente...',
            prefixIcon: const Icon(Icons.person_search),
            isDense: true,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => _busqueda = v.toLowerCase().trim()),
        ),
        if (_busqueda.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildResultados(),
        ],
      ],
    );
  }

  Widget _buildResultados() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .orderBy('nombre')
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return (d['nombre'] ?? '').toString().toLowerCase().contains(_busqueda) ||
              (d['telefono'] ?? '').toString().contains(_busqueda);
        }).toList();

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Sin resultados para "$_busqueda"',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          );
        }

        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                dense: true,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF00796B),
                  radius: 16,
                  child: Icon(Icons.person, color: Colors.white, size: 16),
                ),
                title: Text(d['nombre'] ?? '', style: const TextStyle(fontSize: 13)),
                subtitle: Text(d['telefono'] ?? '',
                    style: const TextStyle(fontSize: 11)),
                onTap: () {
                  setState(() => _busqueda = '');
                  widget.onChanged(docs[i].id);
                },
              );
            },
          ),
        );
      },
    );
  }
}



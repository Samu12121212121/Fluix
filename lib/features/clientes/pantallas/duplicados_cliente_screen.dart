import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/fusion_clientes_service.dart';

/// Pantalla para detectar y fusionar clientes duplicados.
class DuplicadosClienteScreen extends StatefulWidget {
  final String empresaId;
  const DuplicadosClienteScreen({super.key, required this.empresaId});

  @override
  State<DuplicadosClienteScreen> createState() =>
      _DuplicadosClienteScreenState();
}

class _DuplicadosClienteScreenState extends State<DuplicadosClienteScreen> {
  final _svc = FusionClientesService();
  final _db = FirebaseFirestore.instance;
  bool _cargando = true;
  // clienteId → List<DuplicadoDetectado>
  final Map<String, List<DuplicadoDetectado>> _duplicados = {};
  List<QueryDocumentSnapshot>? _clientes;

  @override
  void initState() {
    super.initState();
    _escanear();
  }

  Future<void> _escanear() async {
    setState(() {
      _cargando = true;
      _duplicados.clear();
    });

    final snap = await _db
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('clientes')
        .where('estado_fusionado', isEqualTo: false)
        .get();

    _clientes = snap.docs;

    // Buscar duplicados para cada cliente
    final procesados = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final dups = await _svc.buscarDuplicados(
        empresaId: widget.empresaId,
        clienteId: doc.id,
        clienteData: data,
      );

      // Filtrar duplicados ya procesados (evitar A↔B duplicado)
      final dupsFiltrados = dups
          .where((d) => !procesados.contains(d.clienteId))
          .toList();

      if (dupsFiltrados.isNotEmpty) {
        _duplicados[doc.id] = dupsFiltrados;
      }
      procesados.add(doc.id);
    }

    if (mounted) setState(() => _cargando = false);
  }

  String _nombreCliente(String id) {
    final doc = _clientes?.firstWhere(
      (d) => d.id == id,
      orElse: () => _clientes!.first,
    );
    return (doc?.data() as Map<String, dynamic>?)?['nombre'] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Detección de duplicados'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-escanear',
            onPressed: _escanear,
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Escaneando clientes...'),
                ],
              ),
            )
          : _duplicados.isEmpty
              ? _buildSinDuplicados()
              : _buildResultados(),
    );
  }

  Widget _buildSinDuplicados() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user, size: 64, color: Colors.green[300]),
          const SizedBox(height: 16),
          Text(
            'No se detectaron duplicados',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu base de clientes está limpia 🎉',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    final entries = _duplicados.entries.toList();
    final totalPares =
        entries.fold(0, (s, e) => s + e.value.length);

    return Column(
      children: [
        // Resumen
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFFE57373)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.content_copy, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalPares posible${totalPares != 1 ? 's' : ''} duplicado${totalPares != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'en ${entries.length} cliente${entries.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final principal = entries[i].key;
              final dups = entries[i].value;
              return _buildGrupoDuplicados(principal, dups);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGrupoDuplicados(
    String principalId,
    List<DuplicadoDetectado> duplicados,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre del principal
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Color(0xFF0D47A1)),
                const SizedBox(width: 6),
                Text(
                  _nombreCliente(principalId),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PRINCIPAL',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Duplicados encontrados
            ...duplicados.map((dup) {
              final confianzaPct = (dup.confianza * 100).toInt();
              final color = dup.confianza >= 0.8
                  ? const Color(0xFFD32F2F)
                  : dup.confianza >= 0.5
                      ? const Color(0xFFF57C00)
                      : const Color(0xFF607D8B);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dup.data['nombre'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$confianzaPct% coincidencia',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...dup.motivos.map((m) => Row(
                          children: [
                            Icon(Icons.arrow_right,
                                size: 14, color: Colors.grey[500]),
                            Expanded(
                              child: Text(
                                m,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        )),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _confirmarFusion(principalId, dup),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00796B),
                          ),
                          child: const Text(
                            'Fusionar →',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarFusion(
    String principalId,
    DuplicadoDetectado dup,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar fusión'),
        content: Text(
          '¿Fusionar "${dup.data['nombre']}" en "${_nombreCliente(principalId)}"?\n\n'
          'Se transferirán facturas, citas, pedidos y etiquetas.\n'
          'El duplicado quedará oculto (reversible 30 días).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
            ),
            child: const Text('Fusionar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _svc.fusionar(
          empresaId: widget.empresaId,
          principalId: principalId,
          duplicadoId: dup.clienteId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Clientes fusionados correctamente'),
              backgroundColor: Color(0xFF00796B),
            ),
          );
          _escanear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}


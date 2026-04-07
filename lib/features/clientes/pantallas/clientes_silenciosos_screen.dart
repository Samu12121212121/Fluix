import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/cliente_estado_service.dart';

/// Pantalla que muestra la lista de clientes sin actividad reciente.
/// Ordenados por días de inactividad (el más antiguo primero).
class ClientesSilenciososScreen extends StatefulWidget {
  final String empresaId;
  const ClientesSilenciososScreen({super.key, required this.empresaId});

  @override
  State<ClientesSilenciososScreen> createState() =>
      _ClientesSilenciososScreenState();
}

class _ClientesSilenciososScreenState extends State<ClientesSilenciososScreen> {
  final _svc = ClienteEstadoService();
  List<Map<String, dynamic>>? _clientes;
  bool _cargando = true;
  int _umbral = 60;
  static final _fmtEur = NumberFormat.currency(locale: 'es_ES', symbol: '€');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    _umbral = await _svc.obtenerUmbralInactividad(widget.empresaId);
    final clientes = await _svc.obtenerClientesSilenciosos(widget.empresaId);
    if (mounted) {
      setState(() {
        _clientes = clientes;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Clientes silenciosos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurar umbral',
            onPressed: _configurarUmbral,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _clientes == null || _clientes!.isEmpty
              ? _buildVacio()
              : Column(
                  children: [
                    // Resumen
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF57C00), Color(0xFFFF9800)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_clientes!.length} cliente${_clientes!.length != 1 ? 's' : ''} sin actividad',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'en más de $_umbral días',
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
                      child: RefreshIndicator(
                        onRefresh: _cargar,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _clientes!.length,
                          itemBuilder: (ctx, i) =>
                              _buildTarjeta(_clientes![i]),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTarjeta(Map<String, dynamic> c) {
    final dias = c['dias_inactivo'] as int;
    final totalGastado = ((c['total_gastado'] ?? 0) as num).toDouble();
    final nombre = c['nombre'] ?? '';
    final iniciales = nombre.isNotEmpty
        ? nombre.split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'C';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF57C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  iniciales,
                  style: const TextStyle(
                    color: Color(0xFFF57C00),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text(
                        '$dias días sin actividad',
                        style: TextStyle(
                          fontSize: 12,
                          color: dias > 180
                              ? Colors.red
                              : Colors.grey[600],
                          fontWeight: dias > 180
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (totalGastado > 0)
                    Text(
                      'Facturado: ${_fmtEur.format(totalGastado)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            // Acciones
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'no_contactar',
                  child: Row(
                    children: [
                      Icon(Icons.do_not_disturb, size: 16),
                      SizedBox(width: 8),
                      Text('No contactar'),
                    ],
                  ),
                ),
              ],
              onSelected: (v) async {
                if (v == 'no_contactar') {
                  await _marcarNoContactar(c['id']);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _marcarNoContactar(String clienteId) async {
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .doc(clienteId)
          .update({'no_contactar': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Marcado como "No contactar"'),
            backgroundColor: Color(0xFF00796B),
          ),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '¡Sin clientes silenciosos!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Todos tus clientes han tenido actividad\nen los últimos $_umbral días.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _configurarUmbral() async {
    int nuevo = _umbral;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Umbral de inactividad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Clientes sin actividad en más de $nuevo días aparecerán aquí.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              Slider(
                value: nuevo.toDouble(),
                min: 30,
                max: 180,
                divisions: 15,
                label: '$nuevo días',
                activeColor: const Color(0xFF00796B),
                onChanged: (v) => setS(() => nuevo = v.round()),
              ),
              Text(
                '$nuevo días',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, nuevo),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
              ),
              child:
                  const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _svc.guardarUmbralInactividad(widget.empresaId, result);
      _cargar();
    }
  }
}




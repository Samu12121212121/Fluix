import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/mod_347_service.dart';
import '../../../services/exportadores_aeat/mod_347_exporter.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA MODELO 347 — Operaciones con terceros > 3.005,06 €
// Declaración informativa anual. Plazo: febrero del año siguiente.
// ═════════════════════════════════════════════════════════════════════════════

class Modelo347Screen extends StatefulWidget {
  final String empresaId;
  final int? anioInicial;

  const Modelo347Screen({
    super.key,
    required this.empresaId,
    this.anioInicial,
  });

  @override
  State<Modelo347Screen> createState() => _Modelo347ScreenState();
}

class _Modelo347ScreenState extends State<Modelo347Screen>
    with SingleTickerProviderStateMixin {
  final _svc = Mod347Service();
  final _db = FirebaseFirestore.instance;
  late int _anio;
  bool _procesando = false;
  Resumen347? _resumen;
  String _nifEmpresa = '';
  String _nombreEmpresa = '';

  late TabController _tabController;

  static const double _umbral = 3005.06;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _anio = widget.anioInicial ?? DateTime.now().year - 1;
    _cargarEmpresa();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarEmpresa() async {
    final doc = await _db.collection('empresas').doc(widget.empresaId).get();
    final data = doc.data() ?? {};
    final perfil = data['perfil'] as Map<String, dynamic>? ?? {};
    final fiscal = data['datos_fiscales'] as Map<String, dynamic>? ?? {};
    if (mounted) {
      setState(() {
        _nifEmpresa = (fiscal['nif'] ?? fiscal['cif'] ?? '').toString();
        _nombreEmpresa = (perfil['nombre'] ?? data['nombre'] ?? '').toString();
      });
    }
  }

  Future<void> _calcular() async {
    setState(() => _procesando = true);
    try {
      final resumen = await _svc.calcular(widget.empresaId, _anio);

      // Guardar en Firestore para auditoría
      await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('modelos_fiscales')
          .doc('347_${_anio}')
          .set({
        'modelo': '347',
        'ejercicio': _anio,
        'num_declaraciones': resumen.numDeclaraciones,
        'importe_total': resumen.totalVentas + resumen.totalCompras,
        'umbral': _umbral,
        'num_ventas': resumen.operacionesVenta.length,
        'num_compras': resumen.operacionesCompra.length,
        'fecha_calculo': FieldValue.serverTimestamp(),
        'estado': 'calculado',
      }, SetOptions(merge: true));

      setState(() => _resumen = resumen);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✅ Modelo 347 $_anio calculado — '
            '${resumen.numDeclaraciones} operadores declarables — '
            '${NumberFormat('#,##0.00', 'es').format(resumen.totalVentas + resumen.totalCompras)} €',
          ),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() => _procesando = false);
    }
  }

  Future<void> _descargarFichero() async {
    if (_nifEmpresa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Configura el NIF de la empresa antes de exportar'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    await _svc.descargarFichero(
      empresaId: widget.empresaId,
      nifDeclarante: _nifEmpresa,
      nombreDeclarante: _nombreEmpresa,
      anio: _anio,
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ $e'),
            backgroundColor: Colors.red,
          ));
        }
      },
      onSuccess: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Fichero 347 descargado'),
            backgroundColor: Colors.green,
          ));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modelo 347 — Operaciones con terceros'),
        bottom: _resumen != null
            ? TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Ventas (${_resumen!.operacionesVenta.length})'),
                  Tab(text: 'Compras (${_resumen!.operacionesCompra.length})'),
                ],
              )
            : null,
        actions: [
          if (_resumen != null && _resumen!.numDeclaraciones > 0)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Descargar fichero AEAT',
              onPressed: _descargarFichero,
            ),
        ],
      ),
      body: _resumen != null
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildLista(_resumen!.operacionesVenta, 'cliente'),
                _buildLista(_resumen!.operacionesCompra, 'proveedor'),
              ],
            )
          : _buildContenidoInicial(),
    );
  }

  Widget _buildContenidoInicial() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEjercicioSelector(),
        const SizedBox(height: 16),
        _buildNota(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _procesando ? null : _calcular,
          icon: _procesando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.calculate),
          label: Text(
            _procesando ? 'Calculando...' : 'Calcular Modelo 347 — $_anio',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildEjercicioSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('Ejercicio:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            DropdownButton<int>(
              value: _anio,
              items: List.generate(5, (i) {
                final y = DateTime.now().year - i;
                return DropdownMenuItem(value: y, child: Text('$y'));
              }),
              onChanged: _procesando
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() {
                          _anio = v;
                          _resumen = null;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNota() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Umbral: 3.005,06 €. Se declaran clientes y proveedores cuya suma anual '
              '(con IVA) supere dicho umbral. Plazo: del 1 al 28 de febrero del año siguiente.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(List<Operacion347> ops, String tipo) {
    if (ops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 48, color: Colors.green[400]),
              const SizedBox(height: 12),
              Text(
                tipo == 'cliente'
                    ? 'Ningún cliente supera el umbral de 3.005,06 €'
                    : 'Ningún proveedor supera el umbral de 3.005,06 €',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final fmt = NumberFormat('#,##0.00', 'es');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ops.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) return _buildResumenCard(ops);
        final op = ops[i - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  tipo == 'cliente' ? Colors.green[100] : Colors.orange[100],
              child: Icon(
                tipo == 'cliente' ? Icons.arrow_upward : Icons.arrow_downward,
                color: tipo == 'cliente' ? Colors.green : Colors.orange,
                size: 18,
              ),
            ),
            title: Text(op.nombreTercero,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('NIF: ${op.nifTercero}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${fmt.format(op.totalAnual)} €',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'Clave ${op.clave.codigo}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResumenCard(List<Operacion347> ops) {
    final fmt = NumberFormat('#,##0.00', 'es');
    final total = ops.fold(0.0, (s, o) => s + o.totalAnual);
    return Card(
      color: Colors.grey[100],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${ops.length} declarados',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${fmt.format(total)} €',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}







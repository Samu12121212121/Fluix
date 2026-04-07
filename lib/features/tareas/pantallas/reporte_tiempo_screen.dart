import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/tiempo_tarea_service.dart';
import '../../../domain/modelos/tarea.dart';
import '../../../services/tareas_service.dart';

/// Pantalla de reporte de tiempo para el propietario.
class ReporteTiempoScreen extends StatefulWidget {
  final String empresaId;

  const ReporteTiempoScreen({super.key, required this.empresaId});

  @override
  State<ReporteTiempoScreen> createState() => _ReporteTiempoScreenState();
}

class _ReporteTiempoScreenState extends State<ReporteTiempoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final TiempoTareaService _svc = TiempoTareaService();
  final TareasService _tareasSvc = TareasService();

  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();
  bool _cargando = false;
  Map<String, int> _porEmpleado = {};
  List<MapEntry<String, int>> _rankingTareas = [];
  List<Tarea> _todasTareas = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final empleado = await _svc.reportePorEmpleado(
        empresaId: widget.empresaId,
        desde: _desde,
        hasta: _hasta,
      );
      final ranking = await _svc.rankingTareasPorTiempo(
        empresaId: widget.empresaId,
      );
      final tareas =
          await _tareasSvc.tareasStream(widget.empresaId).first;
      setState(() {
        _porEmpleado = empleado;
        _rankingTareas = ranking;
        _todasTareas = tareas;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Reporte de tiempo'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _seleccionarPeriodo,
            tooltip: 'Período',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people, size: 18), text: 'Por empleado'),
            Tab(icon: Icon(Icons.task, size: 18), text: 'Por tarea'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPeriodoBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildTabEmpleados(),
                      _buildTabTareas(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPeriodoBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '${DateFormat('dd/MM/yyyy').format(_desde)} — ${DateFormat('dd/MM/yyyy').format(_hasta)}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const Spacer(),
          TextButton(
            onPressed: _seleccionarPeriodo,
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabEmpleados() {
    if (_porEmpleado.isEmpty) {
      return _vacio('Sin registros en el período seleccionado');
    }

    final total =
        _porEmpleado.values.fold<int>(0, (sum, v) => sum + v);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cardResumen(total),
        const SizedBox(height: 16),
        ..._porEmpleado.entries.map((e) => _tarjetaEmpleado(e.key, e.value, total)),
      ],
    );
  }

  Widget _buildTabTareas() {
    if (_rankingTareas.isEmpty) {
      return _vacio('Sin registros de tiempo en tareas');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _rankingTareas.take(20).map((e) {
        final tarea = _todasTareas.where((t) => t.id == e.key).firstOrNull;
        return _tarjetaTarea(tarea?.titulo ?? e.key, e.value);
      }).toList(),
    );
  }

  Widget _cardResumen(int totalSegundos) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF1976D2), size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total período',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  _formatDuracion(totalSegundos),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEmpleado(String usuarioId, int segundos, int total) {
    final porcentaje = total > 0 ? segundos / total : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF1976D2),
                  radius: 16,
                  child: Icon(Icons.person, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(usuarioId)
                        .get(),
                    builder: (_, snap) {
                      final nombre = snap.data?.get('nombre') as String? ??
                          usuarioId.substring(0, 8);
                      return Text(nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600));
                    },
                  ),
                ),
                Text(_formatDuracion(segundos),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2))),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: porcentaje,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF1976D2)),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            Text('${(porcentaje * 100).toStringAsFixed(1)}% del total',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaTarea(String titulo, int segundos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF5F7FA),
          child: Icon(Icons.task_alt, color: Color(0xFF1976D2)),
        ),
        title: Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: Text(
          _formatDuracion(segundos),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
        ),
      ),
    );
  }

  Widget _vacio(String mensaje) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(mensaje, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Future<void> _seleccionarPeriodo() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
    );
    if (rango != null) {
      setState(() {
        _desde = rango.start;
        _hasta = rango.end;
      });
      await _cargar();
    }
  }

  String _formatDuracion(int seg) {
    final h = seg ~/ 3600;
    final m = (seg % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}


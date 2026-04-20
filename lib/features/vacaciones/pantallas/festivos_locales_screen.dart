import 'package:flutter/material.dart';
import '../../../models/festivo_model.dart';
import '../../../services/festivos_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE FESTIVOS LOCALES — CRUD manual para festivos de municipio
// ═══════════════════════════════════════════════════════════════════════════════

class FestivosLocalesScreen extends StatefulWidget {
  final String empresaId;
  const FestivosLocalesScreen({super.key, required this.empresaId});

  @override
  State<FestivosLocalesScreen> createState() => _FestivosLocalesScreenState();
}

class _FestivosLocalesScreenState extends State<FestivosLocalesScreen> {
  final FestivosService _svc = FestivosService();
  int _anioSeleccionado = DateTime.now().year;
  List<Festivo> _festivos = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final festivos =
          await _svc.obtenerFestivos(widget.empresaId, _anioSeleccionado);
      if (mounted) {
        setState(() {
          _festivos = festivos
            ..sort((a, b) => a.fecha.compareTo(b.fecha));
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _importarDesdeAPI() async {
    setState(() => _cargando = true);
    final comunidad =
        await _svc.obtenerComunidadAutonoma(widget.empresaId);
    final count = await _svc.importarFestivosDesdeAPI(
      widget.empresaId,
      _anioSeleccionado,
      codigoComunidad: comunidad,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$count festivos importados para $_anioSeleccionado'),
            backgroundColor: Colors.green),
      );
      _cargar();
    }
  }

  Future<void> _anadirFestivoLocal() async {
    DateTime? fecha;
    final nombreCtrl = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Añadir festivo local'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del festivo',
                  hintText: 'Ej: Fiestas patronales',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  fecha != null
                      ? '${fecha!.day.toString().padLeft(2, '0')}/${fecha!.month.toString().padLeft(2, '0')}/${fecha!.year}'
                      : 'Seleccionar fecha',
                  style: TextStyle(
                      color: fecha != null ? Colors.black87 : Colors.grey),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime(_anioSeleccionado, 1, 1),
                    firstDate: DateTime(_anioSeleccionado, 1, 1),
                    lastDate: DateTime(_anioSeleccionado, 12, 31),
                    locale: const Locale('es', 'ES'),
                  );
                  if (picked != null) {
                    setDialogState(() => fecha = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: fecha != null && nombreCtrl.text.isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true && fecha != null && nombreCtrl.text.isNotEmpty) {
      await _svc.anadirFestivoLocal(
        widget.empresaId,
        fecha!,
        nombreCtrl.text,
      );
      _cargar();
    }
    nombreCtrl.dispose();
  }

  Future<void> _eliminarFestivoLocal(Festivo festivo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar festivo local'),
        content: Text('¿Eliminar "${festivo.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _svc.eliminarFestivoLocal(widget.empresaId, festivo.fecha);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Festivos'),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Importar desde API',
            onPressed: _importarDesdeAPI,
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de año
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() => _anioSeleccionado--);
                    _cargar();
                  },
                ),
                Text(
                  '$_anioSeleccionado',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() => _anioSeleccionado++);
                    _cargar();
                  },
                ),
              ],
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildChip(
                  'Nacionales',
                  _festivos.where((f) => f.tipo == TipoFestivo.nacional).length,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildChip(
                  'Autonómicos',
                  _festivos.where((f) => f.tipo == TipoFestivo.autonomico).length,
                  Colors.teal,
                ),
                const SizedBox(width: 8),
                _buildChip(
                  'Locales',
                  _festivos.where((f) => f.tipo == TipoFestivo.local).length,
                  Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else if (_festivos.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No hay festivos para $_anioSeleccionado',
                        style: TextStyle(color: Colors.grey[500])),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _importarDesdeAPI,
                      icon: const Icon(Icons.download),
                      label: const Text('Importar festivos'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _festivos.length,
                itemBuilder: (_, i) => _buildFestivoTile(_festivos[i]),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_festivo_local',
        onPressed: _anadirFestivoLocal,
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFestivoTile(Festivo f) {
    final color = f.tipo == TipoFestivo.nacional
        ? Colors.blue
        : f.tipo == TipoFestivo.autonomico
            ? Colors.teal
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${f.fecha.day}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 16),
            ),
          ),
        ),
        title: Text(f.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${_formatFecha(f.fecha)} · ${_etiquetaTipo(f.tipo)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: f.esLocal
            ? IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: () => _eliminarFestivoLocal(f),
              )
            : null,
      ),
    );
  }

  Widget _buildChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  String _etiquetaTipo(TipoFestivo tipo) {
    switch (tipo) {
      case TipoFestivo.nacional:
        return 'Nacional';
      case TipoFestivo.autonomico:
        return 'Autonómico';
      case TipoFestivo.local:
        return 'Local';
    }
  }

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}


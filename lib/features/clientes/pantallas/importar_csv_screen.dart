import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/modelos/cliente_importado_model.dart';
import '../../../services/importacion_clientes_service.dart';

class ImportarCsvScreen extends StatefulWidget {
  final String empresaId;
  const ImportarCsvScreen({super.key, required this.empresaId});

  @override
  State<ImportarCsvScreen> createState() => _ImportarCsvScreenState();
}

class _ImportarCsvScreenState extends State<ImportarCsvScreen> {
  final _service = ImportacionClientesService();
  int _pasoActual = 0;
  
  // Estado Paso 1
  bool _analizando = false;
  String? _errorAnalisis;

  // Estado Paso 2
  ResultadoPreview? _preview;
  
  // Estado Paso 3
  bool _importando = false; // ignore: unused_field
  double _progreso = 0.0;
  bool _completado = false;

  // ── PASO 0: SELECCIÓN ───────────────────────────────────────────────────────

  Future<void> _seleccionarArchivo() async {
    setState(() {
      _errorAnalisis = null;
      _analizando = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 5 * 1024 * 1024) { // 5MB
          throw Exception('El archivo es demasiado grande (Máx 5MB)');
        }

        final bytes = file.bytes;
        if (bytes == null) throw Exception('No se pudo leer el archivo');

        // Procesar inmediatamente
        final preview = await _service.procesarCSV(bytes, widget.empresaId);
        
        setState(() {
          _preview = preview;
          _pasoActual = 1; // Avanzar a preview
          _analizando = false;
        });
      } else {
        setState(() => _analizando = false);
      }
    } catch (e) {
      setState(() {
        _errorAnalisis = e.toString();
        _analizando = false;
      });
    }
  }

  // ── PASO 1: UI ──────────────────────────────────────────────────────────────

  Widget _buildPasoSeleccion() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          const Text(
            'Sube tu lista de clientes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Formato admitido: CSV o TXT\nColumnas requeridas: Nombre, NIF',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          if (_analizando)
            const CircularProgressIndicator()
          else
            ElevatedButton.icon(
              onPressed: _seleccionarArchivo,
              icon: const Icon(Icons.folder_open),
              label: const Text('Seleccionar archivo'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            
          if (_errorAnalisis != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorAnalisis!,
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildPasoPreview() {
    if (_preview == null) return const SizedBox();
    
    final validos = _preview!.validos.length;
    final errores = _preview!.conErrores.length;
    final nuevos = _preview!.totalNuevos;
    final updates = _preview!.totalActualizaciones;
    final warnings = _preview!.totalWarnings;

    return Column(
      children: [
        // Resumen
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem('Leídos', '${validos + errores}', Colors.black),
                  _StatItem('Importables', '$validos', Colors.green),
                  _StatItem('Errores', '$errores', Colors.red),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(child: _InfoChip(Icons.add_circle, '$nuevos Nuevos', Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoChip(Icons.refresh, '$updates Actualizaciones', Colors.orange)),
                ],
              ),
              if (warnings > 0) ...[
                const SizedBox(height: 8),
                _InfoChip(Icons.warning_amber, '$warnings Warnings (se importarán)', Colors.amber[800]!),
              ],
            ],
          ),
        ),

        // Lista de Errores (si hay)
        if (errores > 0)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const Text('❌ Filas con errores (se omitirán):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                ..._preview!.conErrores.map((c) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error, color: Colors.red),
                    title: Text(c.nombre.isEmpty ? 'Sin nombre' : c.nombre),
                    subtitle: Text(c.motivosError),
                    dense: true,
                  ),
                )),
              ],
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const Text('✅ Vista previa (primeros 50):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._preview!.validos.take(50).map((c) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(c.nombre),
                  subtitle: Text('${c.nif}${c.existeEnDb ? " (Actualizar)" : ""}'),
                  trailing: c.tieneWarnings 
                      ? Tooltip(message: c.motivosWarning, child: const Icon(Icons.warning, color: Colors.amber))
                      : const Icon(Icons.check_circle, color: Colors.green),
                )),
              ],
            ),
          ),

        // Botones
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _pasoActual = 0),
                child: const Text('Cancelar / Reintentar'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: validos > 0 ? _ejecutarImportacion : null,
                icon: const Icon(Icons.download),
                label: Text('Importar $validos clientes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── PASO 3: EJECUCIÓN ───────────────────────────────────────────────────────

  Future<void> _ejecutarImportacion() async {
    setState(() {
      _pasoActual = 2;
      _importando = true;
      _progreso = 0;
    });

    try {
      await for (final p in _service.importarEnLotes(_preview!.validos, widget.empresaId)) {
        setState(() => _progreso = p);
      }
      setState(() {
        _importando = false;
        _completado = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _importando = false);
    }
  }

  Widget _buildPasoProgreso() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_completado) ...[
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text('¡Importación completada!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              'Se han procesado correctamente ${_preview!.validos.length} clientes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), // Retorna true para refrescar
              child: const Text('Volver al listado'),
            ),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Importando... ${(_progreso * 100).toInt()}%',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('No cierres esta pantalla', style: TextStyle(color: Colors.grey)),
          ]
        ],
      ),
    );
  }

  // ── STATS HELPERS ───────────────────────────────────────────────────────────

  Widget _StatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _InfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Clientes'),
        elevation: 0,
      ),
      body: IndexedStack(
        index: _pasoActual,
        children: [
          _buildPasoSeleccion(),
          _buildPasoPreview(),
          _buildPasoProgreso(),
        ],
      ),
    );
  }
}



import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:planeag_flutter/services/importacion_catalogo_service.dart';

/// Bottom sheet con el flujo completo de importación CSV.
///
/// Flujo:
/// 1. Descargar plantilla / elegir archivo
/// 2. Preview de los primeros 5 registros
/// 3. Validación con resumen
/// 4. Importación con progress bar
/// 5. Resultado final
class ImportacionCatalogoSheet extends StatefulWidget {
  final String empresaId;

  const ImportacionCatalogoSheet({super.key, required this.empresaId});

  static Future<bool?> mostrar(BuildContext context,
      {required String empresaId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportacionCatalogoSheet(empresaId: empresaId),
    );
  }

  @override
  State<ImportacionCatalogoSheet> createState() =>
      _ImportacionCatalogoSheetState();
}

enum _Paso { inicio, preview, validacion, importando, resultado }

class _ImportacionCatalogoSheetState extends State<ImportacionCatalogoSheet> {
  final _svc = ImportacionCatalogoService();
  _Paso _paso = _Paso.inicio;
  List<FilaImportacion> _filas = [];
  List<FilaImportacion> _preview = [];
  ResultadoImportacion? _resultado;
  double _progreso = 0;
  bool _reemplazar = false;
  String? _error;

  // ── ACCIONES ──────────────────────────────────────────────────────────────

  Future<void> _descargarPlantilla() async {
    final csv = _svc.generarPlantillaCsv();
    try {
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/plantilla_catalogo.csv');
        await file.writeAsString(csv);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Plantilla catálogo',
        );
      } else {
        // Web: copiar al portapapeles
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contenido de la plantilla copiado')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarArchivo() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null) return;

      String contenido;
      if (result.files.first.bytes != null) {
        contenido = String.fromCharCodes(result.files.first.bytes!);
      } else if (result.files.first.path != null) {
        contenido = await File(result.files.first.path!).readAsString();
      } else {
        return;
      }

      final filas = _svc.parsearCsv(contenido);
      if (filas.isEmpty) {
        setState(() => _error = 'El archivo CSV está vacío o sin datos');
        return;
      }

      // Validar
      final skus = await _svc.obtenerSkusExistentes(widget.empresaId);
      final validadas = _svc.validar(filas, skus);

      setState(() {
        _filas = validadas;
        _preview = validadas.take(5).toList();
        _paso = _Paso.preview;
      });
    } catch (e) {
      setState(() => _error = 'Error al leer el archivo: $e');
    }
  }

  Future<void> _confirmarImportacion() async {
    setState(() {
      _paso = _Paso.importando;
      _progreso = 0;
    });
    try {
      final resultado = await _svc.importar(
        empresaId: widget.empresaId,
        filas: _filas,
        reemplazar: _reemplazar,
        onProgreso: (p) => setState(() => _progreso = p),
      );
      setState(() {
        _resultado = resultado;
        _paso = _Paso.resultado;
      });
    } catch (e) {
      setState(() {
        _error = 'Error durante la importación: $e';
        _paso = _Paso.validacion;
      });
    }
  }

  Future<void> _descargarCsvErrores() async {
    if (_resultado == null) return;
    final csv = _svc.generarCsvErrores(_resultado!.filasConError);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/errores_importacion.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
          subject: 'Errores importación catálogo');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            const Icon(Icons.upload_file, color: Color(0xFF1976D2), size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Importar catálogo CSV',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Añade múltiples productos de golpe',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildContenido(),
          ),
        ),
      ]),
    );
  }

  Widget _buildContenido() {
    return switch (_paso) {
      _Paso.inicio => _buildInicio(),
      _Paso.preview => _buildPreview(),
      _Paso.validacion => _buildValidacion(),
      _Paso.importando => _buildImportando(),
      _Paso.resultado => _buildResultado(),
    };
  }

  // ── PASO 1: INICIO ────────────────────────────────────────────────────────

  Widget _buildInicio() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoCard(
        icon: Icons.info_outline,
        color: const Color(0xFF1976D2),
        titulo: 'Formato del CSV',
        texto:
            'Columnas: nombre, tipo (producto/servicio), categoria, precio, iva_porcentaje, '
            'duracion_minutos, descripcion, sku, codigo_barras, activo.',
      ),
      const SizedBox(height: 16),
      // Descargar plantilla
      OutlinedButton.icon(
        onPressed: _descargarPlantilla,
        icon: const Icon(Icons.download),
        label: const Text('Descargar plantilla de ejemplo'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1976D2),
          side: const BorderSide(color: Color(0xFF1976D2)),
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      const SizedBox(height: 12),
      // Opción reemplazar
      SwitchListTile(
        value: _reemplazar,
        onChanged: (v) => setState(() => _reemplazar = v),
        title: const Text('Reemplazar todo el catálogo',
            style: TextStyle(fontSize: 14)),
        subtitle: const Text(
            'Si está activado, se eliminarán todos los productos actuales',
            style: TextStyle(fontSize: 12)),
        activeThumbColor: Colors.red,
        contentPadding: EdgeInsets.zero,
      ),
      if (_reemplazar)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: const Row(children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ Se eliminarán TODOS los productos actuales. Esta acción no se puede deshacer.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ]),
        ),
      if (_error != null) _errorWidget(_error!),
      const SizedBox(height: 12),
      // Seleccionar archivo
      ElevatedButton.icon(
        onPressed: _seleccionarArchivo,
        icon: const Icon(Icons.folder_open),
        label: const Text('Seleccionar archivo CSV'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }

  // ── PASO 2: PREVIEW ───────────────────────────────────────────────────────

  Widget _buildPreview() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Vista previa (primeros 5 registros de ${_filas.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 12),
      ...(_preview.map((f) => _tarjetaFila(f))),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => setState(() => _paso = _Paso.inicio),
            child: const Text('Volver'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _paso = _Paso.validacion),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Ver validación completa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    ]);
  }

  // ── PASO 3: VALIDACIÓN ────────────────────────────────────────────────────

  Widget _buildValidacion() {
    final validas = _filas.where((f) => f.valida).length;
    final errores = _filas.where((f) => !f.valida).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Resumen
      Row(children: [
        _statBox('$validas', 'válidos', Colors.green),
        const SizedBox(width: 12),
        _statBox('$errores', 'con error', Colors.red),
        const SizedBox(width: 12),
        _statBox('${_filas.length}', 'total', const Color(0xFF1976D2)),
      ]),
      const SizedBox(height: 16),
      if (errores > 0) ...[
        const Text('Registros con errores:',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._filas.where((f) => !f.valida).map((f) => _tarjetaFila(f)),
        const SizedBox(height: 16),
      ],
      if (_error != null) _errorWidget(_error!),
      if (validas == 0)
        _infoCard(
          icon: Icons.warning,
          color: Colors.red,
          titulo: 'Sin registros válidos',
          texto: 'Corrige los errores y vuelve a intentarlo.',
        )
      else
        ElevatedButton.icon(
          onPressed: _confirmarImportacion,
          icon: const Icon(Icons.cloud_upload),
          label: Text('Importar $validas productos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => setState(() => _paso = _Paso.inicio),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44)),
        child: const Text('Volver'),
      ),
    ]);
  }

  // ── PASO 4: IMPORTANDO ────────────────────────────────────────────────────

  Widget _buildImportando() {
    final validas = _filas.where((f) => f.valida).length;
    final actual = (validas * _progreso).round();
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 32),
        const Icon(Icons.cloud_upload_outlined, size: 56, color: Color(0xFF1976D2)),
        const SizedBox(height: 16),
        Text('Importando productos...',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 4),
        Text('$actual de $validas',
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 20),
        LinearProgressIndicator(
          value: _progreso,
          backgroundColor: Colors.grey[200],
          color: const Color(0xFF1976D2),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text('${(_progreso * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
      ]),
    );
  }

  // ── PASO 5: RESULTADO ─────────────────────────────────────────────────────

  Widget _buildResultado() {
    final r = _resultado!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Column(children: [
          const SizedBox(height: 8),
          Icon(
            r.errores == 0 ? Icons.check_circle : Icons.check_circle_outline,
            size: 56,
            color: r.errores == 0 ? Colors.green : const Color(0xFF1976D2),
          ),
          const SizedBox(height: 12),
          Text(
            '${r.importados} producto${r.importados != 1 ? "s" : ""} importados correctamente',
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (r.errores > 0)
            Text(
              '${r.errores} ignorado${r.errores != 1 ? "s" : ""} por errores',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
        ]),
      ),
      const SizedBox(height: 20),
      if (r.filasConError.isNotEmpty) ...[
        OutlinedButton.icon(
          onPressed: _descargarCsvErrores,
          icon: const Icon(Icons.download),
          label: const Text('Descargar errores como CSV'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
        const SizedBox(height: 8),
      ],
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Cerrar'),
      ),
    ]);
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _tarjetaFila(FilaImportacion f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: f.valida ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: f.valida ? Colors.green[200]! : Colors.red[200]!),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(f.valida ? Icons.check_circle : Icons.error,
            size: 16, color: f.valida ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Fila ${f.numero}: ${f.datos['nombre'] ?? '(sin nombre)'}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (!f.valida)
              ...f.errores.map((e) => Text('• $e',
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
            if (f.valida)
              Text(
                '${f.datos['categoria'] ?? ''} · ${f.datos['precio'] ?? ''} €',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _statBox(String valor, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(valor,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 22)),
            Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ]),
        ),
      );

  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String titulo,
    required String texto,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(texto, style: TextStyle(color: color, fontSize: 12)),
            ]),
          ),
        ]),
      );

  Widget _errorWidget(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12))),
        ]),
      );
}



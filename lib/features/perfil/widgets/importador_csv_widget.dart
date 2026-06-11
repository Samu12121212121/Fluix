import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

/// Widget de importación masiva de clientes desde CSV
/// Soporta formato estándar con columnas: nombre, email, telefono, notas
class ImportadorCsvWidget extends StatefulWidget {
  final String empresaId;

  const ImportadorCsvWidget({super.key, required this.empresaId});

  @override
  State<ImportadorCsvWidget> createState() => _ImportadorCsvWidgetState();
}

class _ImportadorCsvWidgetState extends State<ImportadorCsvWidget> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _procesando = false;
  int _importados = 0;
  int _errores = 0;
  List<String> _logs = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upload_file, color: Color(0xFF1976D2), size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importar clientes desde CSV',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sube un archivo CSV con tus clientes',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Formato esperado
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Formato del CSV:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'nombre,email,telefono,notas',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'Juan Pérez,juan@email.com,612345678,Cliente VIP',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Botón de importación
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _procesando ? null : _seleccionarArchivo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _procesando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.file_upload),
              label: Text(
                _procesando ? 'Importando...' : 'Seleccionar archivo CSV',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Resultados
          if (_logs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Importados: $_importados',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      if (_errores > 0)
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[600], size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Errores: $_errores',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final esError = log.startsWith('❌');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontSize: 11,
                              color: esError ? Colors.red[700] : Colors.grey[700],
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
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

  Future<void> _seleccionarArchivo() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // Para web
      );

      if (resultado == null) return;

      final archivo = resultado.files.first;
      String contenido;

      if (kIsWeb) {
        if (archivo.bytes == null) {
          _mostrarError('No se pudo leer el archivo');
          return;
        }
        contenido = utf8.decode(archivo.bytes!);
      } else {
        if (archivo.path == null) {
          _mostrarError('Ruta de archivo inválida');
          return;
        }
        final file = File(archivo.path!);
        contenido = await file.readAsString();
      }

      await _procesarCsv(contenido);
    } catch (e) {
      _mostrarError('Error al seleccionar archivo: $e');
    }
  }

  Future<void> _procesarCsv(String contenido) async {
    setState(() {
      _procesando = true;
      _importados = 0;
      _errores = 0;
      _logs = [];
    });

    try {
      // Parsear CSV
      final List<List<dynamic>> filas = const CsvToListConverter().convert(
        contenido,
        eol: '\n',
        fieldDelimiter: ',',
      );

      if (filas.isEmpty) {
        _mostrarError('El archivo CSV está vacío');
        return;
      }

      // Verificar headers (opcional, puede ser la primera fila o no)
      int inicioFila = 0;
      final primeraFila = filas[0].map((e) => e.toString().toLowerCase()).toList();
      if (primeraFila.contains('nombre') || primeraFila.contains('email')) {
        inicioFila = 1; // Saltar header
      }

      final batch = _db.batch();
      int contador = 0;

      for (int i = inicioFila; i < filas.length; i++) {
        final fila = filas[i];
        if (fila.length < 2) {
          _logs.add('❌ Fila ${i + 1}: formato inválido');
          _errores++;
          continue;
        }

        final nombre = fila.isNotEmpty ? fila[0].toString().trim() : '';
        final email = fila.length > 1 ? fila[1].toString().trim() : '';
        final telefono = fila.length > 2 ? fila[2].toString().trim() : '';
        final notas = fila.length > 3 ? fila[3].toString().trim() : '';

        if (nombre.isEmpty) {
          _logs.add('❌ Fila ${i + 1}: nombre vacío');
          _errores++;
          continue;
        }

        // Crear documento de cliente
        final clienteRef = _db
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('clientes')
            .doc();

        batch.set(clienteRef, {
          'nombre': nombre,
          'email': email.isEmpty ? null : email,
          'telefono': telefono.isEmpty ? null : telefono,
          'notas': notas.isEmpty ? null : notas,
          'fecha_creacion': FieldValue.serverTimestamp(),
          'activo': true,
          'importado_csv': true,
        });

        _logs.add('✅ Importado: $nombre');
        contador++;
        _importados++;

        // Commit cada 500 documentos para evitar límites de Firestore
        if (contador >= 500) {
          await batch.commit();
          contador = 0;
          setState(() {});
        }
      }

      // Commit pendientes
      if (contador > 0) {
        await batch.commit();
      }

      setState(() {
        _procesando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Importación completada: $_importados clientes'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error procesando CSV: $e');
      setState(() {
        _procesando = false;
      });
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


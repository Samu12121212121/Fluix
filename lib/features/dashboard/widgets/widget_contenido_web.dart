import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../../dashboard/pantallas/pantalla_contenido_web.dart';

final _log = Logger();

class WidgetContenidoWeb extends StatelessWidget {
  final String empresaId;

  const WidgetContenidoWeb({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.web, color: const Color(0xFF1976D2), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Contenido Web',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _configurarContenido(context),
                  icon: const Icon(Icons.settings, size: 20),
                  tooltip: 'Configurar contenido',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100, // Reducido de 120 a 100
              child: FutureBuilder<Map<String, dynamic>>(
                future: _obtenerEstadoContenido(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final estado = snapshot.data ?? _getEstadoDemo();
                  return _buildEstadoContenido(context, estado);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoContenido(BuildContext context, Map<String, dynamic> estado) {
    final seccionesActivas = estado['secciones_activas'] ?? 0;
    final seccionesTotal = estado['secciones_total'] ?? 0;
    final ultimaActualizacion = estado['ultima_actualizacion'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Estado general
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: seccionesActivas > 0 ? const Color(0xFF4CAF50) : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                seccionesActivas > 0 ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  color: seccionesActivas > 0 ? Colors.white : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$seccionesActivas de $seccionesTotal secciones activas',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Progreso visual
        LinearProgressIndicator(
          value: seccionesTotal > 0 ? seccionesActivas / seccionesTotal : 0,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            seccionesActivas > seccionesTotal * 0.7
                ? const Color(0xFF4CAF50)
                : seccionesActivas > seccionesTotal * 0.3
                    ? Colors.orange
                    : const Color(0xFFF44336),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          ultimaActualizacion.isNotEmpty
              ? 'Actualizado: $ultimaActualizacion'
              : 'Sin actualizaciones',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),

        const SizedBox(height: 12),

        // Acciones rápidas
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navegarAEditor(context),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Editar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _mostrarCodigoJS(context),
                icon: const Icon(Icons.code, size: 16),
                label: const Text('Código'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _obtenerEstadoContenido() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('contenido_web')
          .get();

      final seccionesTotal = query.docs.length;
      final seccionesActivas = query.docs
          .where((doc) => (doc.data()['activa'] ?? false) == true)
          .length;

      // Buscar última actualización
      DateTime? ultimaActualizacion;
      for (final doc in query.docs) {
        final fechaStr = doc.data()['fecha_actualizacion'] as String?;
        if (fechaStr != null) {
          final fecha = DateTime.parse(fechaStr);
          if (ultimaActualizacion == null || fecha.isAfter(ultimaActualizacion)) {
            ultimaActualizacion = fecha;
          }
        }
      }

      return {
        'secciones_total': seccionesTotal,
        'secciones_activas': seccionesActivas,
        'ultima_actualizacion': ultimaActualizacion != null
            ? _formatearFecha(ultimaActualizacion)
            : '',
      };
    } catch (e) {
      _log.e('Error obteniendo estado contenido: $e');
      return _getEstadoDemo();
    }
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 60) {
      return 'hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'hace ${diferencia.inHours}h';
    } else {
      return 'hace ${diferencia.inDays} días';
    }
  }

  Map<String, dynamic> _getEstadoDemo() => {
    'secciones_total': 4,
    'secciones_activas': 2,
    'ultima_actualizacion': 'hace 2h',
  };

  void _configurarContenido(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contenido Web'),
        content: const Text(
          'Aquí puedes gestionar el contenido dinámico de tu página web.\n\n'
          'Características:\n'
          '• Editar títulos, textos e imágenes\n'
          '• Activar/desactivar secciones\n'
          '• Generar código para tu web\n'
          '• Cambios en tiempo real',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editarContenido();
            },
            child: const Text('Ir a Editar'),
          ),
        ],
      ),
    );
  }

  /// Necesita context — se llama desde onPressed donde hay context
  void _navegarAEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaContenidoWeb(empresaId: empresaId),
      ),
    );
  }

  /// Muestra el código JS embebible para la web del cliente
  void _mostrarCodigoJS(BuildContext context) {
    final codigo = '''
<script>
  // Fluix CRM — Widget dinámico
  (function() {
    const EMPRESA_ID = '$empresaId';
    const API_URL = 'https://firestore.googleapis.com/v1/projects/planeag-flutter/databases/(default)/documents';

    async function cargarContenido() {
      try {
        const resp = await fetch(API_URL + '/empresas/' + EMPRESA_ID + '/contenido_web');
        const data = await resp.json();
        if (data.documents) {
          data.documents.forEach(function(doc) {
            const fields = doc.fields;
            const id = fields.seccion_id?.stringValue || '';
            const el = document.getElementById('fluix-' + id);
            if (el && fields.activa?.booleanValue) {
              el.innerHTML = fields.contenido_html?.stringValue || '';
            }
          });
        }
      } catch(e) { console.warn('Fluix CRM:', e); }
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', cargarContenido);
    } else {
      cargarContenido();
    }
  })();
</script>''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código para tu web'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pega este código justo antes de </body> en tu web:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  codigo,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado al portapapeles')),
              );
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar'),
          ),
        ],
      ),
    );
  }
}


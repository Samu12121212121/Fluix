import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';
import 'dialogs_contenido_web.dart';

class ModuloContenidoWeb extends StatefulWidget {
  final String empresaId;
  const ModuloContenidoWeb({super.key, required this.empresaId});

  @override
  State<ModuloContenidoWeb> createState() => _ModuloContenidoWebState();
}

class _ModuloContenidoWebState extends State<ModuloContenidoWeb> {
  final ContenidoWebService _contenidoService = ContenidoWebService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          _buildHeader(context),

          // Lista de secciones
          Expanded(
            child: StreamBuilder<List<SeccionWeb>>(
              stream: _contenidoService.obtenerSecciones(widget.empresaId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEstadoVacio(context);
                }

                final secciones = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: secciones.length,
                  itemBuilder: (context, index) => _buildSeccionCard(context, secciones[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_codigo',
            onPressed: () => _generarCodigoWeb(context),
            icon: const Icon(Icons.code),
            label: const Text('Generar Código'),
            backgroundColor: const Color(0xFF21759B),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_add',
            onPressed: () => _mostrarDialogNuevaSeccion(context),
            child: const Icon(Icons.add),
            backgroundColor: const Color(0xFF1976D2),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.web, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestión de Contenido Web',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Actualiza tu web dinámicamente',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _mostrarAyuda(context),
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Crea secciones para ofertas, cartas, promociones y más. Los cambios se reflejan en tiempo real en tu web.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoVacio(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.web, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay secciones web',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu primera sección para gestionar el contenido de tu web',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _crearSeccionesPorDefecto(context),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Crear por Defecto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogNuevaSeccion(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Manual'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionCard(BuildContext context, SeccionWeb seccion) {
    final tipoSeccion = TipoSeccionWeb.values.firstWhere(
      (tipo) => tipo.id == seccion.tipo,
      orElse: () => TipoSeccionWeb.personalizado,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editarSeccion(context, seccion),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de la sección
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: seccion.activa ? const Color(0xFF4CAF50) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      tipoSeccion.icono,
                      color: seccion.activa ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seccion.nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${seccion.elementos.length} elemento${seccion.elementos.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: seccion.activa,
                    onChanged: (value) => _toggleSeccion(seccion.id, value),
                    activeThumbColor: const Color(0xFF4CAF50),
                  ),
                ],
              ),

              if (seccion.elementos.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Preview de elementos
                ...seccion.elementos.take(2).map((elemento) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.fiber_manual_record, size: 8, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          elemento.titulo,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (elemento.precio != null)
                        Text(
                          '€${elemento.precio!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                    ],
                  ),
                )),

                if (seccion.elementos.length > 2)
                  Text(
                    'y ${seccion.elementos.length - 2} más...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],

              // Footer con acciones rápidas
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'ID: fluixcrm_${seccion.id}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _agregarElementoRapido(context, seccion),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSeccion(String seccionId, bool activa) async {
    try {
      await _contenidoService.toggleSeccion(widget.empresaId, seccionId, activa);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sección ${activa ? 'activada' : 'desactivada'}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }

  void _mostrarDialogNuevaSeccion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DialogNuevaSeccion(
        empresaId: widget.empresaId,
        contenidoService: _contenidoService,
      ),
    );
  }

  void _editarSeccion(BuildContext context, SeccionWeb seccion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorSeccionPage(
          empresaId: widget.empresaId,
          seccion: seccion,
          contenidoService: _contenidoService,
        ),
      ),
    );
  }

  void _agregarElementoRapido(BuildContext context, SeccionWeb seccion) {
    showDialog(
      context: context,
      builder: (context) => DialogAgregarElemento(
        empresaId: widget.empresaId,
        seccionId: seccion.id,
        tipoSeccion: seccion.tipo,
        contenidoService: _contenidoService,
      ),
    );
  }

  void _crearSeccionesPorDefecto(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Secciones por Defecto'),
        content: const Text('¿Qué tipo de negocio tienes?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _contenidoService.crearSeccionesPorDefecto(widget.empresaId, 'restaurante');
            },
            child: const Text('️ Restaurante'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _contenidoService.crearSeccionesPorDefecto(widget.empresaId, 'peluqueria');
            },
            child: const Text('‍♀️ Peluquería'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _contenidoService.crearSeccionesPorDefecto(widget.empresaId, 'general');
            },
            child: const Text(' General'),
          ),
        ],
      ),
    );
  }

  void _generarCodigoWeb(BuildContext context) async {
    try {
      final codigo = await _contenidoService.generarCodigoJavaScript(widget.empresaId);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.code, color: Color(0xFF21759B)),
              SizedBox(width: 8),
              Text('Código para tu Web'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                const Text(
                  'Copia este código y pégalo en el HTML de tu web donde quieras que aparezcan las secciones:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        codigo,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  ' Para cada sección, añade un div con id="fluixcrm_[id_seccion]" en tu HTML',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codigo));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado al portapapeles'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text(' Copiar Código'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando código: $e'),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }

  void _mostrarAyuda(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Cómo Funciona'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Crear Secciones',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Crea secciones como "Ofertas", "Carta", "Promociones", etc.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '2. Añadir Elementos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Agrega elementos a cada sección con títulos, descripciones y precios.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '3. Generar Código',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Copia el código JavaScript generado y pégalo en tu web.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '4. Añadir DIVs en tu Web',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'En tu HTML, añade: <div id="fluixcrm_[id_seccion]"></div>',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              SizedBox(height: 12),
              Text(
                '✨ Los cambios que hagas en la app se reflejarán automáticamente en tu web!',
                style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}


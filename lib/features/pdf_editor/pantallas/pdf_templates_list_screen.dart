import 'package:flutter/material.dart';
import '../../../services/pdf/pdf_template_service.dart';
import '../../../domain/modelos/pdf_template.dart';

class PdfTemplatesListScreen extends StatefulWidget {
  final String empresaId;

  const PdfTemplatesListScreen({required this.empresaId, super.key});

  @override
  State<PdfTemplatesListScreen> createState() => _PdfTemplatesListScreenState();
}

class _PdfTemplatesListScreenState extends State<PdfTemplatesListScreen> {
  final _service = PdfTemplateService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Plantillas PDF'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ayuda',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('💡 Plantillas PDF'),
                  content: const Text(
                    'Personaliza el diseño de tus documentos:\n\n'
                    '• Facturas\n'
                    '• Presupuestos\n'
                    '• Fichajes\n\n'
                    'Las plantillas activas se usan automáticamente al generar PDFs.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendido'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<PdfTemplate>>(
        future: _service.listTemplates(widget.empresaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final templates = snapshot.data ?? [];

          if (templates.isEmpty) {
            return _buildEmptyState(context);
          }

          // Agrupar por tipo
          final grouped = <PdfDocumentType, List<PdfTemplate>>{};
          for (final template in templates) {
            grouped.putIfAbsent(template.type, () => []).add(template);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatsCard(templates),
              const SizedBox(height: 16),
              ...grouped.entries.map((entry) {
                return _buildTypeSection(entry.key, entry.value);
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📝 Editor visual próximamente disponible'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Plantilla'),
        backgroundColor: const Color(0xFF1565C0),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 120,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Sin plantillas personalizadas',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Crea plantillas para personalizar\nel diseño de tus documentos',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navegar a editor
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📝 Editor avanzado próximamente'),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Crear Primera Plantilla'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(List<PdfTemplate> templates) {
    final active = templates.where((t) => t.isActive).length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('Total', '${templates.length}', Icons.description, Colors.blue),
            _buildStat('Activas', '$active', Icons.check_circle, Colors.green),
            _buildStat('Inactivas', '${templates.length - active}', Icons.pause_circle, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSection(PdfDocumentType type, List<PdfTemplate> templates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(_getIconForType(type), size: 20, color: const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Text(
                _getLabelForType(type),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${templates.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...templates.map((template) => _buildTemplateCard(template)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTemplateCard(PdfTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: template.isActive ? Colors.green[100] : Colors.grey[200],
          child: Icon(
            template.isActive ? Icons.check_circle : Icons.pause_circle_outline,
            color: template.isActive ? Colors.green[700] : Colors.grey[600],
            size: 20,
          ),
        ),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${template.blocks.length} bloques • v${template.version}'
          '${template.isDefault ? " • Por defecto" : ""}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(value, template),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'preview',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(width: 8),
                  Text('Vista previa'),
                ],
              ),
            ),
            if (!template.isActive)
              const PopupMenuItem(
                value: 'activate',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Activar'),
                  ],
                ),
              ),
            if (template.isActive)
              const PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Desactivar'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'duplicate',
              child: Row(
                children: [
                  Icon(Icons.copy, size: 20),
                  SizedBox(width: 8),
                  Text('Duplicar'),
                ],
              ),
            ),
            if (!template.isDefault)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
        onTap: () {
          // TODO: Abrir editor
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Editar: ${template.name}')),
          );
        },
      ),
    );
  }

  void _handleMenuAction(String action, PdfTemplate template) async {
    switch (action) {
      case 'preview':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📄 Vista previa próximamente')),
        );
        break;

      case 'activate':
        // Activar plantilla
        final updated = template.copyWith(isActive: true);
        final success = await _service.updateTemplate(
          empresaId: widget.empresaId,
          templateId: template.id,
          template: updated,
        );
        if (success) {
          setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Plantilla activada'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        break;

      case 'deactivate':
        // Desactivar plantilla
        final updated = template.copyWith(isActive: false);
        final success = await _service.updateTemplate(
          empresaId: widget.empresaId,
          templateId: template.id,
          template: updated,
        );
        if (success) {
          setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⏸️ Plantilla desactivada'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        break;

      case 'duplicate':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📋 Duplicar próximamente')),
        );
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('⚠️ Eliminar plantilla'),
            content: Text('¿Eliminar "${template.name}"?\n\nEsta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final success = await _service.deleteTemplate(
            empresaId: widget.empresaId,
            templateId: template.id,
          );
          if (success) {
            setState(() {});
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Plantilla eliminada'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        break;
    }
  }

  IconData _getIconForType(PdfDocumentType type) {
    return switch (type) {
      PdfDocumentType.factura => Icons.receipt_long,
      PdfDocumentType.rectificativa => Icons.receipt,
      PdfDocumentType.presupuesto => Icons.request_quote,
      PdfDocumentType.fichaje => Icons.access_time,
      PdfDocumentType.nomina => Icons.payments,
      PdfDocumentType.albar => Icons.local_shipping,
    };
  }

  String _getLabelForType(PdfDocumentType type) {
    return switch (type) {
      PdfDocumentType.factura => 'Facturas',
      PdfDocumentType.rectificativa => 'Rectificativas',
      PdfDocumentType.presupuesto => 'Presupuestos',
      PdfDocumentType.fichaje => 'Fichajes',
      PdfDocumentType.nomina => 'Nóminas',
      PdfDocumentType.albar => 'Albaranes',
    };
  }
}


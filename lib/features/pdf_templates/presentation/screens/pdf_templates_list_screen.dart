import 'package:flutter/material.dart';
import '../../domain/models/pdf_template.dart';
import '../../data/pdf_template_service.dart';
import 'template_editor_screen.dart';

// ── helper color ─────────────────────────────────────────────────────────────
Color _hxL(String h) {
  try { return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16)); }
  catch (_) { return const Color(0xFF1565C0); }
}

class PdfTemplatesListScreen extends StatefulWidget {
  final String empresaId;
  const PdfTemplatesListScreen({super.key, required this.empresaId});
  @override
  State<PdfTemplatesListScreen> createState() => _PdfTemplatesListScreenState();
}

class _PdfTemplatesListScreenState extends State<PdfTemplatesListScreen> {
  final _service = PdfTemplateService();
  TipoDocumentoPdf? _filtroTipo;
  bool _inicializando = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() => _inicializando = true);
    try {
      await _service.inicializarPlantillasDefault(widget.empresaId);
    } catch (_) {}
    if (mounted) setState(() => _inicializando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Plantillas PDF'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Nueva plantilla', onPressed: _crearNueva),
        ],
      ),
      body: _inicializando
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildFiltros(),
              Expanded(child: StreamBuilder<List<PdfTemplate>>(
                stream: _service.watchPlantillas(widget.empresaId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text('Sin permisos — despliega las reglas Firestore', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('firebase deploy --only firestore:rules', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey[600])),
                    ])));
                  }
                  final todas = snap.data ?? [];
                  final plantillas = _filtroTipo == null ? todas : todas.where((p) => p.tipo == _filtroTipo).toList();
                  if (plantillas.isEmpty) return _buildEmpty();
                  return _buildGrid(plantillas);
                },
              )),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearNueva,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Plantilla'),
      ),
    );
  }

  // ── Filtros ────────────────────────────────────────────────────────────────
  Widget _buildFiltros() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip(null, '📋 Todas'),
        ...TipoDocumentoPdf.values.map((t) => _chip(t, '${t.icon} ${t.label}')),
      ]),
    ),
  );

  Widget _chip(TipoDocumentoPdf? tipo, String label) {
    final sel = _filtroTipo == tipo;
    return Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: sel,
      onSelected: (_) => setState(() => _filtroTipo = tipo),
      selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.15),
      checkmarkColor: const Color(0xFF1565C0),
      side: BorderSide(color: sel ? const Color(0xFF1565C0) : Colors.grey.shade300),
    ));
  }

  // ── Grid con mini-canvas ───────────────────────────────────────────────────
  Widget _buildGrid(List<PdfTemplate> plantillas) {
    final ancho = MediaQuery.of(context).size.width;
    final cols = ancho > 900 ? 4 : ancho > 600 ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: plantillas.length,
      itemBuilder: (_, i) => _templateCard(plantillas[i]),
    );
  }

  Widget _templateCard(PdfTemplate p) {
    return GestureDetector(
      onTap: () => _editarPlantilla(p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: p.esDefault ? Border.all(color: _hxL(p.colorPrimario), width: 2) : Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Mini canvas preview
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Stack(children: [
              _miniCanvas(p),
              // overlay tipo
              Positioned(top: 6, left: 6, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: _hxL(p.colorPrimario), borderRadius: BorderRadius.circular(6)),
                child: Text('${p.tipo.icon} ${p.tipo.label}', style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
              )),
              if (p.esDefault) Positioned(top: 6, right: 6, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(6)),
                child: const Text('⭐ Por defecto', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
              )),
            ]),
          )),
          // Footer info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _usadoEn(p.tipo),
                    style: const TextStyle(fontSize: 8, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text('${p.bloques.where((b) => b['activo'] == true).length} bloques', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              const SizedBox(height: 6),
              Row(children: [
                _miniBtn(Icons.edit_outlined, 'Editar', () => _editarPlantilla(p), _hxL(p.colorPrimario)),
                const SizedBox(width: 4),
                _miniBtn(Icons.copy_outlined, '', () => _duplicarPlantilla(p), Colors.grey),
                if (!p.esDefault) ...[
                  const SizedBox(width: 4),
                  _miniBtn(Icons.star_outline, '', () => _establecerDefault(p), Colors.amber.shade700),
                ],
                const Spacer(),
                if (!p.esDefault)
                  GestureDetector(onTap: () => _confirmarEliminar(p), child: const Icon(Icons.delete_outline, color: Colors.red, size: 16)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _usadoEn(TipoDocumentoPdf tipo) => switch (tipo) {
    TipoDocumentoPdf.factura              => '🖥️ TPV · Facturación',
    TipoDocumentoPdf.facturaRectificativa => '🔄 Rectificativas',
    TipoDocumentoPdf.fichajes             => '⏱️ Módulo Fichajes',
    TipoDocumentoPdf.horasEmpleado        => '⏱️ Módulo Fichajes',
    TipoDocumentoPdf.proforma             => '📋 Proformas',
    TipoDocumentoPdf.presupuesto          => '💼 Presupuestos',
    TipoDocumentoPdf.albaran              => '📦 Albaranes',
    TipoDocumentoPdf.informeInterno       => '📄 Informes',
  };

  Widget _miniBtn(IconData icon, String label, VoidCallback fn, Color color) => GestureDetector(
    onTap: fn,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        if (label.isNotEmpty) ...[const SizedBox(width: 3), Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))],
      ]),
    ),
  );

  // ── Mini canvas A4 escalado ────────────────────────────────────────────────
  Widget _miniCanvas(PdfTemplate p) {
    final color = _hxL(p.colorPrimario);
    return Container(
      color: const Color(0xFFE8EAF0),
      child: Center(child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 297, height: 420, // A4 a escala 0.5
          child: Container(
            color: Colors.white,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Siempre mostramos una cabecera con el color de la plantilla
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                color: color,
                child: Row(children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Container(height: 4, width: 60, color: Colors.white.withValues(alpha: 0.9), margin: const EdgeInsets.only(bottom: 2)),
                    Container(height: 3, width: 40, color: Colors.white.withValues(alpha: 0.5)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Container(height: 4, width: 40, color: Colors.white.withValues(alpha: 0.9), margin: const EdgeInsets.only(bottom: 2)),
                    Container(height: 3, width: 25, color: Colors.white.withValues(alpha: 0.5)),
                  ]),
                ]),
              ),
              // Renderizamos los bloques activos de la plantilla
              ...p.bloques.where((b) => b['activo'] == true).take(7).map((b) => _miniBloqueRender(b, color)),
            ]),
          ),
        ),
      )),
    );
  }

  Widget _miniBloqueRender(Map<String, dynamic> b, Color color) {
    final tipo = b['tipo'] as String? ?? '';
    switch (tipo) {
      case 'header': return const SizedBox.shrink(); // ya dibujamos header arriba
      case 'cliente':
        return Container(margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 3, width: 40, color: color.withValues(alpha: 0.7), margin: const EdgeInsets.only(bottom: 2)),
            Container(height: 3, width: 70, color: Colors.grey.shade400, margin: const EdgeInsets.only(bottom: 1)),
            Container(height: 2, width: 55, color: Colors.grey.shade300),
          ]));
      case 'info_documento':
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Align(alignment: Alignment.centerRight,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(height: 3, width: 50, color: Colors.grey.shade500, margin: const EdgeInsets.only(bottom: 1)),
            Container(height: 2, width: 38, color: Colors.grey.shade300),
          ])));
      case 'tabla_lineas':
        return Column(children: [
          Container(height: 8, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 6), color: color,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [
              Expanded(child: Container(height: 2, color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(width: 8),
              Container(width: 20, height: 2, color: Colors.white.withValues(alpha: 0.7)),
            ]))),
          _filaTabla(Colors.white, color), _filaTabla(color.withValues(alpha: 0.04), color), _filaTabla(Colors.white, color),
        ]);
      case 'totales':
        return Align(alignment: Alignment.centerRight, child: Container(
          width: 80, margin: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
          child: Column(children: [
            _rowTotales(Colors.grey.shade400, Colors.grey.shade400),
            _rowTotales(Colors.grey.shade400, Colors.grey.shade400),
            Divider(height: 3, color: color.withValues(alpha: 0.4)),
            _rowTotales(color.withValues(alpha: 0.8), color),
          ]),
        ));
      case 'forma_pago':
        return Container(margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 2, width: 35, color: color.withValues(alpha: 0.6), margin: const EdgeInsets.only(bottom: 1)),
            Container(height: 2, width: 55, color: Colors.grey.shade300),
          ]));
      case 'qr_verifactu':
        return Padding(padding: const EdgeInsets.only(right: 6, bottom: 3), child: Align(alignment: Alignment.centerRight,
          child: Container(width: 16, height: 16, decoration: BoxDecoration(border: Border.all(color: color, width: 1.5), borderRadius: BorderRadius.circular(2)),
            child: GridView.count(crossAxisCount: 3, padding: const EdgeInsets.all(1), mainAxisSpacing: 1, crossAxisSpacing: 1,
              children: List.generate(9, (i) => Container(color: i % 2 == 0 ? color : Colors.white))))));
      case 'notas':
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 2, width: double.infinity, color: Colors.grey.shade200, margin: const EdgeInsets.only(bottom: 1)),
          Container(height: 2, width: 120, color: Colors.grey.shade200),
        ]));
      case 'texto_libre':
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Container(height: 2, width: double.infinity, color: Colors.grey.shade300));
      case 'separador':
        return Divider(height: 6, indent: 6, endIndent: 6, color: Colors.grey.shade300);
      case 'espaciador':
        return const SizedBox(height: 4);
      case 'tabla_fichajes':
        return Column(children: [
          Container(height: 7, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 6), color: color),
          _filaTabla(Colors.white, color), _filaTabla(color.withValues(alpha: 0.04), color),
        ]);
      case 'resumen_horas':
        return Container(margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), padding: const EdgeInsets.all(4),
          color: color.withValues(alpha: 0.05),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statMini(color), _statMini(color), _statMini(Colors.orange),
          ]));
      case 'info_empleado':
        return Container(margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(2), border: Border.all(color: color.withValues(alpha: 0.15))),
          child: Row(children: [
            CircleAvatar(radius: 5, backgroundColor: color.withValues(alpha: 0.3)),
            const SizedBox(width: 4),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 3, width: 40, color: Colors.grey.shade500, margin: const EdgeInsets.only(bottom: 1)),
              Container(height: 2, width: 28, color: Colors.grey.shade300),
            ]),
          ]));
      case 'footer':
        return Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(vertical: 2),
          child: Center(child: Container(height: 2, width: 100, color: Colors.grey.shade300)));
      default:
        return Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), color: Colors.grey.shade100);
    }
  }

  Widget _filaTabla(Color bg, Color accent) => Container(
    height: 6, margin: const EdgeInsets.symmetric(horizontal: 6), color: bg,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), child: Row(children: [
      Expanded(child: Container(height: 2, color: Colors.grey.shade300)),
      const SizedBox(width: 8),
      Container(width: 15, height: 2, color: accent.withValues(alpha: 0.5)),
    ])),
  );

  Widget _rowTotales(Color l, Color r) => Padding(padding: const EdgeInsets.symmetric(vertical: 0.5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(height: 2, width: 30, color: l),
      Container(height: 2, width: 18, color: r),
    ]));

  Widget _statMini(Color c) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(height: 6, width: 14, color: c.withValues(alpha: 0.7), margin: const EdgeInsets.only(bottom: 1)),
    Container(height: 2, width: 10, color: Colors.grey.shade300),
  ]);

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.picture_as_pdf_outlined, size: 72, color: Colors.grey.shade300),
    const SizedBox(height: 16),
    const Text('Todavía no tienes ninguna plantilla creada', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text(
      _filtroTipo == null ? 'Crea tu primera plantilla y personaliza el diseño de tus documentos' : 'No hay plantillas de tipo ${_filtroTipo!.label}',
      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13),
    ),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      onPressed: _crearNueva,
      icon: const Icon(Icons.add),
      label: const Text('Crear primera plantilla'),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ),
  ])));

  // ── Acciones ───────────────────────────────────────────────────────────────
  void _crearNueva() => Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditorScreen(empresaId: widget.empresaId)));

  void _editarPlantilla(PdfTemplate p) => Navigator.push(context, MaterialPageRoute(
    builder: (_) => TemplateEditorScreen(empresaId: widget.empresaId, plantillaInicial: p)));

  Future<void> _duplicarPlantilla(PdfTemplate p) async {
    final ctrl = TextEditingController(text: 'Copia de ${p.nombre}');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Duplicar plantilla'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre de la copia'), autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Duplicar'))],
    ));
    if (ok != true || !mounted) return;
    try {
      await _service.duplicarPlantilla(p, ctrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Plantilla duplicada'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _establecerDefault(PdfTemplate p) async {
    try {
      await _service.establecerComoDefault(widget.empresaId, p.id, p.tipo);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⭐ "${p.nombre}" es ahora la plantilla por defecto'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmarEliminar(PdfTemplate p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Eliminar plantilla'),
      content: Text('¿Eliminar "${p.nombre}"?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Eliminar'))],
    ));
    if (ok != true || !mounted) return;
    try {
      await _service.eliminarPlantilla(p.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Eliminada'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }
}

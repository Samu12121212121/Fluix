import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../domain/models/pdf_template.dart';
import '../../data/pdf_template_service.dart';
import 'template_editor_screen.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/pdf_service.dart';

// ── Colores editorpdf.html ───────────────────────────────────────────────────
const _kPurple     = Color(0xFF6D5EF8);
const _kPurpleLight= Color(0xFFECE9FE);
const _kBg         = Color(0xFFEEF1F6);
const _kCanvas     = Color(0xFFE3E7EE);
const _kText       = Color(0xFF12131A);
const _kTextSec    = Color(0xFF6B7280);
const _kTextTer    = Color(0xFF9CA3AF);

Color _hx(String h) { try { return Color(int.parse('FF${h.replaceAll('#','')}', radix:16)); } catch(_){ return _kPurple; } }

enum _Cat { galeria, todas, facturacion, comercial, interno, misPlantillas }

const _catLabel = {
  _Cat.galeria:       '✨ Galería',
  _Cat.todas:         'Todas',
  _Cat.facturacion:   'Facturación',
  _Cat.comercial:     'Comercial',
  _Cat.interno:       'Interno',
  _Cat.misPlantillas: 'Mis plantillas',
};

const _facTypes = {TipoDocumentoPdf.factura, TipoDocumentoPdf.facturaRectificativa, TipoDocumentoPdf.proforma};
const _comTypes = {TipoDocumentoPdf.presupuesto, TipoDocumentoPdf.albaran};
const _intTypes = {TipoDocumentoPdf.informeInterno, TipoDocumentoPdf.fichajes, TipoDocumentoPdf.horasEmpleado};

class PdfTemplatesListScreen extends StatefulWidget {
  final String empresaId;
  const PdfTemplatesListScreen({super.key, required this.empresaId});
  @override State<PdfTemplatesListScreen> createState() => _State();
}

class _State extends State<PdfTemplatesListScreen> {
  final _svc = PdfTemplateService();
  _Cat _cat = _Cat.galeria;
  bool _init = false;
  bool _guardandoGaleria = false;

  @override
  void initState() { super.initState(); _inicializar(); }

  Future<void> _inicializar() async {
    setState(() => _init = true);
    try { await _svc.inicializarPlantillasDefault(widget.empresaId); } catch (_) {}
    if (mounted) setState(() => _init = false);
  }

  bool _enCat(PdfTemplate p) => switch (_cat) {
    _Cat.galeria       => false, // La galería tiene su propia vista
    _Cat.todas         => true,
    _Cat.misPlantillas => !p.esDefault,
    _Cat.facturacion   => _facTypes.contains(p.tipo),
    _Cat.comercial     => _comTypes.contains(p.tipo),
    _Cat.interno       => _intTypes.contains(p.tipo),
  };

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.shortestSide < 600) return _pantallaInsuficiente();
    return Scaffold(
      backgroundColor: _kBg,
      body: _init
        ? const Center(child: CircularProgressIndicator())
        : _cat == _Cat.galeria
            ? _vistaGaleria()
            : StreamBuilder<List<PdfTemplate>>(
                stream: _svc.watchTodasPlantillas(widget.empresaId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return _error(snap.error);
                  final filtradas = (snap.data ?? []).where(_enCat).toList();
                  return _gallery(filtradas);
                },
              ),
    );
  }

  Widget _pantallaInsuficiente() => Scaffold(
    backgroundColor: _kBg,
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width:72,height:72,decoration:BoxDecoration(color:_kPurpleLight,shape:BoxShape.circle),child:const Icon(Icons.desktop_windows_outlined,color:_kPurple,size:36)),
      const SizedBox(height:24),
      const Text('Pantalla insuficiente',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:_kText)),
      const SizedBox(height:12),
      const Text('El editor de plantillas requiere\nuna pantalla de mínimo 11 pulgadas.',textAlign:TextAlign.center,style:TextStyle(color:_kTextSec,fontSize:14,height:1.5)),
      const SizedBox(height:24),
      GestureDetector(onTap:()=>Navigator.pop(context),child:Container(padding:const EdgeInsets.symmetric(horizontal:24,vertical:12),decoration:BoxDecoration(color:_kPurple,borderRadius:BorderRadius.circular(12)),child:const Text('Volver',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700)))),
    ])),
  );

  Widget _headerFiltros() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(24,14,24,10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width:36, height:36, decoration: BoxDecoration(color:_kPurpleLight, borderRadius:BorderRadius.circular(10)), child: const Icon(Icons.picture_as_pdf, color:_kPurple, size:18)),
        const SizedBox(width:10),
        const Text('Plantillas de documentos', style: TextStyle(fontSize:17, fontWeight:FontWeight.w800, color:_kText)),
      ]),
      const SizedBox(height:10),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _Cat.values.map((c) {
        final sel = _cat == c;
        final isGal = c == _Cat.galeria;
        return Padding(padding: const EdgeInsets.only(right:8), child: GestureDetector(
          onTap: () => setState(() => _cat = c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal:14, vertical:7),
            decoration: BoxDecoration(
              color: sel ? (isGal ? const Color(0xFFFFB300) : _kPurple) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? (isGal ? const Color(0xFFFFB300) : _kPurple) : (isGal ? const Color(0xFFFFB300) : Colors.grey.shade200)),
            ),
            child: Text(_catLabel[c]!, style: TextStyle(
              color: sel ? Colors.white : (isGal ? const Color(0xFFE65100) : _kTextSec),
              fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ));
      }).toList())),
    ]),
  );

  Widget _vistaGaleria() {
    final galeria = PdfTemplate.galeria(widget.empresaId);
    final w = MediaQuery.of(context).size.width;
    final cols = w > 1150 ? 3 : w > 750 ? 2 : 1;
    return Column(children: [
      _headerFiltros(),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Banner descriptivo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFF8E1), Color(0xFFFFF3E0)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Text('✨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Plantillas profesionales listas para usar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                const SizedBox(height: 3),
                Text('Elige un diseño, personaliza los colores y estará en tu empresa en segundos. Luego puedes editarla libremente desde el editor.', style: TextStyle(fontSize: 11.5, color: Colors.brown.shade600, height: 1.4)),
              ])),
            ]),
          ),
          // Grid de plantillas de galería
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, childAspectRatio: 0.72,
              crossAxisSpacing: 16, mainAxisSpacing: 16,
            ),
            itemCount: galeria.length,
            itemBuilder: (_, i) => _cardGaleria(galeria[i]),
          ),
        ]),
      )),
    ]);
  }

  Widget _cardGaleria(PdfTemplate p) {
    final accent = _hx(p.colorPrimario);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.07), blurRadius:14, offset:const Offset(0,4))],
      ),
      child: Column(children: [
        // Vista previa PDF real
        Expanded(flex: 5, child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: _PdfCardPreview(plantilla: p, empresaId: widget.empresaId),
        )),
        // Info + botones
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal:7, vertical:3),
              decoration: BoxDecoration(color: accent.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)),
              child: Text('${p.tipo.icon} ${p.tipo.label}', style: TextStyle(fontSize:8.5, fontWeight:FontWeight.w800, color:accent)),
            ),
          ]),
          const SizedBox(height: 5),
          Text(p.nombre, style: const TextStyle(fontWeight:FontWeight.w800, fontSize:13, color:_kText)),
          const SizedBox(height: 3),
          Text(p.descripcion, style: const TextStyle(fontSize:10, color:_kTextSec, height:1.4), maxLines:2, overflow:TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _btn('Vista previa', Icons.visibility_outlined, false, () => PdfService.previewPlantilla(context, p, widget.empresaId))),
            const SizedBox(width: 8),
            Expanded(child: _guardandoGaleria
              ? Container(height: 34, decoration: BoxDecoration(color: _kPurple, borderRadius: BorderRadius.circular(9)), child: const Center(child: SizedBox(width:14, height:14, child: CircularProgressIndicator(strokeWidth:2, color:Colors.white))))
              : _btn('Usar plantilla', Icons.add_circle_outline, true, () => _usarPlantillaGaleria(p))),
          ]),
        ])),
      ]),
    );
  }

  Future<void> _usarPlantillaGaleria(PdfTemplate p) async {
    if (_guardandoGaleria) return;
    setState(() => _guardandoGaleria = true);
    try {
      final copia = p.copyWith(
        id: const Uuid().v4(),
        empresaId: widget.empresaId,
        nombre: p.nombre,
        esDefault: false,
        activa: true,
        fechaCreacion: DateTime.now(),
        fechaModificacion: DateTime.now(),
      );
      await _svc.crearPlantilla(copia);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Plantilla añadida a tus plantillas'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ));
        setState(() { _cat = _Cat.misPlantillas; _guardandoGaleria = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardandoGaleria = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _gallery(List<PdfTemplate> items) {
    final w = MediaQuery.of(context).size.width;
    final cols = w > 1150 ? 4 : w > 850 ? 3 : 2;
    return Column(children: [
      _headerFiltros(),
      // Grid — cards con altura máxima 200px, auto-escalan si hay muchas
      Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
        const sp = 12.0;
        const padH = 20.0;
        final totalItems = items.length + 1;
        final rows = (totalItems / cols).ceil();
        final cardW = (constraints.maxWidth - padH*2 - sp*(cols-1)) / cols;
        // Calcula la altura que ocuparían si llenaran la pantalla
        final fillH = (constraints.maxHeight - 16 - sp*(rows-1)) / rows;
        // Limita a 750px máximo por tarjeta
        final cardH = fillH.clamp(80.0, 750.0);
        final ratio = (cardW / cardH).clamp(0.4, 2.5);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(padH, 8, padH, 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, childAspectRatio: ratio, crossAxisSpacing: sp, mainAxisSpacing: sp,
            ),
            itemCount: totalItems,
            itemBuilder: (_, i) => i < items.length ? _card(items[i]) : _cardNueva(),
          ),
        );
      })),
    ]);
  }

  Widget _card(PdfTemplate p) {
    final accent = _hx(p.colorPrimario);
    return GestureDetector(
      onTap: () => _editar(p),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.06), blurRadius:12, offset:const Offset(0,3))]),
        child: Column(children: [
          // Vista previa PDF real (renderizada de forma asíncrona)
          Expanded(flex: 4, child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: _PdfCardPreview(plantilla: p, empresaId: widget.empresaId),
          )),
          // Footer compacto
          Padding(padding: const EdgeInsets.fromLTRB(8,6,8,8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color:accent.withValues(alpha:0.12), borderRadius:BorderRadius.circular(10)), child: Text('${p.tipo.icon} ${p.tipo.label}', style: TextStyle(fontSize:8, fontWeight:FontWeight.w800, color:accent))),
              if (p.esDefault) ...[const SizedBox(width:3), Text('⭐', style: const TextStyle(fontSize:9))],
            ]),
            const SizedBox(height:4),
            Text(p.nombre, style: const TextStyle(fontWeight:FontWeight.w700, fontSize:11, color:_kText), maxLines:1, overflow:TextOverflow.ellipsis),
            const SizedBox(height:5),
            Row(children: [
              // Verde = activa (se usa), Rojo = inactiva (desactivada, no se usa)
              Expanded(child: _btn(
                p.activa ? 'Activa' : 'Inactiva',
                p.activa ? Icons.check_circle_outline : Icons.cancel_outlined,
                false, () => _toggleActiva(p),
                bgColor: p.activa ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              )),
              const SizedBox(width:4),
              _iconBtn(Icons.visibility_outlined, 'Preview', () => PdfService.previewPlantilla(context, p, widget.empresaId)),
              const SizedBox(width:4),
              Expanded(child: _btn('Editar', Icons.edit_outlined, true, () => _editar(p))),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _cardNueva() => GestureDetector(
    onTap: _nueva,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width:56, height:56, decoration: BoxDecoration(color:_kPurpleLight, shape:BoxShape.circle), child: const Icon(Icons.add, color:_kPurple, size:26)),
        const SizedBox(height:12),
        const Text('Nueva plantilla', style: TextStyle(color:_kTextSec, fontWeight:FontWeight.w700, fontSize:14)),
        const SizedBox(height:4),
        const Text('Crea desde cero', style: TextStyle(color:_kTextTer, fontSize:11)),
      ]),
    ),
  );

  Widget _btn(String lbl, IconData icon, bool primary, VoidCallback fn, {Color? bgColor}) {
    final bg = bgColor ?? (primary ? _kPurple : _kBg);
    final fg = (bgColor != null || primary) ? Colors.white : _kText;
    return GestureDetector(
      onTap: fn,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical:7, horizontal:6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9), border: (bgColor == null && !primary) ? Border.all(color: Colors.grey.shade200) : null),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size:12, color: fg),
          const SizedBox(width:4),
          Flexible(child: Text(lbl, style: TextStyle(fontSize:10, fontWeight:FontWeight.w700, color: fg), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }


  Widget _iconBtn(IconData icon, String tooltip, VoidCallback fn) =>
      Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: fn,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(icon, size: 12, color: _kTextSec),
          ),
        ),
      );

  // ── Mini canvas A4 ─────────────────────────────────────────────────────────
  // Si los bloques tienen posiciones (_x,_y,_w,_h) del editor → layout libre con Stack.
  // Si no → fallback a layout en columna.
  // ── Función _miniCanvas mantenida para compatibilidad interna ──────────────
  Widget _miniCanvas(PdfTemplate p) {
    final color = _hx(p.colorPrimario);
    final bloques = p.bloques.where((b) => b['activo']==true).toList();
    final tienePositions = bloques.any((b) {
      final pr = b['props'] as Map? ?? {};
      return pr['_x'] != null;
    });

    // Canvas A4: editor usa 595×842 → mini usa 297×420 (escala 0.5)
    const sx = 297.0 / 595.0;
    const sy = 420.0 / 842.0;

    Widget content;
    if (tienePositions) {
      content = Stack(children: [
        // Fondo blanco A4
        Container(width:297, height:420, color:Colors.white),
        // Bloques posicionados a escala real
        ...bloques.take(15).map((b) {
          final pr = b['props'] as Map? ?? {};
          final x  = ((pr['_x'] as num?)?.toDouble() ?? 0) * sx;
          final y  = ((pr['_y'] as num?)?.toDouble() ?? 0) * sy;
          final w  = ((pr['_w'] as num?)?.toDouble() ?? 297) * sx;
          final h  = ((pr['_h'] as num?)?.toDouble() ?? 20) * sy;
          return Positioned(left:x, top:y, width:w, height:h,
            child: ClipRect(child: _bloqueWire(b, color)));
        }),
      ]);
    } else {
      // Fallback: columna vertical
      content = Container(color:Colors.white, child: Column(mainAxisSize:MainAxisSize.min, children: [
        Container(width:double.infinity, padding: const EdgeInsets.symmetric(horizontal:8, vertical:5), color:color, child: Row(children:[
          Container(width:14, height:14, decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.3), borderRadius:BorderRadius.circular(2))),
          const SizedBox(width:4),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, mainAxisSize:MainAxisSize.min, children:[Container(height:4,width:60,color:Colors.white.withValues(alpha:0.9),margin:const EdgeInsets.only(bottom:2)),Container(height:3,width:40,color:Colors.white.withValues(alpha:0.5))])),
          Column(crossAxisAlignment:CrossAxisAlignment.end, mainAxisSize:MainAxisSize.min, children:[Container(height:4,width:40,color:Colors.white.withValues(alpha:0.9),margin:const EdgeInsets.only(bottom:2)),Container(height:3,width:25,color:Colors.white.withValues(alpha:0.5))]),
        ])),
        ...bloques.take(7).map((b) => _bloque(b, color)),
      ]));
    }

    return Center(child: FittedBox(fit:BoxFit.contain,
      child: SizedBox(width:297, height:420, child: content)));
  }

  // Versión wireframe para Stack (no necesita margen ni padding propio)
  Widget _bloqueWire(Map<String,dynamic> b, Color c) {
    final tipo = b['tipo'] as String? ?? '';
    switch(tipo) {
      case 'header': return Container(color:c, child:Row(children:[const SizedBox(width:2),Container(width:8,height:8,color:Colors.white.withValues(alpha:0.4)),const SizedBox(width:2),Expanded(child:Container(height:3,color:Colors.white.withValues(alpha:0.8)))]));
      case 'tabla_lineas': return Column(children:[Expanded(flex:2,child:Container(color:c)),Expanded(child:Container(color:Colors.grey.shade100)),Expanded(child:Container(color:Colors.grey.shade50))]);
      case 'totales': return Align(alignment:Alignment.centerRight,child:Container(width:60,child:Column(children:[Container(height:2,color:Colors.grey.shade400,margin:const EdgeInsets.only(bottom:1)),Container(height:2,color:Colors.grey.shade400,margin:const EdgeInsets.only(bottom:1)),Container(height:3,color:c)])));
      case 'cliente': return Container(decoration:BoxDecoration(color:c.withValues(alpha:0.06),border:Border.all(color:c.withValues(alpha:0.2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(height:2,width:30,color:c.withValues(alpha:0.6)),Container(height:2,width:50,color:Colors.grey.shade400)]));
      case 'separador': return Divider(height:1,color:Colors.grey.shade300);
      case 'footer': return Container(color:Colors.grey.shade100,child:Center(child:Container(height:1,width:60,color:Colors.grey.shade300)));
      case 'qr_verifactu': return Align(alignment:Alignment.bottomRight,child:Container(width:12,height:12,decoration:BoxDecoration(border:Border.all(color:c,width:1),borderRadius:BorderRadius.circular(1))));
      case 'indice': return Container(padding:const EdgeInsets.all(4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(height:3,width:40,color:c,margin:const EdgeInsets.only(bottom:3)),Container(height:2,width:70,color:Colors.grey.shade300,margin:const EdgeInsets.only(bottom:2)),Container(height:2,width:60,color:Colors.grey.shade300,margin:const EdgeInsets.only(bottom:2)),Container(height:2,width:50,color:Colors.grey.shade300)]));
      default: return Container(decoration:BoxDecoration(color:c.withValues(alpha:0.04),borderRadius:BorderRadius.circular(2)),child:Container(height:2,color:Colors.grey.shade200));
    }
  }

  Widget _bloque(Map<String,dynamic> b, Color c) {
    final tipo = b['tipo'] as String? ?? '';
    switch(tipo) {
      case 'header': return const SizedBox.shrink();
      case 'cliente': return Container(margin:const EdgeInsets.symmetric(horizontal:6,vertical:2),padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:c.withValues(alpha:0.06),borderRadius:BorderRadius.circular(3),border:Border.all(color:c.withValues(alpha:0.2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(height:3,width:40,color:c.withValues(alpha:0.7),margin:const EdgeInsets.only(bottom:2)),Container(height:3,width:70,color:Colors.grey.shade400,margin:const EdgeInsets.only(bottom:1)),Container(height:2,width:55,color:Colors.grey.shade300)]));
      case 'info_documento': return Padding(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),child:Align(alignment:Alignment.centerRight,child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Container(height:3,width:50,color:Colors.grey.shade500,margin:const EdgeInsets.only(bottom:1)),Container(height:2,width:38,color:Colors.grey.shade300)])));
      case 'tabla_lineas': return Column(children:[Container(height:8,width:double.infinity,margin:const EdgeInsets.symmetric(horizontal:6),color:c,child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:Row(children:[Expanded(child:Container(height:2,color:Colors.white.withValues(alpha:0.7))),const SizedBox(width:8),Container(width:20,height:2,color:Colors.white.withValues(alpha:0.7))]))),_fila(Colors.white,c),_fila(c.withValues(alpha:0.04),c),_fila(Colors.white,c)]);
      case 'totales': return Align(alignment:Alignment.centerRight,child:Container(width:80,margin:const EdgeInsets.only(right:6,top:2,bottom:2),child:Column(children:[_rowT(Colors.grey.shade400,Colors.grey.shade400),_rowT(Colors.grey.shade400,Colors.grey.shade400),Divider(height:3,color:c.withValues(alpha:0.4)),_rowT(c.withValues(alpha:0.8),c)])));
      case 'forma_pago': return Container(margin:const EdgeInsets.symmetric(horizontal:6,vertical:2),padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:c.withValues(alpha:0.05),borderRadius:BorderRadius.circular(2)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(height:2,width:35,color:c.withValues(alpha:0.6),margin:const EdgeInsets.only(bottom:1)),Container(height:2,width:55,color:Colors.grey.shade300)]));
      case 'qr_verifactu': return Padding(padding:const EdgeInsets.only(right:6,bottom:3),child:Align(alignment:Alignment.centerRight,child:Container(width:16,height:16,decoration:BoxDecoration(border:Border.all(color:c,width:1.5),borderRadius:BorderRadius.circular(2)),child:GridView.count(crossAxisCount:3,padding:const EdgeInsets.all(1),mainAxisSpacing:1,crossAxisSpacing:1,children:List.generate(9,(i)=>Container(color:i%2==0?c:Colors.white))))));
      case 'notas': case 'texto_libre': return Padding(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(height:2,width:double.infinity,color:Colors.grey.shade200,margin:const EdgeInsets.only(bottom:1)),Container(height:2,width:120,color:Colors.grey.shade200)]));
      case 'separador': return Divider(height:6,indent:6,endIndent:6,color:Colors.grey.shade300);
      case 'espaciador': return const SizedBox(height:4);
      case 'tabla_fichajes': return Column(children:[Container(height:7,width:double.infinity,margin:const EdgeInsets.symmetric(horizontal:6),color:c),_fila(Colors.white,c),_fila(c.withValues(alpha:0.04),c)]);
      case 'resumen_horas': return Container(margin:const EdgeInsets.symmetric(horizontal:6,vertical:2),padding:const EdgeInsets.all(4),color:c.withValues(alpha:0.05),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_stat(c),_stat(c),_stat(Colors.orange)]));
      case 'info_empleado': return Container(margin:const EdgeInsets.symmetric(horizontal:6,vertical:2),padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:c.withValues(alpha:0.05),borderRadius:BorderRadius.circular(2),border:Border.all(color:c.withValues(alpha:0.15))),child:Row(children:[CircleAvatar(radius:5,backgroundColor:c.withValues(alpha:0.3)),const SizedBox(width:4),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(height:3,width:40,color:Colors.grey.shade500,margin:const EdgeInsets.only(bottom:1)),Container(height:2,width:28,color:Colors.grey.shade300)])]));
      case 'footer': return Container(margin:const EdgeInsets.only(top:2),padding:const EdgeInsets.symmetric(vertical:2),child:Center(child:Container(height:2,width:100,color:Colors.grey.shade300)));
      case 'indice': return Container(margin:const EdgeInsets.symmetric(horizontal:6,vertical:2),padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:c.withValues(alpha:0.05),border:Border.all(color:c.withValues(alpha:0.2)),borderRadius:BorderRadius.circular(3)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(height:3,width:38,color:c,margin:const EdgeInsets.only(bottom:4)),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Container(height:2,width:50,color:Colors.grey.shade400),Container(height:2,width:10,color:Colors.grey.shade400)]),const SizedBox(height:2),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Container(height:2,width:40,color:Colors.grey.shade300),Container(height:2,width:10,color:Colors.grey.shade300)]),const SizedBox(height:2),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Container(height:2,width:30,color:Colors.grey.shade300),Container(height:2,width:10,color:Colors.grey.shade300)])]));
      default: return Container(height:4,margin:const EdgeInsets.symmetric(horizontal:6,vertical:1),color:Colors.grey.shade100);
    }
  }

  Widget _fila(Color bg, Color c) => Container(height:6,margin:const EdgeInsets.symmetric(horizontal:6),color:bg,child:Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:1),child:Row(children:[Expanded(child:Container(height:2,color:Colors.grey.shade300)),const SizedBox(width:8),Container(width:15,height:2,color:c.withValues(alpha:0.5))])));
  Widget _rowT(Color l, Color r) => Padding(padding:const EdgeInsets.symmetric(vertical:0.5),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Container(height:2,width:30,color:l),Container(height:2,width:18,color:r)]));
  Widget _stat(Color c) => Column(mainAxisSize:MainAxisSize.min,children:[Container(height:6,width:14,color:c.withValues(alpha:0.7),margin:const EdgeInsets.only(bottom:1)),Container(height:2,width:10,color:Colors.grey.shade300)]);

  // ── Acciones ────────────────────────────────────────────────────────────────
  void _nueva() => Navigator.push(context, MaterialPageRoute(builder:(_) => TemplateEditorScreen(empresaId:widget.empresaId)));
  void _editar(PdfTemplate p) => Navigator.push(context, MaterialPageRoute(builder:(_) => TemplateEditorScreen(empresaId:widget.empresaId, plantillaInicial:p)));

  Future<void> _toggleActiva(PdfTemplate p) async {
    try {
      await _svc.toggleActiva(p.id, !p.activa);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }


  Widget _error([Object? err]) {
    final msg = err?.toString() ?? '';
    final esIndice = msg.contains('index') || msg.contains('FAILED_PRECONDITION');
    return Center(child: Padding(padding:const EdgeInsets.all(24), child: Column(mainAxisSize:MainAxisSize.min, children:[
      Icon(esIndice ? Icons.search_off : Icons.lock_outline, size:48, color:Colors.orange),
      const SizedBox(height:12),
      Text(esIndice ? 'Índice Firestore faltante' : 'Sin permisos — despliega las reglas Firestore', textAlign:TextAlign.center, style:const TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      Text(esIndice ? 'firebase deploy --only firestore:indexes' : 'firebase deploy --only firestore:rules', style:TextStyle(fontFamily:'monospace', fontSize:11, color:Colors.grey[600])),
      if (msg.isNotEmpty) ...[const SizedBox(height:8), Text(msg, style:TextStyle(fontSize:9, color:Colors.grey[500]), textAlign:TextAlign.center, maxLines:3, overflow:TextOverflow.ellipsis)],
    ])));
  }

}

// ═══════════════════════════════════════════════════════════════════════════
// Widget que renderiza la primera página del PDF como imagen en la tarjeta
// ═══════════════════════════════════════════════════════════════════════════

class _PdfCardPreview extends StatefulWidget {
  final PdfTemplate plantilla;
  final String empresaId;
  const _PdfCardPreview({required this.plantilla, required this.empresaId});

  @override
  State<_PdfCardPreview> createState() => _PdfCardPreviewState();
}

class _PdfCardPreviewState extends State<_PdfCardPreview> {
  // Caché estático para no regenerar el PDF de cada plantilla en cada rebuild
  static final _cache = <String, Future<MemoryImage>>{};

  Future<MemoryImage> _getImage() {
    final key = '${widget.plantilla.id}_${widget.plantilla.colorPrimario}_${widget.plantilla.colorSecundario}';
    return _cache.putIfAbsent(key, () async {
      final bytes = await PdfService.generarPreviewBytes(
          widget.plantilla, widget.empresaId);
      // Rasterizar la primera página del PDF a una imagen PNG
      final pages = Printing.raster(bytes, dpi: 120);
      final page = await pages.first;
      return MemoryImage(await page.toPng());
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MemoryImage>(
      future: _getImage(),
      builder: (ctx, snap) {
        if (snap.hasData) {
          return Image(
            image: snap.data!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          );
        }
        if (snap.hasError) {
          // Fallback: mostrar fondo de color si falla la renderización
          return Container(
            color: const Color(0xFFEEF1F6),
            child: Center(child: Icon(
              Icons.description_outlined,
              color: const Color(0xFFCBD5E1),
              size: 32,
            )),
          );
        }
        return Container(
          color: const Color(0xFFEEF1F6),
          child: const Center(child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6D5EF8)),
          )),
        );
      },
    );
  }
}

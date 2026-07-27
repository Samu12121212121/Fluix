import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/pdf_template.dart';
import '../../data/pdf_template_service.dart';
import '../widgets/bloques_catalog.dart';

const _kPurple      = Color(0xFF6D5EF8);
const _kPurpleLight = Color(0xFFECE9FE);
const _kBg          = Color(0xFFEEF1F6);
const _kCanvas      = Color(0xFFE3E7EE);
const _kText        = Color(0xFF12131A);
const _kTextSec     = Color(0xFF6B7280);
const _kTextTer     = Color(0xFF9CA3AF);

Color _hx(String h) { try { return Color(int.parse('FF${h.replaceAll('#','')}', radix:16)); } catch(_){ return _kPurple; } }

// ── Geometry helpers stored in props with _ prefix ───────────────────────────
double _gx(Map p, int idx) => (p['_x'] as num?)?.toDouble() ?? 14.0;
double _gy(Map p, int idx) => (p['_y'] as num?)?.toDouble() ?? _defY(p['tipo'] as String? ?? '', idx);
double _gw(Map p)          => (p['_w'] as num?)?.toDouble() ?? 567.0;
double _gh(Map p)          => (p['_h'] as num?)?.toDouble() ?? _defH(p['tipo'] as String? ?? '');
double _gop(Map p)         => (p['_opacity'] as num?)?.toDouble() ?? 100.0;

double _defY(String t, int idx) => switch(t) {
  'header'         => 0,   'info_documento' => 75,  'cliente'      => 120,
  'tabla_lineas'   => 210, 'totales'        => 370, 'forma_pago'   => 460,
  'qr_verifactu'   => 530, 'notas'          => 610, 'footer'       => 790,
  'info_empleado'  => 75,  'tabla_fichajes' => 160, 'resumen_horas'=> 380,
  _ => max(0.0, 14.0 + idx * 70.0),
};
double _defH(String t) => switch(t) {
  'header'      => 65,  'cliente'     => 90,  'info_documento'  => 45,
  'tabla_lineas'=> 140, 'totales'     => 85,  'forma_pago'      => 55,
  'qr_verifactu'=> 65,  'notas'       => 45,  'footer'          => 30,
  'info_empleado'=> 55, 'tabla_fichajes'=> 120,'resumen_horas'  => 70,
  'separador'   => 20,  'espaciador'  => 20,  'texto_libre'     => 45,
  _ => 60,
};

class TemplateEditorScreen extends StatefulWidget {
  final String empresaId;
  final PdfTemplate? plantillaInicial;
  const TemplateEditorScreen({super.key, required this.empresaId, this.plantillaInicial});
  @override State<TemplateEditorScreen> createState() => _State();
}

class _State extends State<TemplateEditorScreen> {
  final _svc = PdfTemplateService();
  bool _guardando = false;
  late String _nombre, _descripcion, _colorPrimario;
  late TipoDocumentoPdf _tipo;
  late double _margenH, _margenV, _zoom;
  late List<Map<String,dynamic>> _bloques;
  int? _selIdx;
  String _catFiltro = 'Todos';
  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool get _esNueva => widget.plantillaInicial == null;
  Map<String,dynamic> _empresaData = {};

  @override
  void initState() {
    super.initState();
    final p = widget.plantillaInicial;
    _nombre = p?.nombre ?? '';  _descripcion = p?.descripcion ?? '';
    _tipo = p?.tipo ?? TipoDocumentoPdf.factura;
    _colorPrimario = p?.colorPrimario ?? '#1565C0';
    _margenH = p?.margenHorizontal ?? 36;  _margenV = p?.margenVertical ?? 36;
    _zoom = 1.0;
    _bloques = p != null ? List.from(p.bloques) : List.from(PdfTemplate.defaultFactura(widget.empresaId).bloques);
    _nomCtrl.text = _nombre;  _descCtrl.text = _descripcion;
    _cargarEmpresa();
  }

  Future<void> _cargarEmpresa() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).get();
      if (doc.exists && mounted) setState(() => _empresaData = doc.data() ?? {});
    } catch (_) {}
  }

  @override void dispose() { _nomCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.shortestSide < 600) {
      return Scaffold(backgroundColor:_kBg,body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        Container(width:72,height:72,decoration:BoxDecoration(color:_kPurpleLight,shape:BoxShape.circle),child:const Icon(Icons.desktop_windows_outlined,color:_kPurple,size:36)),
        const SizedBox(height:24),
        const Text('Pantalla insuficiente',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:_kText)),
        const SizedBox(height:12),
        const Text('El editor de plantillas requiere\nuna pantalla de mínimo 11 pulgadas.',textAlign:TextAlign.center,style:TextStyle(color:_kTextSec,fontSize:14,height:1.5)),
        const SizedBox(height:24),
        GestureDetector(onTap:()=>Navigator.pop(context),child:Container(padding:const EdgeInsets.symmetric(horizontal:24,vertical:12),decoration:BoxDecoration(color:_kPurple,borderRadius:BorderRadius.circular(12)),child:const Text('Volver',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700)))),
      ])));
    }
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _topbar(),
        Expanded(child: _desktop()),
      ]),
    );
  }

  // ── Topbar ─────────────────────────────────────────────────────────────────
  Widget _topbar() => Container(
    padding: const EdgeInsets.symmetric(horizontal:20,vertical:13),
    decoration: BoxDecoration(color:Colors.white,border:Border(bottom:BorderSide(color:Colors.grey.shade200))),
    child: Row(children:[
      GestureDetector(onTap:()=>Navigator.pop(context),child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.chevron_left,color:_kTextSec,size:16),const Text('Plantillas',style:TextStyle(color:_kTextSec,fontWeight:FontWeight.w500,fontSize:13))])),
      const SizedBox(width:14),
      Container(width:38,height:38,decoration:BoxDecoration(color:_kPurpleLight,borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.picture_as_pdf,color:_kPurple,size:18)),
      const SizedBox(width:10),
      Expanded(child:Text(_nombre.isEmpty?'Nueva plantilla':_nombre,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:15,color:_kText))),
      _topBtn('Guardar',Icons.save_outlined,true,_guardando?null:_guardar),
    ]),
  );

  Widget _topBtn(String lbl,IconData ic,bool primary,VoidCallback? fn)=>GestureDetector(onTap:fn,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),decoration:BoxDecoration(color:primary?_kPurple:Colors.white,borderRadius:BorderRadius.circular(11),border:Border.all(color:primary?_kPurple:Colors.grey.shade200)),child:Row(mainAxisSize:MainAxisSize.min,children:[if(_guardando&&primary)const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))else Icon(ic,size:14,color:primary?Colors.white:_kText),const SizedBox(width:6),Text(lbl,style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:primary?Colors.white:_kText))])));

  Widget _desktop()=>Row(children:[Expanded(flex:29,child:_toolbox()),Container(width:1,color:Colors.grey.shade200),Expanded(flex:62,child:_canvas()),Container(width:1,color:Colors.grey.shade200),Expanded(flex:29,child:_inspector())]);


  // ── Toolbox ────────────────────────────────────────────────────────────────
  Widget _toolbox() {
    const cats = ['Todos','Empresa','Cliente','Facturación','Fichajes','Genérico'];
    final filtrados = _catFiltro=='Todos' ? kBloquesDisponibles : kBloquesDisponibles.where((b)=>b.categoria==_catFiltro).toList();
    return Container(color:Colors.white,child:Column(children:[
      _pTitle(Icons.style_outlined,'Cambiar de plantilla'),
      _miniTplSwitcher(),
      _pTitle(Icons.widgets_outlined,'Elementos'),
      SizedBox(height:32,child:ListView.builder(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),itemCount:cats.length,itemBuilder:(_,i){final c=cats[i];final sel=c==_catFiltro;return GestureDetector(onTap:()=>setState(()=>_catFiltro=c),child:Container(margin:const EdgeInsets.only(right:4),padding:const EdgeInsets.symmetric(horizontal:7,vertical:2),decoration:BoxDecoration(color:sel?_kPurple:Colors.grey.shade100,borderRadius:BorderRadius.circular(10),border:Border.all(color:sel?_kPurple:Colors.grey.shade300)),child:Text(c,style:TextStyle(fontSize:9,color:sel?Colors.white:_kTextSec,fontWeight:sel?FontWeight.bold:FontWeight.normal))));})),
      const Divider(height:1),
      Expanded(child:GridView.builder(padding:const EdgeInsets.all(8),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,childAspectRatio:1.8,crossAxisSpacing:5,mainAxisSpacing:5),itemCount:filtrados.length,itemBuilder:(_,i)=>_libItem(filtrados[i]))),
    ]));
  }

  Widget _pTitle(IconData ic,String lbl)=>Padding(padding:const EdgeInsets.fromLTRB(10,10,10,6),child:Row(children:[Icon(ic,size:13,color:_kPurple),const SizedBox(width:6),Text(lbl.toUpperCase(),style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:_kTextTer,letterSpacing:0.8))]));

  Widget _miniTplSwitcher()=>SizedBox(height:82,child:ListView.builder(scrollDirection:Axis.horizontal,padding:const EdgeInsets.fromLTRB(8,4,8,8),itemCount:TipoDocumentoPdf.values.length,itemBuilder:(_,i){final t=TipoDocumentoPdf.values[i];final sel=t==_tipo;return GestureDetector(onTap:()=>setState((){_tipo=t;final prev=PdfTemplate.defaultParaTipo(widget.empresaId,t);_bloques=List.from(prev.bloques);_colorPrimario=prev.colorPrimario;_selIdx=null;}),child:Container(width:52,margin:const EdgeInsets.only(right:6),child:Column(children:[Container(width:52,height:52,decoration:BoxDecoration(color:Colors.grey.shade50,borderRadius:BorderRadius.circular(6),border:Border.all(color:sel?_kPurple:Colors.grey.shade200,width:sel?2:1)),child:Center(child:Text(t.icon,style:const TextStyle(fontSize:20)))),Text(t.label,style:const TextStyle(fontSize:7,color:_kTextTer),maxLines:1,overflow:TextOverflow.ellipsis)])));
  }));

  Widget _libItem(BloqueDisponible b)=>Draggable<BloqueDisponible>(data:b,feedback:Material(elevation:6,borderRadius:BorderRadius.circular(8),child:Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:_kPurple,borderRadius:BorderRadius.circular(8)),child:Row(mainAxisSize:MainAxisSize.min,children:[Text(b.icono),const SizedBox(width:4),Text(b.nombre,style:const TextStyle(color:Colors.white,fontSize:10))]))),childWhenDragging:Opacity(opacity:0.4,child:_libCard(b)),child:_libCard(b));
  Widget _libCard(BloqueDisponible b)=>GestureDetector(onTap:()=>_addBloque(b),child:Container(decoration:BoxDecoration(color:_kBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.grey.shade200)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(b.icono,style:const TextStyle(fontSize:16)),const SizedBox(height:3),Text(b.nombre,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:_kTextSec),textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis)])));

  // ── Canvas con posicionamiento libre ───────────────────────────────────────
  Widget _canvas() => Container(color:_kCanvas,child:Column(children:[
    Container(color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),child:Row(children:[const Icon(Icons.article_outlined,size:13,color:_kTextSec),const SizedBox(width:5),Text('A4 · ${_bloques.length} elementos',style:const TextStyle(fontSize:11,color:_kTextSec)),const Spacer(),Text('Zoom ${(_zoom*100).round()}%',style:const TextStyle(fontSize:9,color:_kTextTer))])),
    Expanded(child:CustomPaint(painter:_DotPainter(),child:GestureDetector(
      onTap:()=>setState(()=>_selIdx=null),
      child:SingleChildScrollView(child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Padding(padding:const EdgeInsets.all(36),child:_canvasContent()),
      )),
    ))),
  ]));

  Widget _canvasContent() => DragTarget<BloqueDisponible>(
    onAcceptWithDetails:(d)=>_addBloque(d.data),
    builder:(ctx,cand,_)=>Transform.scale(
      scale:_zoom, alignment:Alignment.topLeft,
      child:Container(
        width:595, height:842,
        decoration:BoxDecoration(color:Colors.white,boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.18),blurRadius:40,offset:const Offset(0,8))],border:cand.isNotEmpty?Border.all(color:_kPurple,width:2):null),
        child:Stack(clipBehavior:Clip.none,children:[
          if(_bloques.isEmpty) Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(Icons.add_box_outlined,size:56,color:Colors.grey.withValues(alpha:0.4)),
            const SizedBox(height:10),
            Text('Arrastra elementos aquí\no haz clic en un bloque del panel',textAlign:TextAlign.center,style:TextStyle(color:Colors.grey.withValues(alpha:0.6),fontSize:13)),
          ])),
          ..._bloques.asMap().entries.map((e) => _CanvasBlock(
            key: ValueKey('cb_${e.value['id']??e.key}'),
            idx: e.key,
            bloque: e.value,
            selected: _selIdx == e.key,
            onSelect: () => setState(() => _selIdx = e.key),
            onGeomChanged: (x,y,w,h,op) => setState(() => _updGeom(e.key,x,y,w,h,op)),
            onDelete: () => setState(() { _bloques.removeAt(e.key); _selIdx = null; }),
            onDuplicate: () => setState((){
              final b=Map<String,dynamic>.from(_bloques[e.key]);
              final p=Map<String,dynamic>.from(b['props'] as Map<String,dynamic>? ?? {});
              p['_x']=(p['_x'] as num? ?? 14)+20; p['_y']=(p['_y'] as num? ?? 14)+20;
              b['props']=p; b['id']='${b['tipo']}_${DateTime.now().millisecondsSinceEpoch}';
              _bloques.insert(e.key+1,b); _selIdx=e.key+1;
            }),
            onToggleVisible: () => _toggleActivo(e.key),
            preview: _bloquePreview,
          )),
        ]),
      ),
    ),
  );


  void _updGeom(int idx,double x,double y,double w,double h,double op){final b=Map<String,dynamic>.from(_bloques[idx]);final p=Map<String,dynamic>.from(b['props'] as Map<String,dynamic>? ?? {});p['_x']=x;p['_y']=y;p['_w']=w;p['_h']=h;p['_opacity']=op;b['props']=p;_bloques[idx]=b;}

  // ── Inspector ─────────────────────────────────────────────────────────────
  Widget _inspector()=>Container(color:Colors.white,child:Column(children:[_pTitle(Icons.tune,'Propiedades'),Expanded(child:DefaultTabController(length:2,child:Column(children:[TabBar(labelColor:_kPurple,unselectedLabelColor:_kTextSec,indicatorColor:_kPurple,tabs:const[Tab(text:'Bloque'),Tab(text:'Plantilla')]),Expanded(child:TabBarView(children:[_inspBloque(),_inspPlantilla()]))])))]));

  Widget _inspBloque() {
    if(_selIdx==null||_bloques.isEmpty) return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.mouse_outlined,size:36,color:Colors.grey.shade300),const SizedBox(height:12),const Text('Nada seleccionado',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13)),const SizedBox(height:6),const Text('Haz clic sobre un elemento\npara editar sus propiedades.',textAlign:TextAlign.center,style:TextStyle(color:_kTextSec,fontSize:12,height:1.5))])));
    final b=_bloques[_selIdx!]; final tipo=b['tipo'] as String? ?? '';
    final bp=b['props'] as Map<String,dynamic>? ?? {};
    final p=Map<String,dynamic>.from(bp);
    final x=_gx(bp,_selIdx!);final y=_gy(bp,_selIdx!);final w=_gw(bp);final h=_gh(bp);final op=_gop(bp);
    return SingleChildScrollView(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(_nomBlq(tipo),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
      const SizedBox(height:10),
      // Posición y tamaño (como el HTML)
      _pg(Icons.open_with,'Posición y tamaño',Column(children:[
        Row(children:[Expanded(child:_numF('X',x,(v)=>_updGeom(_selIdx!,v,y,w,h,op))),const SizedBox(width:8),Expanded(child:_numF('Y',y,(v)=>_updGeom(_selIdx!,x,v,w,h,op)))]),
        const SizedBox(height:8),
        Row(children:[Expanded(child:_numF('Ancho',w,(v)=>_updGeom(_selIdx!,x,y,max(20,v),h,op))),const SizedBox(width:8),Expanded(child:_numF('Alto',h,(v)=>_updGeom(_selIdx!,x,y,w,max(10,v),op)))]),
        const SizedBox(height:4),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Opacidad',style:TextStyle(fontSize:11)),Text('${op.round()}%',style:const TextStyle(fontSize:11,color:_kTextSec))]),
        Slider(value:op.clamp(10,100),min:10,max:100,activeColor:_kPurple,onChanged:(v)=>setState(()=>_updGeom(_selIdx!,x,y,w,h,v))),
      ])),
      ..._propsParaTipo(tipo,p),
      // Acciones (Frente/Fondo/Duplicar/Eliminar como el HTML)
      _pg(Icons.layers,'Acciones',Wrap(spacing:6,runSpacing:6,children:[
        _acBtn('Frente',Icons.vertical_align_top,_toFront),
        _acBtn('Fondo',Icons.vertical_align_bottom,_toBack),
        _acBtn('Duplicar',Icons.copy_outlined,(){
          if(_selIdx==null)return;
          setState((){final b=Map<String,dynamic>.from(_bloques[_selIdx!]);final p=Map<String,dynamic>.from(b['props'] as Map<String,dynamic>? ?? {});p['_x']=(p['_x'] as num? ?? 14)+20;p['_y']=(p['_y'] as num? ?? 14)+20;b['props']=p;b['id']='${b['tipo']}_${DateTime.now().millisecondsSinceEpoch}';_bloques.insert(_selIdx!+1,b);_selIdx=_selIdx!+1;});
        }),
        _acBtn('Eliminar',Icons.delete_outline,()=>_delBloque(_selIdx!),danger:true),
      ])),
    ]));
  }

  Widget _pg(IconData ic,String lbl,Widget child)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_kBg,border:Border.all(color:Colors.grey.shade200),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(ic,size:13,color:_kPurple),const SizedBox(width:5),Text(lbl.toUpperCase(),style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:_kTextSec,letterSpacing:0.5))]),const SizedBox(height:10),child]));
  Widget _numF(String lbl,double val,void Function(double) fn)=>TextField(controller:TextEditingController(text:val.toStringAsFixed(0)),decoration:InputDecoration(labelText:lbl,isDense:true,border:const OutlineInputBorder(),contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:6)),style:const TextStyle(fontSize:11),keyboardType:TextInputType.number,onSubmitted:(v){final d=double.tryParse(v);if(d!=null)setState(()=>fn(d));});
  Widget _acBtn(String lbl,IconData ic,VoidCallback fn,{bool danger=false})=>GestureDetector(onTap:fn,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:danger?Colors.red.shade50:Colors.white,borderRadius:BorderRadius.circular(9),border:Border.all(color:danger?Colors.red.shade200:Colors.grey.shade200)),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(ic,size:13,color:danger?Colors.red:_kText),const SizedBox(width:5),Text(lbl,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:danger?Colors.red:_kText))])));

  List<Widget> _propsParaTipo(String tipo,Map<String,dynamic> p)=>switch(tipo){
    'header'        =>[_pg(Icons.palette,'Estilo',Column(children:[_pColor('Color fondo','color_fondo',p),_pColor('Color texto','color_texto',p),_pSlider('Padding','padding',p,0,40),_pSwitch('Logo','mostrar_logo',p)]))],
    'cliente'       =>[_pg(Icons.person,'Cliente',Column(children:[_pText('Título','titulo',p),_pColor('Color fondo','color_fondo',p),_pSwitch('NIF','mostrar_nif',p),_pSwitch('Dirección','mostrar_direccion',p)]))],
    'tabla_lineas'  =>[_pg(Icons.table_chart,'Tabla',Column(children:[_pColor('Cabecera','color_cabecera',p),_pColor('Fila par','color_fila_par',p),_pSwitch('Cantidad','mostrar_cantidad',p),_pSwitch('IVA','mostrar_iva',p)]))],
    'totales'       =>[_pg(Icons.calculate,'Totales',Column(children:[_pSwitch('Base','mostrar_base',p),_pSwitch('IVA','mostrar_iva',p),_pSwitch('IRPF','mostrar_irpf',p),_pSwitch('Total','mostrar_total',p)]))],
    'texto_libre'   =>[_pg(Icons.text_fields,'Texto',Column(children:[_pTextArea('Contenido','contenido',p),_pSlider('Tamaño','tamano_fuente',p,6,24),_pColor('Color','color_texto',p),_pSwitch('Negrita','negrita',p)]))],
    'notas'         =>[_pg(Icons.notes,'Notas',Column(children:[_pTextArea('Texto','placeholder',p),_pSlider('Tamaño','tamano_fuente',p,6,20),_pColor('Color','color_texto',p)]))],
    'forma_pago'    =>[_pg(Icons.credit_card,'Pago',Column(children:[_pColor('Fondo','color_fondo',p),_pSwitch('Método','mostrar_metodo',p),_pSwitch('IBAN','mostrar_iban',p)]))],
    'separador'     =>[_pg(Icons.horizontal_rule,'Separador',Column(children:[_pColor('Color','color',p),_pSlider('Grosor','grosor',p,0.5,4)]))],
    'espaciador'    =>[_pg(Icons.height,'Espaciador',_pSlider('Altura','altura',p,4,64))],
    'qr_verifactu'  =>[_pg(Icons.qr_code,'QR',Column(children:[_pSlider('Tamaño','tamano',p,40,100),_pSwitch('Etiqueta','mostrar_etiqueta',p)]))],
    'tabla_fichajes'=>[_pg(Icons.table_rows,'Fichajes',Column(children:[_pColor('Cabecera','color_cabecera',p),_pSwitch('Fecha','mostrar_fecha',p),_pSwitch('Entrada','mostrar_entrada',p)]))],
    'resumen_horas' =>[_pg(Icons.bar_chart,'Resumen',Column(children:[_pSwitch('Total horas','mostrar_total_horas',p),_pSwitch('Horas extra','mostrar_horas_extra',p)]))],
    'info_empleado' =>[_pg(Icons.badge,'Empleado',Column(children:[_pSwitch('Nombre','mostrar_nombre',p),_pSwitch('Puesto','mostrar_puesto',p)]))],
    'footer'        =>[_pg(Icons.vertical_align_bottom,'Footer',Column(children:[_pText('Texto','contenido',p),_pSlider('Tamaño','tamano_fuente',p,6,14),_pColor('Color','color_texto',p)]))],
    _               =>[],
  };

  Widget _inspPlantilla()=>SingleChildScrollView(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    _pg(Icons.info_outline,'Información',Column(children:[TextField(controller:_nomCtrl,decoration:const InputDecoration(labelText:'Nombre',isDense:true,border:OutlineInputBorder()),onChanged:(v)=>_nombre=v),const SizedBox(height:8),TextField(controller:_descCtrl,decoration:const InputDecoration(labelText:'Descripción',isDense:true,border:OutlineInputBorder()),maxLines:2,onChanged:(v)=>_descripcion=v)])),
    _pg(Icons.category,'Tipo',DropdownButtonFormField<TipoDocumentoPdf>(initialValue:_tipo,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder()),items:TipoDocumentoPdf.values.map((t)=>DropdownMenuItem(value:t,child:Text('${t.icon} ${t.label}',style:const TextStyle(fontSize:12)))).toList(),onChanged:(v){if(v!=null)setState((){final c=v!=_tipo;_tipo=v;if(c){final pr=PdfTemplate.defaultParaTipo(widget.empresaId,v);_bloques=List.from(pr.bloques);_colorPrimario=pr.colorPrimario;_selIdx=null;}});})),
    _pg(Icons.palette,'Color primario',Wrap(spacing:5,runSpacing:5,children:['#6D5EF8','#1565C0','#2E7D32','#D32F2F','#E65100','#7B1FA2','#00695C','#B71C1C','#424242','#000000'].map((hex){final sel=hex.toUpperCase()==_colorPrimario.toUpperCase();return GestureDetector(onTap:()=>setState(()=>_colorPrimario=hex),child:Container(width:26,height:26,decoration:BoxDecoration(color:_hx(hex),borderRadius:BorderRadius.circular(4),border:Border.all(color:sel?Colors.blue:Colors.transparent,width:2))));}).toList())),
    _pg(Icons.space_bar,'Márgenes',Column(children:[_slider2('H',_margenH,(v)=>setState(()=>_margenH=v)),_slider2('V',_margenV,(v)=>setState(()=>_margenV=v))])),
  ]));

  // ── Prop helpers ──────────────────────────────────────────────────────────
  Widget _pSwitch(String lbl,String key,Map<String,dynamic> p)=>SwitchListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(lbl,style:const TextStyle(fontSize:12)),value:p[key] as bool? ?? false,activeThumbColor:_kPurple,onChanged:(v)=>_updProp(key,v));
  Widget _pSlider(String lbl,String key,Map<String,dynamic> p,double min,double max){final val=(p[key] as num?)?.toDouble()??min;return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(lbl,style:const TextStyle(fontSize:12)),Text(val.toStringAsFixed(0),style:const TextStyle(fontSize:11,color:_kTextSec))]),Slider(value:val.clamp(min,max),min:min,max:max,activeColor:_kPurple,onChanged:(v)=>_updProp(key,v.roundToDouble()))]);}
  Widget _pText(String lbl,String key,Map<String,dynamic> p)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:TextField(controller:TextEditingController(text:p[key] as String? ?? ''),decoration:InputDecoration(labelText:lbl,isDense:true,border:const OutlineInputBorder()),style:const TextStyle(fontSize:12),onChanged:(v)=>_updProp(key,v)));
  Widget _pTextArea(String lbl,String key,Map<String,dynamic> p)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:TextField(controller:TextEditingController(text:p[key] as String? ?? ''),decoration:InputDecoration(labelText:lbl,isDense:true,border:const OutlineInputBorder()),style:const TextStyle(fontSize:12),maxLines:3,onChanged:(v)=>_updProp(key,v)));
  Widget _pColor(String lbl,String key,Map<String,dynamic> p){final hex=p[key] as String? ?? '#000000';const cols=['#6D5EF8','#1565C0','#0D47A1','#2E7D32','#D32F2F','#E65100','#7B1FA2','#00695C','#FFFFFF','#F5F9FF','#F5F5F5','#E0E0E0','#757575','#424242','#000000'];return Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:14,height:14,decoration:BoxDecoration(color:_hx(hex),borderRadius:BorderRadius.circular(3),border:Border.all(color:Colors.grey.shade300))),const SizedBox(width:6),Text(lbl,style:const TextStyle(fontSize:12))]),const SizedBox(height:4),Wrap(spacing:3,runSpacing:3,children:cols.map((h){final s=h.toUpperCase()==hex.toUpperCase();return GestureDetector(onTap:()=>_updProp(key,h),child:Container(width:20,height:20,decoration:BoxDecoration(color:_hx(h),borderRadius:BorderRadius.circular(3),border:Border.all(color:s?Colors.blue:Colors.grey.shade300,width:s?2:1)),child:s?const Icon(Icons.check,size:12,color:Colors.white):null));}).toList())]));}
  Widget _slider2(String lbl,double val,void Function(double) fn)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(lbl,style:const TextStyle(fontSize:11)),Text('${val.toStringAsFixed(0)}px',style:const TextStyle(fontSize:10,color:_kTextSec))]),Slider(value:val.clamp(0,72),min:0,max:72,activeColor:_kPurple,onChanged:fn)]);

  // ── Block preview ─────────────────────────────────────────────────────────
  Widget _bloquePreview(Map<String,dynamic> b) {
    final tipo=b['tipo'] as String? ?? '';
    final p=Map<String,dynamic>.from(b['props'] as Map? ?? {});
    switch(tipo) {
      case 'header':
        final cf=_hx(p['color_fondo'] as String? ?? '#1565C0');final ct=_hx(p['color_texto'] as String? ?? '#FFFFFF');
        final pr=_empresaData['perfil'] as Map? ?? {};
        final nE=(pr['nombre'] as String?)?.isNotEmpty==true?pr['nombre'] as String:(_empresaData['nombre'] as String? ?? 'MI EMPRESA S.L.');
        return Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:cf,borderRadius:BorderRadius.circular((p['border_radius'] as num?)?.toDouble()??8)),child:Row(children:[if(p['mostrar_logo']==true)...[Container(width:28,height:28,decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.2),borderRadius:BorderRadius.circular(3)),child:const Icon(Icons.business,color:Colors.white,size:16)),const SizedBox(width:6)],Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text(nE,style:TextStyle(color:ct,fontWeight:FontWeight.bold,fontSize:10)),Text(_empresaData['nif'] as String? ?? 'NIF: B12345678',style:TextStyle(color:ct.withValues(alpha:0.8),fontSize:7))])),Column(crossAxisAlignment:CrossAxisAlignment.end,mainAxisSize:MainAxisSize.min,children:[Text('FAC-2026-001',style:TextStyle(color:ct,fontWeight:FontWeight.bold,fontSize:8)),Text('01/06/2026',style:TextStyle(color:ct.withValues(alpha:0.7),fontSize:7))])]));
      case 'cliente':
        final cf=_hx(p['color_fondo'] as String? ?? '#F5F9FF');
        return Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:cf,borderRadius:BorderRadius.circular((p['border_radius'] as num?)?.toDouble()??8),border:Border.all(color:Colors.grey.shade200)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text(p['titulo'] as String? ?? 'FACTURAR A:',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:7,color:Color(0xFF1565C0))),const Text('Cliente Ejemplo S.A.',style:TextStyle(fontWeight:FontWeight.bold,fontSize:9)),if(p['mostrar_nif']==true) const Text('NIF: A87654321',style:TextStyle(fontSize:7,color:Colors.grey)),if(p['mostrar_direccion']==true) const Text('Calle Ejemplo, 1',style:TextStyle(fontSize:7,color:Colors.grey))]));
      case 'tabla_lineas':
        final cc=_hx(p['color_cabecera'] as String? ?? '#0D47A1');
        Widget fi(String d,String t,Color c)=>Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:2),color:c,child:Row(children:[Expanded(flex:4,child:Text(d,style:const TextStyle(fontSize:7))),SizedBox(width:46,child:Text(t,textAlign:TextAlign.right,style:const TextStyle(fontSize:7,fontWeight:FontWeight.bold)))]));
        return Column(children:[Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:4),color:cc,child:const Row(children:[Expanded(flex:4,child:Text('DESCRIPCIÓN',style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold))),SizedBox(width:46,child:Text('TOTAL',textAlign:TextAlign.right,style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold)))])),fi('Servicio ejemplo','121,00€',_hx(p['color_fila_par'] as String? ?? '#FFFFFF')),fi('Otro servicio','121,00€',_hx(p['color_fila_impar'] as String? ?? '#FAFBFC'))]);
      case 'totales':
        Widget rt(String l,String v,{Color? c})=>Padding(padding:const EdgeInsets.symmetric(vertical:1),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(l,style:TextStyle(fontSize:8,color:c??Colors.grey[700])),Text(v,style:TextStyle(fontSize:8,fontWeight:FontWeight.bold,color:c??Colors.black))]));
        return Align(alignment:Alignment.centerRight,child:SizedBox(width:150,child:Padding(padding:const EdgeInsets.all(6),child:Column(children:[if(p['mostrar_base']==true)rt('Base imponible','200,00 €'),if(p['mostrar_iva']==true)rt('IVA 21%','42,00 €'),if(p['mostrar_irpf']==true)rt('IRPF 15%','-30,00 €'),const Divider(height:4),rt('TOTAL','212,00 €',c:_kPurple)]))));
      case 'forma_pago': return Container(padding:const EdgeInsets.all(7),color:_hx(p['color_fondo'] as String? ?? '#F5F9FF'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[const Text('FORMA DE PAGO',style:TextStyle(fontWeight:FontWeight.bold,fontSize:7,color:Color(0xFF1565C0))),if(p['mostrar_metodo']==true) const Text('Transferencia',style:TextStyle(fontSize:7)),if(p['mostrar_iban']==true) const Text('IBAN: ES12 ...',style:TextStyle(fontSize:7,fontWeight:FontWeight.bold))]));
      case 'notas': case 'texto_libre':
        final txt=tipo=='notas'?(p['placeholder'] as String? ?? ''):(p['contenido'] as String? ?? '');
        return Padding(padding:const EdgeInsets.all(4),child:Text(txt,style:TextStyle(fontSize:(p['tamano_fuente'] as num?)?.toDouble()??9,color:_hx(p['color_texto'] as String? ?? '#757575'),fontStyle:p['cursiva']==true?FontStyle.italic:FontStyle.normal,fontWeight:p['negrita']==true?FontWeight.bold:FontWeight.normal)));
      case 'qr_verifactu': return Padding(padding:const EdgeInsets.all(4),child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[if(p['mostrar_etiqueta']==true) const Text('VERI*FACTU',style:TextStyle(fontSize:7,color:Color(0xFF0D47A1))),const SizedBox(width:4),Container(width:40,height:40,color:Colors.grey.shade200,child:const Icon(Icons.qr_code,color:Colors.grey,size:26))]));
      case 'separador': return Padding(padding:EdgeInsets.symmetric(vertical:(p['margen_vertical'] as num?)?.toDouble()??4),child:Divider(color:_hx(p['color'] as String? ?? '#E0E0E0'),height:(p['grosor'] as num?)?.toDouble()??1));
      case 'espaciador': return SizedBox(height:(p['altura'] as num?)?.toDouble()??16);
      case 'tabla_fichajes': return Column(children:[Container(padding:const EdgeInsets.all(4),color:_hx(p['color_cabecera'] as String? ?? '#0D47A1'),child:const Row(children:[Expanded(child:Text('FECHA',style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold))),Expanded(child:Text('ENTRADA',style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold))),Expanded(child:Text('HORAS',style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold)))])),const Padding(padding:EdgeInsets.symmetric(horizontal:4,vertical:3),child:Row(children:[Expanded(child:Text('01/01/2026',style:TextStyle(fontSize:7))),Expanded(child:Text('09:00',style:TextStyle(fontSize:7))),Expanded(child:Text('8h',style:TextStyle(fontSize:7,fontWeight:FontWeight.bold)))]))]);
      case 'resumen_horas': return Container(padding:const EdgeInsets.all(8),color:const Color(0xFFF5F9FF),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[if(p['mostrar_dias_trabajados']==true) const Column(children:[Text('22',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:_kPurple)),Text('Días',style:TextStyle(fontSize:7,color:Colors.grey))]),if(p['mostrar_total_horas']==true) const Column(children:[Text('176h',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:_kPurple)),Text('Total',style:TextStyle(fontSize:7,color:Colors.grey))]),if(p['mostrar_horas_extra']==true) const Column(children:[Text('8h',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:Color(0xFFE65100))),Text('Extra',style:TextStyle(fontSize:7,color:Colors.grey))])]));
      case 'info_empleado': return Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:const Color(0xFFF5F9FF),borderRadius:BorderRadius.circular(6),border:Border.all(color:Colors.grey.shade200)),child:Row(children:[const CircleAvatar(radius:12,child:Icon(Icons.person,size:12)),const SizedBox(width:7),Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[if(p['mostrar_nombre']==true) const Text('Juan García',style:TextStyle(fontWeight:FontWeight.bold,fontSize:9)),if(p['mostrar_puesto']==true) const Text('Desarrollador',style:TextStyle(fontSize:7,color:Colors.grey))])]));
      case 'footer': return Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text(p['contenido'] as String? ?? 'Pie de página',textAlign:TextAlign.center,style:TextStyle(fontSize:(p['tamano_fuente'] as num?)?.toDouble()??7,color:_hx(p['color_texto'] as String? ?? '#BDBDBD'))));
      case 'info_documento': return Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:12),child:Align(alignment:Alignment.centerRight,child:Column(crossAxisAlignment:CrossAxisAlignment.end,mainAxisSize:MainAxisSize.min,children:[if(p['mostrar_numero']==true) const Text('Nº: FAC-2026-001',style:TextStyle(fontSize:9,fontWeight:FontWeight.bold)),if(p['mostrar_fecha_emision']==true) const Text('Emisión: 01/01/2026',style:TextStyle(fontSize:8,color:Colors.grey))])));
      default: return Container(height:32,color:Colors.grey.shade100,child:Center(child:Text('[$tipo]',style:const TextStyle(color:Colors.grey,fontSize:9))));
    }
  }

  // ── State helpers ─────────────────────────────────────────────────────────
  void _addBloque(BloqueDisponible b) => setState((){
    final idx=_bloques.length;
    final p=Map<String,dynamic>.from(b.propsDefault);
    p['_x']=14.0; p['_y']=_defY(b.tipo,idx); p['_w']=567.0; p['_h']=_defH(b.tipo); p['_opacity']=100.0;
    _bloques.add({'id':'${b.tipo}_${DateTime.now().millisecondsSinceEpoch}','tipo':b.tipo,'orden':idx,'activo':true,'props':p});
    _selIdx=_bloques.length-1;
  });
  void _updProp(String key,dynamic val){if(_selIdx==null)return;setState((){final b=Map<String,dynamic>.from(_bloques[_selIdx!]);final p=Map<String,dynamic>.from(b['props'] as Map<String,dynamic>? ?? {});p[key]=val;b['props']=p;_bloques[_selIdx!]=b;});}
  void _toggleActivo(int idx)=>setState((){final b=Map<String,dynamic>.from(_bloques[idx]);b['activo']=!(b['activo'] as bool? ?? true);_bloques[idx]=b;});
  void _delBloque(int idx)=>setState((){_bloques.removeAt(idx);_selIdx=null;});
  void _toFront(){if(_selIdx==null)return;setState((){final b=_bloques.removeAt(_selIdx!);_bloques.add(b);_selIdx=_bloques.length-1;});}
  void _toBack(){if(_selIdx==null)return;setState((){final b=_bloques.removeAt(_selIdx!);_bloques.insert(0,b);_selIdx=0;});}

  Future<void> _guardar() async {
    if(_nombre.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Introduce un nombre'),backgroundColor:Colors.orange));return;}
    setState(()=>_guardando=true);
    try {
      final tpl=PdfTemplate(id:widget.plantillaInicial?.id??'',empresaId:widget.empresaId,nombre:_nombre.trim(),descripcion:_descripcion.trim(),tipo:_tipo,esDefault:widget.plantillaInicial?.esDefault??false,activa:true,fechaCreacion:widget.plantillaInicial?.fechaCreacion??DateTime.now(),fechaModificacion:DateTime.now(),colorPrimario:_colorPrimario,colorSecundario:widget.plantillaInicial?.colorSecundario??'#0D47A1',margenHorizontal:_margenH,margenVertical:_margenV,bloques:List.from(_bloques));
      if(_esNueva) await _svc.crearPlantilla(tpl); else await _svc.actualizarPlantilla(tpl);
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('✅ "${tpl.nombre}" guardada'),backgroundColor:Colors.green));Navigator.pop(context);}
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('❌ $e'),backgroundColor:Colors.red));
    } finally{if(mounted)setState(()=>_guardando=false);}
  }

}

// ── Top-level helper ──────────────────────────────────────────────────────────
String _nomBlq(String tipo) => kBloquesDisponibles
  .firstWhere((b)=>b.tipo==tipo, orElse:()=>BloqueDisponible(tipo:tipo,nombre:tipo,icono:'📄',categoria:'Genérico',propsDefault:const{}))
  .nombre;

// ── Canvas block widget — local drag state for 60fps smoothness ───────────────
class _CanvasBlock extends StatefulWidget {
  final int idx;
  final Map<String,dynamic> bloque;
  final bool selected;
  final VoidCallback onSelect, onDelete, onDuplicate, onToggleVisible;
  final void Function(double x,double y,double w,double h,double op) onGeomChanged;
  final Widget Function(Map<String,dynamic>) preview;
  const _CanvasBlock({required super.key, required this.idx, required this.bloque, required this.selected, required this.onSelect, required this.onDelete, required this.onDuplicate, required this.onToggleVisible, required this.onGeomChanged, required this.preview});
  @override State<_CanvasBlock> createState() => _CanvasBlockState();
}

class _CanvasBlockState extends State<_CanvasBlock> {
  double _dx=0, _dy=0;

  @override void didUpdateWidget(_CanvasBlock old) {
    super.didUpdateWidget(old);
    // When parent commits new position, reset local delta
    if (!widget.selected || old.bloque != widget.bloque) { _dx=0; _dy=0; }
  }

  @override
  Widget build(BuildContext ctx) {
    final p = widget.bloque['props'] as Map<String,dynamic>? ?? {};
    final x=_gx(p,widget.idx); final y=_gy(p,widget.idx);
    final w=_gw(p); final h=_gh(p); final op=_gop(p);
    final sel=widget.selected;
    final activo=widget.bloque['activo'] as bool? ?? true;
    final tipo=widget.bloque['tipo'] as String? ?? '';

    return Positioned(
      left: x+_dx, top: y+_dy, width: w, height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        // Only rebuild THIS widget on each drag frame — not the parent
        onPanUpdate: sel ? (d) => setState((){_dx+=d.delta.dx; _dy+=d.delta.dy;}) : null,
        onPanEnd: sel ? (_) {
          final nx=(x+_dx).clamp(0.0,595.0-w);
          final ny=(y+_dy).clamp(0.0,842.0-h);
          _dx=0; _dy=0;
          widget.onGeomChanged(nx,ny,w,h,op); // parent setState once on drop
        } : null,
        child: Stack(clipBehavior:Clip.none,children:[
          Opacity(
            opacity:(op/100).clamp(0.05,1.0)*(activo?1.0:0.3),
            child:ClipRect(child:SizedBox(width:w,height:h,child:widget.preview(widget.bloque))),
          ),
          if(sel)...[
            Positioned.fill(child:IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(border:Border.all(color:_kPurple,width:2))))),
            _rh(-5,-5,(ddx,ddy)=>widget.onGeomChanged((x+_dx+ddx).clamp(0,595),(y+_dy+ddy).clamp(0,842),max(20.0,w-ddx),max(10.0,h-ddy),op)),
            _rh(w-5,-5,(ddx,ddy)=>widget.onGeomChanged(x+_dx,y+_dy+ddy,max(20.0,w+ddx),max(10.0,h-ddy),op)),
            _rh(-5,h-5,(ddx,ddy)=>widget.onGeomChanged(x+_dx+ddx,y+_dy,max(20.0,w-ddx),max(10.0,h+ddy),op)),
            _rh(w-5,h-5,(ddx,ddy)=>widget.onGeomChanged(x+_dx,y+_dy,max(20.0,w+ddx),max(10.0,h+ddy),op)),
            Positioned(top:-28,right:0,child:Row(mainAxisSize:MainAxisSize.min,children:[
              _ib(activo?Icons.visibility_off:Icons.visibility,widget.onToggleVisible),
              _ib(Icons.copy_outlined,widget.onDuplicate),
              _ib(Icons.delete_outline,widget.onDelete,danger:true),
            ])),
          ],
          Positioned(top:3,left:3,child:IgnorePointer(child:Container(
            padding:const EdgeInsets.symmetric(horizontal:4,vertical:1),
            decoration:BoxDecoration(color:sel?_kPurple:Colors.black45,borderRadius:BorderRadius.circular(3)),
            child:Text(_nomBlq(tipo),style:const TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold)),
          ))),
        ]),
      ),
    );
  }

  Positioned _rh(double l,double t,void Function(double,double) fn) => Positioned(left:l,top:t,child:GestureDetector(onPanUpdate:(d)=>fn(d.delta.dx,d.delta.dy),child:Container(width:10,height:10,decoration:BoxDecoration(color:Colors.white,border:Border.all(color:_kPurple,width:2),borderRadius:BorderRadius.circular(2)))));
  Widget _ib(IconData ic,VoidCallback fn,{bool danger=false})=>GestureDetector(onTap:fn,child:Container(margin:const EdgeInsets.only(left:2),width:22,height:22,decoration:BoxDecoration(color:danger?Colors.red.shade400:_kPurple,borderRadius:BorderRadius.circular(3)),child:Icon(ic,color:Colors.white,size:13)));
}

class _DotPainter extends CustomPainter {
  @override void paint(Canvas canvas,Size size){final p=Paint()..color=Colors.grey.withValues(alpha:0.25);const s=22.0;for(double x=0;x<size.width;x+=s){for(double y=0;y<size.height;y+=s){canvas.drawCircle(Offset(x,y),1,p);}}}
  @override bool shouldRepaint(_)=>false;
}

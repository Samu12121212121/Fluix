import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/pdf_template.dart';
import '../../data/pdf_template_service.dart';

Color _hx(String h) { try { return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16)); } catch (_) { return const Color(0xFF1565C0); } }

class BloqueDisponible {
  final String tipo, nombre, icono, categoria;
  final Map<String, dynamic> propsDefault;
  const BloqueDisponible({required this.tipo, required this.nombre, required this.icono, required this.categoria, required this.propsDefault});
}

const List<BloqueDisponible> kBloquesDisponibles = [
  BloqueDisponible(tipo:'header',nombre:'Cabecera Empresa',icono:'🏢',categoria:'Empresa',propsDefault:{'mostrar_logo':true,'color_fondo':'#1565C0','color_texto':'#FFFFFF','padding':18.0,'border_radius':12.0}),
  BloqueDisponible(tipo:'footer',nombre:'Pie de Página',icono:'🔽',categoria:'Empresa',propsDefault:{'contenido':'Generado con PlaneaG','tamano_fuente':7.0,'color_texto':'#BDBDBD'}),
  BloqueDisponible(tipo:'cliente',nombre:'Datos del Cliente',icono:'👤',categoria:'Cliente',propsDefault:{'titulo':'FACTURAR A:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#F5F9FF','border_radius':8.0}),
  BloqueDisponible(tipo:'info_documento',nombre:'Info Documento',icono:'🧾',categoria:'Facturación',propsDefault:{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}),
  BloqueDisponible(tipo:'tabla_lineas',nombre:'Tabla de Líneas',icono:'📊',categoria:'Facturación',propsDefault:{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#0D47A1','color_fila_par':'#FFFFFF','color_fila_impar':'#FAFBFC'}),
  BloqueDisponible(tipo:'totales',nombre:'Totales',icono:'💰',categoria:'Facturación',propsDefault:{'mostrar_base':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true}),
  BloqueDisponible(tipo:'forma_pago',nombre:'Forma de Pago',icono:'💳',categoria:'Facturación',propsDefault:{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#F5F9FF'}),
  BloqueDisponible(tipo:'qr_verifactu',nombre:'QR Verifactu',icono:'📱',categoria:'Facturación',propsDefault:{'tamano':57.0,'mostrar_etiqueta':true}),
  BloqueDisponible(tipo:'info_empleado',nombre:'Info Empleado',icono:'👷',categoria:'Fichajes',propsDefault:{'mostrar_nombre':true,'mostrar_puesto':true,'mostrar_periodo':true}),
  BloqueDisponible(tipo:'tabla_fichajes',nombre:'Tabla de Fichajes',icono:'⏱️',categoria:'Fichajes',propsDefault:{'mostrar_fecha':true,'mostrar_entrada':true,'mostrar_salida':true,'color_cabecera':'#0D47A1'}),
  BloqueDisponible(tipo:'resumen_horas',nombre:'Resumen Horas',icono:'📈',categoria:'Fichajes',propsDefault:{'mostrar_total_horas':true,'mostrar_horas_extra':true,'mostrar_dias_trabajados':true}),
  BloqueDisponible(tipo:'notas',nombre:'Notas',icono:'📝',categoria:'Genérico',propsDefault:{'placeholder':'Notas...','tamano_fuente':9.0,'color_texto':'#757575'}),
  BloqueDisponible(tipo:'texto_libre',nombre:'Texto Libre',icono:'✏️',categoria:'Genérico',propsDefault:{'contenido':'Texto personalizado','tamano_fuente':10.0,'color_texto':'#000000','negrita':false,'cursiva':false}),
  BloqueDisponible(tipo:'separador',nombre:'Separador',icono:'➖',categoria:'Genérico',propsDefault:{'color':'#E0E0E0','grosor':1.0,'margen_vertical':8.0}),
  BloqueDisponible(tipo:'espaciador',nombre:'Espaciador',icono:'⬜',categoria:'Genérico',propsDefault:{'altura':16.0}),
];

class TemplateEditorScreen extends StatefulWidget {
  final String empresaId;
  final PdfTemplate? plantillaInicial;
  const TemplateEditorScreen({super.key, required this.empresaId, this.plantillaInicial});
  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _svc = PdfTemplateService();
  bool _guardando = false;
  late String _nombre, _descripcion, _colorPrimario;
  late TipoDocumentoPdf _tipo;
  late double _margenH, _margenV;
  late List<Map<String, dynamic>> _bloques;
  int? _selIdx;
  String _catFiltro = 'Todos';
  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool get _esNueva => widget.plantillaInicial == null;

  // Datos reales de empresa para la preview
  Map<String, dynamic> _empresaData = {};

  @override
  void initState() {
    super.initState();
    final p = widget.plantillaInicial;
    _nombre = p?.nombre ?? '';
    _descripcion = p?.descripcion ?? '';
    _tipo = p?.tipo ?? TipoDocumentoPdf.factura;
    _colorPrimario = p?.colorPrimario ?? '#1565C0';
    _margenH = p?.margenHorizontal ?? 36;
    _margenV = p?.margenVertical ?? 36;
    _bloques = p != null ? List.from(p.bloques) : List.from(PdfTemplate.defaultFactura(widget.empresaId).bloques);
    _nomCtrl.text = _nombre;
    _descCtrl.text = _descripcion;
    _cargarDatosEmpresa();
  }

  Future<void> _cargarDatosEmpresa() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).get();
      if (doc.exists && mounted) {
        setState(() => _empresaData = doc.data() as Map<String, dynamic>? ?? {});
      }
    } catch (_) {}
  }

  @override
  void dispose() { _nomCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva Plantilla' : 'Editar: $_nombre'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_guardando)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
          else
            TextButton.icon(onPressed: _guardar, icon: const Icon(Icons.save, color: Colors.white), label: const Text('Guardar', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: ancho > 900 ? _desktopLayout() : _mobileLayout(),
    );
  }

  Widget _desktopLayout() => Row(children: [
    SizedBox(width: 220, child: _toolbox()),
    const VerticalDivider(width: 1),
    Expanded(child: _canvas()),
    const VerticalDivider(width: 1),
    SizedBox(width: 300, child: _inspector()),
  ]);

  Widget _mobileLayout() => DefaultTabController(length: 3, child: Column(children: [
    const TabBar(labelColor: Color(0xFF1565C0), unselectedLabelColor: Colors.grey, indicatorColor: Color(0xFF1565C0), tabs: [Tab(icon: Icon(Icons.widgets_outlined), text: 'Bloques'), Tab(icon: Icon(Icons.preview_outlined), text: 'Canvas'), Tab(icon: Icon(Icons.tune), text: 'Props')]),
    Expanded(child: TabBarView(children: [_toolbox(), _canvas(), _inspector()])),
  ]));

  Widget _toolbox() {
    final cats = ['Todos','Empresa','Cliente','Facturación','Fichajes','Genérico'];
    final filtrados = _catFiltro == 'Todos' ? kBloquesDisponibles : kBloquesDisponibles.where((b) => b.categoria == _catFiltro).toList();
    return Container(color: Colors.white, child: Column(children: [
      Container(padding: const EdgeInsets.all(10), color: const Color(0xFF1A237E), child: const Row(children: [Icon(Icons.widgets, color: Colors.white, size: 15), SizedBox(width: 6), Text('Bloques', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))])),
      SizedBox(height: 34, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), itemCount: cats.length, itemBuilder: (_, i) {
        final cat = cats[i]; final sel = cat == _catFiltro;
        return GestureDetector(onTap: () => setState(() => _catFiltro = cat), child: Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: sel ? const Color(0xFF1565C0) : Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? const Color(0xFF1565C0) : Colors.grey.shade300)), child: Text(cat, style: TextStyle(fontSize: 9, color: sel ? Colors.white : Colors.grey[700], fontWeight: sel ? FontWeight.bold : FontWeight.normal))));
      })),
      const Divider(height: 1),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(6), itemCount: filtrados.length, itemBuilder: (_, i) => _toolboxTile(filtrados[i]))),
    ]));
  }

  Widget _toolboxTile(BloqueDisponible b) => Draggable<BloqueDisponible>(
    data: b,
    feedback: Material(elevation: 6, borderRadius: BorderRadius.circular(6), child: Container(width: 140, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(6)), child: Row(children: [Text(b.icono), const SizedBox(width: 4), Text(b.nombre, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]))),
    childWhenDragging: Opacity(opacity: 0.4, child: _tileCard(b)),
    child: _tileCard(b),
  );

  Widget _tileCard(BloqueDisponible b) => Container(margin: const EdgeInsets.only(bottom: 3), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)), child: ListTile(dense: true, leading: Text(b.icono, style: const TextStyle(fontSize: 16)), title: Text(b.nombre, style: const TextStyle(fontSize: 11)), trailing: IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF1565C0), size: 18), onPressed: () => _addBloque(b))));

  Widget _canvas() => Container(color: const Color(0xFFE8EAF0), child: Column(children: [
    Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Row(children: [const Icon(Icons.article_outlined, size: 14, color: Colors.grey), const SizedBox(width: 5), Text('A4 · ${_bloques.length} bloques', style: const TextStyle(fontSize: 11, color: Colors.grey)), const Spacer(), if (_bloques.isNotEmpty) const Text('⠿ Arrastra para reordenar', style: TextStyle(fontSize: 9, color: Colors.grey))])),
    Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: DragTarget<BloqueDisponible>(onAcceptWithDetails: (d) => _addBloque(d.data), builder: (ctx, cand, rej) => Container(
      width: 595, constraints: const BoxConstraints(minHeight: 842),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))], border: cand.isNotEmpty ? Border.all(color: const Color(0xFF1565C0), width: 2) : null),
      child: _bloques.isEmpty
        ? Container(height: 400, alignment: Alignment.center, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_box_outlined, size: 56, color: Colors.grey.withValues(alpha: 0.4)), const SizedBox(height: 10), Text('Arrastra bloques aquí\no usa el botón + del panel', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.withValues(alpha: 0.6), fontSize: 13))]))
        : ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final b = _bloques.removeAt(oldIdx);
                _bloques.insert(newIdx, b);
                if (_selIdx == oldIdx) _selIdx = newIdx;
                _reIdx();
              });
            },
            children: List.generate(_bloques.length, (i) => _canvasBloque(i)),
          ),
    )))),
  ]));

  Widget _canvasBloque(int idx) {
    final b = _bloques[idx]; final sel = _selIdx == idx;
    final activo = b['activo'] as bool? ?? true;
    final key = ValueKey(b['id'] ?? 'bloque_$idx');
    return GestureDetector(key: key, onTap: () => setState(() => _selIdx = idx), child: Container(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), decoration: BoxDecoration(border: Border.all(color: sel ? const Color(0xFF1565C0) : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(4)), child: Stack(children: [
      Opacity(opacity: activo ? 1.0 : 0.4, child: _bloquePreview(b)),
      Positioned(top: 3, right: 3, child: Row(children: [
        ReorderableDragStartListener(index: idx, child: _cBtn(Icons.drag_handle, () {})),
        _cBtn(activo ? Icons.visibility_off : Icons.visibility, () => _toggleActivo(idx)),
        _cBtn(Icons.delete_outline, () => _delBloque(idx), color: Colors.red),
      ])),
      Positioned(top: 3, left: 3, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: sel ? const Color(0xFF1565C0) : Colors.black45, borderRadius: BorderRadius.circular(3)), child: Text(_nomBloque(b['tipo'] as String? ?? ''), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
    ])));
  }

  Widget _cBtn(IconData ic, VoidCallback fn, {Color? color}) => GestureDetector(onTap: fn, child: Container(margin: const EdgeInsets.only(left: 2), width: 22, height: 22, decoration: BoxDecoration(color: color ?? const Color(0xFF1565C0), borderRadius: BorderRadius.circular(3)), child: Icon(ic, color: Colors.white, size: 13)));

  Widget _bloquePreview(Map<String, dynamic> b) {
    final tipo = b['tipo'] as String? ?? '';
    final p = Map<String, dynamic>.from(b['props'] as Map? ?? {});
    switch (tipo) {
      case 'header':
        final cf = _hx(p['color_fondo'] as String? ?? '#1565C0'); final ct = _hx(p['color_texto'] as String? ?? '#FFFFFF');
        // Usar datos reales de empresa si están disponibles
        final perfil = _empresaData['perfil'] as Map? ?? {};
        final nombreEmpresa = (perfil['nombre'] as String?)?.isNotEmpty == true ? perfil['nombre'] as String : (_empresaData['nombre'] as String? ?? 'MI EMPRESA S.L.');
        final nifEmpresa = (perfil['nif'] as String?)?.isNotEmpty == true ? 'NIF: ${perfil['nif']}' : 'NIF: ${_empresaData['nif'] ?? 'B12345678'}';
        return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: cf, borderRadius: BorderRadius.circular((p['border_radius'] as num?)?.toDouble() ?? 8)), child: Row(children: [if (p['mostrar_logo']==true) ...[Container(width:28, height:28, decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.2), borderRadius:BorderRadius.circular(3)), child:const Icon(Icons.business,color:Colors.white,size:16)), const SizedBox(width:6)], Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, mainAxisSize:MainAxisSize.min, children:[Text(nombreEmpresa,style:TextStyle(color:ct,fontWeight:FontWeight.bold,fontSize:10)), Text(nifEmpresa,style:TextStyle(color:ct.withValues(alpha:0.8),fontSize:7))])), Column(crossAxisAlignment:CrossAxisAlignment.end, mainAxisSize:MainAxisSize.min, children:[Text('FAC-2026-001',style:TextStyle(color:ct,fontWeight:FontWeight.bold,fontSize:8)), Text('01/06/2026',style:TextStyle(color:ct.withValues(alpha:0.7),fontSize:7))])]));
      case 'cliente':
        final cf = _hx(p['color_fondo'] as String? ?? '#F5F9FF');
        return Container(padding:const EdgeInsets.all(7), decoration:BoxDecoration(color:cf, borderRadius:BorderRadius.circular((p['border_radius'] as num?)?.toDouble()??8), border:Border.all(color:Colors.grey.shade200)), child:Column(crossAxisAlignment:CrossAxisAlignment.start, mainAxisSize:MainAxisSize.min, children:[Text(p['titulo'] as String? ?? 'FACTURAR A:', style:const TextStyle(fontWeight:FontWeight.bold,fontSize:7,color:Color(0xFF1565C0))), const Text('Cliente Ejemplo S.A.',style:TextStyle(fontWeight:FontWeight.bold,fontSize:9)), if(p['mostrar_nif']==true) const Text('NIF: A87654321',style:TextStyle(fontSize:7,color:Colors.grey)), if(p['mostrar_direccion']==true) const Text('Calle Ejemplo, 1',style:TextStyle(fontSize:7,color:Colors.grey))]));
      case 'tabla_lineas':
        final cc = _hx(p['color_cabecera'] as String? ?? '#0D47A1');
        Widget fila(String d, String tot, Color cf) => Container(padding:const EdgeInsets.symmetric(horizontal:5, vertical:2), color:cf, child:Row(children:[Expanded(flex:4,child:Text(d,style:const TextStyle(fontSize:7))), SizedBox(width:46,child:Text(tot,textAlign:TextAlign.right,style:const TextStyle(fontSize:7,fontWeight:FontWeight.bold)))]));
        return Column(children:[Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:4),color:cc,child:const Row(children:[Expanded(flex:4,child:Text('DESCRIPCIÓN',style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold))),SizedBox(width:46,child:Text('TOTAL',textAlign:TextAlign.right,style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold)))])), fila('Servicio ejemplo','121,00€',_hx(p['color_fila_par'] as String? ?? '#FFFFFF')), fila('Otro servicio','121,00€',_hx(p['color_fila_impar'] as String? ?? '#FAFBFC'))]);
      case 'totales':
        Widget rt(String l, String v, {bool bold=false, Color? c}) => Padding(padding:const EdgeInsets.symmetric(vertical:1), child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text(l,style:TextStyle(fontSize:8,color:c??Colors.grey[700])), Text(v,style:TextStyle(fontSize:8,fontWeight:FontWeight.bold,color:c??Colors.black))]));
        return Align(alignment:Alignment.centerRight, child:SizedBox(width:150, child:Padding(padding:const EdgeInsets.all(6), child:Column(children:[if(p['mostrar_base']==true) rt('Base imponible','200,00 €'), if(p['mostrar_iva']==true) rt('IVA 21%','42,00 €'), if(p['mostrar_irpf']==true) rt('IRPF 15%','-30,00 €'), const Divider(height:4), rt('TOTAL','212,00 €',bold:true,c:const Color(0xFF1565C0))]))));
      case 'forma_pago':
        return Container(padding:const EdgeInsets.all(7),color:_hx(p['color_fondo'] as String? ?? '#F5F9FF'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[const Text('FORMA DE PAGO',style:TextStyle(fontWeight:FontWeight.bold,fontSize:7,color:Color(0xFF1565C0))),if(p['mostrar_metodo']==true) const Text('Transferencia',style:TextStyle(fontSize:7)),if(p['mostrar_iban']==true) const Text('IBAN: ES12 ...',style:TextStyle(fontSize:7,fontWeight:FontWeight.bold))]));
      case 'notas': case 'texto_libre':
        final txt = tipo=='notas'?(p['placeholder'] as String? ?? ''):(p['contenido'] as String? ?? '');
        return Padding(padding:const EdgeInsets.all(4),child:Text(txt,style:TextStyle(fontSize:(p['tamano_fuente'] as num?)?.toDouble()??9,color:_hx(p['color_texto'] as String? ?? '#757575'),fontStyle:p['cursiva']==true?FontStyle.italic:FontStyle.normal,fontWeight:p['negrita']==true?FontWeight.bold:FontWeight.normal)));
      case 'qr_verifactu':
        return Padding(padding:const EdgeInsets.all(6),child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[if(p['mostrar_etiqueta']==true) const Expanded(child:Text('VERI*FACTU',style:TextStyle(fontSize:7,color:Color(0xFF0D47A1)))),Container(width:40,height:40,color:Colors.grey.shade200,child:const Icon(Icons.qr_code,color:Colors.grey,size:26))]));
      case 'separador': return Padding(padding:EdgeInsets.symmetric(vertical:(p['margen_vertical'] as num?)?.toDouble()??4),child:Divider(color:_hx(p['color'] as String? ?? '#E0E0E0'),height:(p['grosor'] as num?)?.toDouble()??1));
      case 'espaciador': return SizedBox(height:(p['altura'] as num?)?.toDouble()??16);
      case 'tabla_fichajes':
        return Column(children:[Container(padding:const EdgeInsets.all(4),color:_hx(p['color_cabecera'] as String? ?? '#0D47A1'),child:const Row(children:[Expanded(child:Text('FECHA',style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold))),Expanded(child:Text('ENTRADA',style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold))),Expanded(child:Text('HORAS',style:TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold)))])),const Padding(padding:EdgeInsets.symmetric(horizontal:4,vertical:3),child:Row(children:[Expanded(child:Text('01/01/2026',style:TextStyle(fontSize:7))),Expanded(child:Text('09:00',style:TextStyle(fontSize:7))),Expanded(child:Text('8h',style:TextStyle(fontSize:7,fontWeight:FontWeight.bold)))]))]);
      case 'resumen_horas':
        return Container(padding:const EdgeInsets.all(8),color:const Color(0xFFF5F9FF),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[if(p['mostrar_dias_trabajados']==true) Column(children:[const Text('22',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:Color(0xFF1565C0))),const Text('Días',style:TextStyle(fontSize:7,color:Colors.grey))]),if(p['mostrar_total_horas']==true) Column(children:[const Text('176h',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:Color(0xFF1565C0))),const Text('Total',style:TextStyle(fontSize:7,color:Colors.grey))]),if(p['mostrar_horas_extra']==true) Column(children:[const Text('8h',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:Color(0xFFE65100))),const Text('Extra',style:TextStyle(fontSize:7,color:Colors.grey))])]));
      case 'info_empleado':
        return Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:const Color(0xFFF5F9FF),borderRadius:BorderRadius.circular(6),border:Border.all(color:Colors.grey.shade200)),child:Row(children:[const CircleAvatar(radius:12,child:Icon(Icons.person,size:12)),const SizedBox(width:7),Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[if(p['mostrar_nombre']==true) const Text('Juan García',style:TextStyle(fontWeight:FontWeight.bold,fontSize:9)),if(p['mostrar_puesto']==true) const Text('Desarrollador',style:TextStyle(fontSize:7,color:Colors.grey))])]));
      case 'footer': return Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text(p['contenido'] as String? ?? 'Pie de página',textAlign:TextAlign.center,style:TextStyle(fontSize:(p['tamano_fuente'] as num?)?.toDouble()??7,color:_hx(p['color_texto'] as String? ?? '#BDBDBD'))));
      case 'info_documento': return Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:12),child:Align(alignment:Alignment.centerRight,child:Column(crossAxisAlignment:CrossAxisAlignment.end,mainAxisSize:MainAxisSize.min,children:[if(p['mostrar_numero']==true) const Text('Nº: FAC-2026-001',style:TextStyle(fontSize:9,fontWeight:FontWeight.bold)),if(p['mostrar_fecha_emision']==true) const Text('Emisión: 01/01/2026',style:TextStyle(fontSize:8,color:Colors.grey))])));
      default: return Container(height:32,color:Colors.grey.shade100,child:Center(child:Text('[$tipo]',style:const TextStyle(color:Colors.grey,fontSize:9))));
    }
  }

  Widget _inspector() => Container(color: Colors.white, child: Column(children: [
    Container(padding:const EdgeInsets.all(10),color:const Color(0xFF1A237E),child:const Row(children:[Icon(Icons.tune,color:Colors.white,size:15),SizedBox(width:6),Text('Propiedades',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:12))])),
    Expanded(child: DefaultTabController(length:2, child:Column(children:[
      const TabBar(labelColor:Color(0xFF1565C0),unselectedLabelColor:Colors.grey,indicatorColor:Color(0xFF1565C0),tabs:[Tab(text:'Bloque'),Tab(text:'Plantilla')]),
      Expanded(child:TabBarView(children:[_inspBloque(),_inspPlantilla()])),
    ]))),
  ]));

  Widget _inspBloque() {
    if (_selIdx==null||_bloques.isEmpty) return const Center(child:Padding(padding:EdgeInsets.all(20),child:Text('Selecciona un bloque\npara editar sus propiedades',textAlign:TextAlign.center,style:TextStyle(color:Colors.grey))));
    final b = _bloques[_selIdx!]; final tipo = b['tipo'] as String? ?? '';
    final p = Map<String,dynamic>.from(b['props'] as Map<String,dynamic>? ?? {});
    return SingleChildScrollView(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_nomBloque(tipo),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),const SizedBox(height:10),..._propsParaTipo(tipo,p)]));
  }

  List<Widget> _propsParaTipo(String tipo, Map<String,dynamic> p) {
    switch(tipo) {
      case 'header': return [_pColor('Color fondo','color_fondo',p),_pColor('Color texto','color_texto',p),_pSlider('Padding','padding',p,0,40),_pSlider('Border radius','border_radius',p,0,20),_pSwitch('Mostrar logo','mostrar_logo',p)];
      case 'cliente': return [_pText('Título','titulo',p),_pColor('Color fondo','color_fondo',p),_pSwitch('Mostrar NIF','mostrar_nif',p),_pSwitch('Mostrar dirección','mostrar_direccion',p),_pSwitch('Mostrar email','mostrar_email',p)];
      case 'tabla_lineas': return [_pColor('Color cabecera','color_cabecera',p),_pColor('Fila par','color_fila_par',p),_pColor('Fila impar','color_fila_impar',p),_pSwitch('Cantidad','mostrar_cantidad',p),_pSwitch('Precio','mostrar_precio_unitario',p),_pSwitch('IVA','mostrar_iva',p)];
      case 'totales': return [_pSwitch('Base','mostrar_base',p),_pSwitch('IVA','mostrar_iva',p),_pSwitch('IRPF','mostrar_irpf',p),_pSwitch('Total','mostrar_total',p)];
      case 'texto_libre': case 'notas': return [_pTextArea('Contenido',tipo=='notas'?'placeholder':'contenido',p),_pSlider('Tamaño fuente','tamano_fuente',p,6,24),_pColor('Color texto','color_texto',p),_pSwitch('Negrita','negrita',p),_pSwitch('Cursiva','cursiva',p)];
      case 'forma_pago': return [_pColor('Color fondo','color_fondo',p),_pSwitch('Método','mostrar_metodo',p),_pSwitch('IBAN','mostrar_iban',p)];
      case 'separador': return [_pColor('Color','color',p),_pSlider('Grosor','grosor',p,0.5,4),_pSlider('Margen','margen_vertical',p,0,24)];
      case 'espaciador': return [_pSlider('Altura','altura',p,4,64)];
      case 'qr_verifactu': return [_pSlider('Tamaño','tamano',p,40,100),_pSwitch('Etiqueta','mostrar_etiqueta',p)];
      case 'tabla_fichajes': return [_pColor('Color cabecera','color_cabecera',p),_pSwitch('Fecha','mostrar_fecha',p),_pSwitch('Entrada','mostrar_entrada',p),_pSwitch('Salida','mostrar_salida',p)];
      case 'resumen_horas': return [_pSwitch('Total horas','mostrar_total_horas',p),_pSwitch('Horas extra','mostrar_horas_extra',p),_pSwitch('Días trabajados','mostrar_dias_trabajados',p)];
      case 'info_empleado': return [_pSwitch('Nombre','mostrar_nombre',p),_pSwitch('Puesto','mostrar_puesto',p),_pSwitch('Período','mostrar_periodo',p)];
      case 'footer': return [_pText('Contenido','contenido',p),_pSlider('Tamaño fuente','tamano_fuente',p,6,14),_pColor('Color texto','color_texto',p)];
      default: return [const Text('Sin propiedades',style:TextStyle(color:Colors.grey,fontSize:12))];
    }
  }

  Widget _pSwitch(String lbl, String key, Map<String,dynamic> p) => SwitchListTile(dense:true,title:Text(lbl,style:const TextStyle(fontSize:12)),value:p[key] as bool? ?? false,activeThumbColor:const Color(0xFF1565C0),onChanged:(v)=>_updProp(key,v));
  Widget _pSlider(String lbl, String key, Map<String,dynamic> p, double min, double max) {
    final val=(p[key] as num?)?.toDouble()??min;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.only(left:14,top:6),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(lbl,style:const TextStyle(fontSize:12)),Text(val.toStringAsFixed(0),style:const TextStyle(fontSize:11,color:Colors.grey))])),Slider(value:val.clamp(min,max),min:min,max:max,activeColor:const Color(0xFF1565C0),onChanged:(v)=>_updProp(key,v.roundToDouble()))]);
  }
  Widget _pText(String lbl, String key, Map<String,dynamic> p) => Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),child:TextField(controller:TextEditingController(text:p[key] as String? ?? ''),decoration:InputDecoration(labelText:lbl,isDense:true,border:const OutlineInputBorder()),style:const TextStyle(fontSize:12),onChanged:(v)=>_updProp(key,v)));
  Widget _pTextArea(String lbl, String key, Map<String,dynamic> p) => Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),child:TextField(controller:TextEditingController(text:p[key] as String? ?? ''),decoration:InputDecoration(labelText:lbl,isDense:true,border:const OutlineInputBorder()),style:const TextStyle(fontSize:12),maxLines:3,onChanged:(v)=>_updProp(key,v)));
  Widget _pColor(String lbl, String key, Map<String,dynamic> p) {
    final colorHex = p[key] as String? ?? '#000000';
    const colores = ['#1565C0','#0D47A1','#1976D2','#42A5F5','#2E7D32','#388E3C','#D32F2F','#E65100','#7B1FA2','#00695C','#FFFFFF','#F5F9FF','#F5F5F5','#E0E0E0','#757575','#424242','#000000'];
    return Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:16,height:16,decoration:BoxDecoration(color:_hx(colorHex),borderRadius:BorderRadius.circular(3),border:Border.all(color:Colors.grey.shade300))),const SizedBox(width:6),Text(lbl,style:const TextStyle(fontSize:12))]),const SizedBox(height:4),Wrap(spacing:3,runSpacing:3,children:colores.map((hex){final sel=hex.toUpperCase()==colorHex.toUpperCase();return GestureDetector(onTap:()=>_updProp(key,hex),child:Container(width:20,height:20,decoration:BoxDecoration(color:_hx(hex),borderRadius:BorderRadius.circular(3),border:Border.all(color:sel?Colors.blue:Colors.grey.shade300,width:sel?2:1)),child:sel?const Icon(Icons.check,size:12,color:Colors.white):null));}).toList())]));
  }

  Widget _inspPlantilla() => SingleChildScrollView(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Información',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
    const SizedBox(height:8),
    TextField(controller:_nomCtrl,decoration:const InputDecoration(labelText:'Nombre',isDense:true,border:OutlineInputBorder()),onChanged:(v)=>_nombre=v),
    const SizedBox(height:8),
    TextField(controller:_descCtrl,decoration:const InputDecoration(labelText:'Descripción',isDense:true,border:OutlineInputBorder()),maxLines:2,onChanged:(v)=>_descripcion=v),
    const SizedBox(height:10),
    const Text('Tipo de documento',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
    const SizedBox(height:6),
    DropdownButtonFormField<TipoDocumentoPdf>(
      initialValue:_tipo,
      decoration:const InputDecoration(isDense:true,border:OutlineInputBorder()),
      items:TipoDocumentoPdf.values.map((t)=>DropdownMenuItem(value:t,child:Text('${t.icon} ${t.label}',style:const TextStyle(fontSize:12)))).toList(),
      onChanged:(v){
        if(v!=null) setState((){
          final cambioTipo = v != _tipo;
          _tipo=v;
          // Al cambiar tipo, cargar previsualización por defecto
          if (cambioTipo) {
            final preview = PdfTemplate.defaultParaTipo(widget.empresaId, v);
            _bloques = List.from(preview.bloques);
            _colorPrimario = preview.colorPrimario;
            _selIdx = null;
            _nomCtrl.text = _esNueva ? '' : _nomCtrl.text;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('✅ Previsualización cargada: ${v.icon} ${v.label}'),
              backgroundColor: const Color(0xFF1565C0),
              duration: const Duration(seconds: 2),
            ));
          }
        });
      },
    ),
    const SizedBox(height:6),
    // Botón para recargar previsualización manualmente
    SizedBox(width:double.infinity, child: OutlinedButton.icon(
      onPressed: () {
        showDialog(context: context, builder: (_) => AlertDialog(
          title: Text('${_tipo.icon} Cargar previsualización'),
          content: Text('Se reemplazarán los bloques actuales por la plantilla por defecto de "${_tipo.label}".\n\n¿Continuar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  final preview = PdfTemplate.defaultParaTipo(widget.empresaId, _tipo);
                  _bloques = List.from(preview.bloques);
                  _colorPrimario = preview.colorPrimario;
                  _selIdx = null;
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
              child: const Text('Cargar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ));
      },
      icon: const Icon(Icons.preview_outlined, size: 16),
      label: const Text('Recargar previsualización', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0), side: const BorderSide(color: Color(0xFF1565C0))),
    )),
    const SizedBox(height:10),
    const Text('Color primario',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
    const SizedBox(height:4),
    Wrap(spacing:4,runSpacing:4,children:['#1565C0','#0D47A1','#2E7D32','#D32F2F','#E65100','#7B1FA2','#00695C','#B71C1C','#424242','#000000'].map((hex){final sel=hex.toUpperCase()==_colorPrimario.toUpperCase();return GestureDetector(onTap:()=>setState(()=>_colorPrimario=hex),child:Container(width:26,height:26,decoration:BoxDecoration(color:_hx(hex),borderRadius:BorderRadius.circular(4),border:Border.all(color:sel?Colors.blue:Colors.transparent,width:2))));}).toList()),
    const SizedBox(height:10),
    const Text('Márgenes',style:TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
    _slider2('Horizontal',_margenH,0,72,(v)=>setState(()=>_margenH=v)),
    _slider2('Vertical',_margenV,0,72,(v)=>setState(()=>_margenV=v)),
  ]));

  Widget _slider2(String lbl, double val, double min, double max, void Function(double) fn) => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Padding(padding:const EdgeInsets.only(top:4),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(lbl,style:const TextStyle(fontSize:11)),Text('${val.toStringAsFixed(0)}px',style:const TextStyle(fontSize:10,color:Colors.grey))])),
    Slider(value:val.clamp(min,max),min:min,max:max,activeColor:const Color(0xFF1565C0),onChanged:fn),
  ]);

  void _addBloque(BloqueDisponible b) => setState(() { _bloques.add({'id':'${b.tipo}_${DateTime.now().millisecondsSinceEpoch}','tipo':b.tipo,'orden':_bloques.length,'activo':true,'props':Map<String,dynamic>.from(b.propsDefault)}); _selIdx=_bloques.length-1; });
  void _updProp(String key, dynamic val) { if(_selIdx==null) return; setState((){final b=Map<String,dynamic>.from(_bloques[_selIdx!]);final p=Map<String,dynamic>.from(b['props'] as Map<String,dynamic>? ?? {});p[key]=val;b['props']=p;_bloques[_selIdx!]=b;}); }
  void _moverArriba(int idx) { if(idx<=0) return; setState((){final t=_bloques[idx];_bloques[idx]=_bloques[idx-1];_bloques[idx-1]=t;_selIdx=idx-1;_reIdx();}); }
  void _moverAbajo(int idx) { if(idx>=_bloques.length-1) return; setState((){final t=_bloques[idx];_bloques[idx]=_bloques[idx+1];_bloques[idx+1]=t;_selIdx=idx+1;_reIdx();}); }
  void _reIdx() { for(var i=0;i<_bloques.length;i++){_bloques[i]=Map<String,dynamic>.from(_bloques[i])..['orden']=i;} }
  void _toggleActivo(int idx) => setState((){final b=Map<String,dynamic>.from(_bloques[idx]);b['activo']=!(b['activo'] as bool? ?? true);_bloques[idx]=b;});
  void _delBloque(int idx) => setState((){_bloques.removeAt(idx);_selIdx=null;_reIdx();});
  String _nomBloque(String tipo) => kBloquesDisponibles.firstWhere((b)=>b.tipo==tipo,orElse:()=>BloqueDisponible(tipo:tipo,nombre:tipo,icono:'📄',categoria:'Genérico',propsDefault:const{})).nombre;

  Future<void> _guardar() async {
    if(_nombre.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Introduce un nombre'),backgroundColor:Colors.orange));return;}
    setState(()=>_guardando=true);
    try {
      final tpl = PdfTemplate(id:widget.plantillaInicial?.id??'',empresaId:widget.empresaId,nombre:_nombre.trim(),descripcion:_descripcion.trim(),tipo:_tipo,esDefault:widget.plantillaInicial?.esDefault??false,activa:true,fechaCreacion:widget.plantillaInicial?.fechaCreacion??DateTime.now(),fechaModificacion:DateTime.now(),colorPrimario:_colorPrimario,colorSecundario:widget.plantillaInicial?.colorSecundario??'#0D47A1',margenHorizontal:_margenH,margenVertical:_margenV,bloques:List.from(_bloques));
      if(_esNueva) await _svc.crearPlantilla(tpl); else await _svc.actualizarPlantilla(tpl);
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('✅ Plantilla "${tpl.nombre}" guardada'),backgroundColor:Colors.green));Navigator.pop(context);}
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('❌ Error: $e'),backgroundColor:Colors.red));
    } finally { if(mounted) setState(()=>_guardando=false); }
  }
}























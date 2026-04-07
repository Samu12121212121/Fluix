import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

class PantallaIntegracionScript extends StatefulWidget {
  final String empresaId;

  const PantallaIntegracionScript({
    Key? key,
    required this.empresaId,
  }) : super(key: key);

  @override
  State<PantallaIntegracionScript> createState() =>
      _PantallaIntegracionScriptState();
}

class _PantallaIntegracionScriptState extends State<PantallaIntegracionScript> {
  late Future<Map<String, dynamic>> _scriptFuture;
  bool _scriptCopiado = false;

  @override
  void initState() {
    super.initState();
    _scriptFuture = _obtenerScript();
  }

  Future<Map<String, dynamic>> _obtenerScript() async {
    try {
      // Obtener datos de la empresa
      final empresaDoc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();

      if (!empresaDoc.exists) {
        throw Exception('Empresa no encontrada');
      }

      final empresaData = empresaDoc.data()!;
      final nombreEmpresa = empresaData['nombre'] ?? 'Mi Negocio';
      final dominio = empresaData['sitio_web'] ?? 'midominio.com';

      // Llamar a la Cloud Function para obtener el script
      const functionUrl =
          'https://europe-west1-planeaapp-4bea4.cloudfunctions.net/obtenerScriptJSON';

      final dio = Dio();
      final response = await dio.get(
        '$functionUrl?empresaId=${widget.empresaId}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'nombre': nombreEmpresa,
          'dominio': dominio,
          'script': data['script'],
          'exito': true,
        };
      } else {
        // Si falla la Cloud Function, generar el script localmente
        final scriptLocal = _generarScriptLocal(
          widget.empresaId,
          nombreEmpresa,
          dominio,
        );
        return {
          'nombre': nombreEmpresa,
          'dominio': dominio,
          'script': scriptLocal,
          'exito': true,
        };
      }
    } catch (e) {
      return {
        'error': e.toString(),
        'exito': false,
      };
    }
  }

  String _generarScriptLocal(
    String empresaId,
    String nombreEmpresa,
    String dominio,
  ) {
    return '''<!-- ============================================================
     🔥 FLUIX CRM - SCRIPT COMPLETO: CONTENIDO DINÁMICO + ANALYTICS
     Web: $dominio
     Empresa: $nombreEmpresa
     Versión: SEGURA (no bloquea la web si Firebase falla)
     ============================================================ -->

<!-- ═══════════════════════════════════════════════════════════════ -->
<!-- PON ESTOS DIVS DONDE QUIERAS EN TU WEB                        -->
<!-- <div id="fluixcrm_SECCION_ID"></div>  → Secciones de la app    -->
<!-- <div id="fluixcrm_contacto"></div>    → Formulario de contacto  -->
<!-- <div id="fluixcrm_reservas"></div>    → Formulario de reservas  -->
<!-- <div id="fluixcrm_blog"></div>        → Blog / Noticias         -->
<!-- ═══════════════════════════════════════════════════════════════ -->

<!-- Firebase SDK -->
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore-compat.js"></script>

<script>
(function () {
  'use strict';

  var FIREBASE_CONFIG = {
    apiKey: "AIzaSyCvOaB1hF_sF-A6jMZ0MusttuhzSMDezb4",
    authDomain: "planeaapp-4bea4.firebaseapp.com",
    projectId: "planeaapp-4bea4",
    storageBucket: "planeaapp-4bea4.firebasestorage.app",
    messagingSenderId: "1085482191658",
    appId: "1:1085482191658:web:c5461353b123ab92d62c53"
  };

  var EMPRESA_ID = "$empresaId";
  var DOMINIO_WEB = "$dominio";
  var NOMBRE_EMPRESA = "$nombreEmpresa";

  window.addEventListener('load', function () {
    try { inicializar(); }
    catch (e) { console.warn('Fluix CRM: error al inicializar', e); }
  });

  function inicializar() {
    if (!firebase.apps || !firebase.apps.length) {
      firebase.initializeApp(FIREBASE_CONFIG);
    }
    var db = firebase.firestore();
    registrarVisita(db).catch(function(e){ console.warn('Fluix CRM: visita error', e); });
    rastrearEventos(db).catch(function(e){ console.warn('Fluix CRM: eventos error', e); });
    cargarContenidoDinamico(db);
    cargarFormularioContacto(db);
    cargarFormularioReservas(db);
    cargarBlog(db);
  }

  function render(id, html, show) {
    var el = document.getElementById("fluixcrm_" + id);
    if (!el) return;
    el.innerHTML = html;
    el.style.display = (show === false) ? "none" : "";
  }

  function cargarContenidoDinamico(db) {
    db.collection("empresas").doc(EMPRESA_ID)
      .collection("contenido_web").onSnapshot(function(snap) {
      snap.docChanges().forEach(function(ch) {
        if (ch.type === "removed") render(ch.doc.id, "", false);
      });
      snap.forEach(function(doc) {
        var d = doc.data(), tipo = d.tipo || "texto", c = d.contenido || {};
        if (!d.activa) { render(doc.id, "", false); return; }
        var html = "";
        if (tipo === "texto") {
          html = '<h3>'+(c.titulo||'')+'</h3><p>'+(c.texto||'')+'</p>'+(c.imagen_url?'<img src="'+c.imagen_url+'" style="max-width:100%;border-radius:8px">':'')
        } else if (tipo === "carta") {
          html = (c.items_carta||[]).filter(function(p){return p.disponible!==false;}).map(function(p){
            return '<div style="border-bottom:1px solid #eee;padding:10px 0;display:flex;gap:12px;align-items:start">'
              +(p.imagen_url?'<img src="'+p.imagen_url+'" style="width:70px;height:70px;object-fit:cover;border-radius:8px">':'')
              +'<div style="flex:1"><div><strong style="font-size:15px">'+p.nombre+'</strong>'
              +'<span style="float:right;font-weight:bold;color:#e65100">'+p.precio+'€</span></div>'
              +'<p style="margin:4px 0 0;color:#666;font-size:13px">'+(p.descripcion||'')+'</p></div></div>';
          }).join("");
        } else if (tipo === "galeria") {
          html = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px">'
            +(c.imagenes_galeria||[]).map(function(i){return '<img src="'+i.url+'" style="width:100%;border-radius:8px;object-fit:cover;aspect-ratio:1" loading="lazy">';}).join("")+'</div>';
        } else if (tipo === "ofertas") {
          html = (c.ofertas||[]).filter(function(o){return o.activa;}).map(function(o){
            return '<div style="border:1px solid #eee;border-radius:8px;padding:14px;margin-bottom:12px">'
              +(o.imagen_url?'<img src="'+o.imagen_url+'" style="width:100%;border-radius:6px;margin-bottom:8px">':'')
              +'<h4 style="margin:0 0 6px">'+o.titulo+'</h4><p style="color:#666;font-size:13px">'+(o.descripcion||'')+'</p>'
              +(o.precio_original?'<s style="color:#999">'+o.precio_original+'€</s> ':'')
              +(o.precio_oferta?'<strong style="color:#e53935;font-size:18px">'+o.precio_oferta+'€</strong>':'')+'</div>';
          }).join("");
        } else if (tipo === "horarios") {
          html = '<table style="width:100%;border-collapse:collapse">'+(c.horarios||[]).map(function(h){
            return '<tr style="border-bottom:1px solid #f5f5f5"><td style="padding:8px 12px;font-weight:bold">'+h.dia+'</td>'
              +'<td style="padding:8px 12px;color:'+(h.cerrado?'#e53935':'#2e7d32')+'">'+(h.cerrado?'Cerrado':h.apertura+' – '+h.cierre)+'</td></tr>';
          }).join("")+'</table>';
        }
        render(doc.id, html, true);
      });
    });
  }

  function cargarFormularioContacto(db) {
    var el = document.getElementById("fluixcrm_contacto"); if (!el) return;
    el.innerHTML = '<div style="max-width:480px"><h3>Contáctanos</h3>'
      +'<form id="fluixcrm_form_contacto" style="display:flex;flex-direction:column;gap:12px">'
      +'<input name="nombre" placeholder="Tu nombre" required style="padding:10px;border:1px solid #ddd;border-radius:8px">'
      +'<input name="email" type="email" placeholder="Tu email" required style="padding:10px;border:1px solid #ddd;border-radius:8px">'
      +'<textarea name="mensaje" placeholder="Tu mensaje" rows="4" required style="padding:10px;border:1px solid #ddd;border-radius:8px;resize:vertical"></textarea>'
      +'<button type="submit" style="background:#1976D2;color:#fff;padding:12px;border:none;border-radius:8px;cursor:pointer;font-weight:bold">Enviar mensaje</button>'
      +'</form></div>';
    document.getElementById("fluixcrm_form_contacto").addEventListener("submit",function(e){
      e.preventDefault();var fd=new FormData(e.target);
      db.collection("empresas").doc(EMPRESA_ID).collection("contacto_web").add({
        nombre:fd.get("nombre"),email:fd.get("email"),mensaje:fd.get("mensaje"),
        fecha:firebase.firestore.FieldValue.serverTimestamp(),leido:false
      }).then(function(){e.target.innerHTML='<p style="color:green;font-weight:bold">✅ Mensaje enviado.</p>';
      }).catch(function(err){alert("Error: "+err.message);});
    });
  }

  function cargarFormularioReservas(db) {
    var el = document.getElementById("fluixcrm_reservas"); if (!el) return;
    el.innerHTML = '<div style="max-width:480px;border:1px solid #eee;padding:24px;border-radius:12px">'
      +'<h3>📅 Reservar Mesa / Cita</h3>'
      +'<form id="fluixcrm_form_reservas" style="display:flex;flex-direction:column;gap:14px">'
      +'<input name="nombre" placeholder="Tu nombre" required style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      +'<input name="telefono" type="tel" placeholder="Tu teléfono" required style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      +'<div style="display:flex;gap:10px"><input name="fecha" type="date" required style="padding:12px;border:1px solid #ddd;border-radius:8px;flex:1">'
      +'<input name="hora" type="time" required style="padding:12px;border:1px solid #ddd;border-radius:8px;flex:1"></div>'
      +'<input name="personas" type="number" min="1" placeholder="Nº Personas" style="padding:12px;border:1px solid #ddd;border-radius:8px">'
      +'<button type="submit" style="background:#1976D2;color:#fff;padding:14px;border:none;border-radius:8px;cursor:pointer;font-weight:bold;font-size:16px">Solicitar Reserva</button>'
      +'</form></div>';
    document.getElementById("fluixcrm_form_reservas").addEventListener("submit",function(e){
      e.preventDefault();var fd=new FormData(e.target);
      var fecha=new Date(fd.get("fecha")+"T"+fd.get("hora")+":00");
      db.collection("empresas").doc(EMPRESA_ID).collection("reservas").add({
        nombre_cliente:fd.get("nombre"),telefono_cliente:fd.get("telefono"),
        personas:fd.get("personas")?parseInt(fd.get("personas")):1,
        fecha:firebase.firestore.Timestamp.fromDate(fecha),fecha_hora:fecha.toISOString(),
        estado:"PENDIENTE",origen:"web",fecha_creacion:firebase.firestore.FieldValue.serverTimestamp()
      }).then(function(){e.target.innerHTML='<div style="text-align:center;padding:20px"><h3 style="color:green">✅ ¡Solicitud enviada!</h3><p>Te confirmaremos pronto.</p></div>';
      }).catch(function(err){alert("Error: "+err.message);});
    });
  }

  function cargarBlog(db) {
    var el = document.getElementById("fluixcrm_blog"); if (!el) return;
    db.collection("empresas").doc(EMPRESA_ID).collection("blog")
      .where("publicada","==",true).orderBy("fecha_publicacion","desc").limit(6)
      .onSnapshot(function(snap){
        if(snap.empty){el.innerHTML="<p>Sin noticias por el momento.</p>";return;}
        el.innerHTML='<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:18px">'
          +snap.docs.map(function(d){var b=d.data();var f=b.fecha_publicacion&&b.fecha_publicacion.toDate?b.fecha_publicacion.toDate().toLocaleDateString("es-ES"):"";
            return '<article style="border:1px solid #eee;border-radius:10px;overflow:hidden">'
              +(b.imagen_url?'<img src="'+b.imagen_url+'" style="width:100%;height:160px;object-fit:cover">':'<div style="height:6px;background:#1976D2"></div>')
              +'<div style="padding:14px"><h4 style="margin:0 0 8px">'+b.titulo+'</h4><p style="color:#666;font-size:13px;margin:0 0 10px">'+(b.resumen||'')+'</p><small style="color:#999">'+f+'</small></div></article>';
          }).join("")+'</div>';
      });
  }

  async function registrarVisita(db) {
    var fechaHoy = new Date().toISOString().substring(0, 10);
    var paginaActual = window.location.pathname || '/';
    var hora = new Date().getHours();
    var referrer = document.referrer || 'Directo';
    await db.collection('empresas').doc(EMPRESA_ID).collection('estadisticas').doc('web_resumen')
      .set({visitas_totales:firebase.firestore.FieldValue.increment(1),visitas_mes:firebase.firestore.FieldValue.increment(1),
        ultima_visita:firebase.firestore.FieldValue.serverTimestamp(),sitio_web:DOMINIO_WEB,nombre_empresa:NOMBRE_EMPRESA,
        pagina_actual:paginaActual,referrer_actual:referrer},{merge:true});
    await db.collection('empresas').doc(EMPRESA_ID).collection('estadisticas').doc('visitas_'+fechaHoy)
      .set({fecha:fechaHoy,sitio:DOMINIO_WEB,visitas:firebase.firestore.FieldValue.increment(1),
        paginas_vistas:firebase.firestore.FieldValue.arrayUnion(paginaActual),
        referrers:firebase.firestore.FieldValue.arrayUnion(referrer),
        ['visitas_hora_'+hora]:firebase.firestore.FieldValue.increment(1),
        timestamp:firebase.firestore.FieldValue.serverTimestamp()},{merge:true});
    console.log('✅ Visita registrada para ' + NOMBRE_EMPRESA);
  }

  async function rastrearEventos(db) {
    document.querySelectorAll('a[href^="tel:"], .telefono, .phone').forEach(function(tel){
      tel.addEventListener('click',function(){db.collection("empresas").doc(EMPRESA_ID).collection("eventos").add({tipo:"llamada_telefonica",sitio:DOMINIO_WEB,fecha:firebase.firestore.FieldValue.serverTimestamp()});});
    });
    document.querySelectorAll('form[id*="contact"], form[class*="contact"], .contact-form').forEach(function(form){
      form.addEventListener('submit',function(){db.collection("empresas").doc(EMPRESA_ID).collection("eventos").add({tipo:"formulario_contacto",sitio:DOMINIO_WEB,fecha:firebase.firestore.FieldValue.serverTimestamp()});});
    });
    document.querySelectorAll('a[href*="wa.me"], a[href*="whatsapp"], .whatsapp-btn').forEach(function(btn){
      btn.addEventListener('click',function(){db.collection("empresas").doc(EMPRESA_ID).collection("eventos").add({tipo:"whatsapp_click",sitio:DOMINIO_WEB,fecha:firebase.firestore.FieldValue.serverTimestamp()});});
    });
  }

})();
</script>''';
  }

  void _copiarAlPortapapeles(String script) {
    Clipboard.setData(ClipboardData(text: script));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Script copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
    setState(() {
      _scriptCopiado = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _scriptCopiado = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integración Web - Script'),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _scriptFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!['exito'] != true) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.data?['error'] ?? 'Desconocido'}'),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final nombreEmpresa = data['nombre'] as String;
          final dominio = data['dominio'] as String;
          final script = data['script'] as String;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  Card(
                    color: const Color(0xFF1565C0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🌐 Integración Web Personalizada',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nombreEmpresa,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dominio,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Instrucciones
                  const Text(
                    '📋 Instrucciones de Instalación:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionStep(
                    '1',
                    'Copia el script',
                    'Haz clic en el botón "Copiar Script" a continuación',
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionStep(
                    '2',
                    'Accede a WordPress',
                    'Ve a tu panel de administración de WordPress en $dominio',
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionStep(
                    '3',
                    'Pega el script',
                    'Ve a Apariencia > Editor de temas > Busca footer.php\n(O usa un plugin como "Code Snippets")',
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionStep(
                    '4',
                    'Pega antes de </body>',
                    'Pega el script completo antes de la etiqueta de cierre </body>',
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionStep(
                    '5',
                    'Guarda los cambios',
                    'Haz clic en "Guardar" o "Actualizar"',
                  ),
                  const SizedBox(height: 24),

                  // Qué hará el script
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
                        const Text(
                          '📊 Qué hará este script:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildFeature('Registra todas las visitas a tu web'),
                        _buildFeature('Rastreatoda llamadas telefónicas'),
                        _buildFeature('Rastreera formularios de contacto'),
                        _buildFeature('Rastreera clicks en WhatsApp'),
                        _buildFeature('Sincroniza datos en tiempo real con Fluix CRM'),
                        const SizedBox(height: 8),
                        const Text(
                          '📍 Los datos aparecerán en:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        _buildFeature('Módulo de Estadísticas (Tráfico Web)'),
                        _buildFeature('Módulo de Eventos (Acciones de clientes)'),
                        _buildFeature('Dashboard principal'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Script Preview
                  const Text(
                    '📄 Script para copiar:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: Colors.grey[800],
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'script-fluixcrm.html',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _copiarAlPortapapeles(script),
                                icon: Icon(
                                  _scriptCopiado ? Icons.check : Icons.copy,
                                  size: 18,
                                ),
                                label: Text(
                                  _scriptCopiado ? 'Copiado!' : 'Copiar',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _scriptCopiado
                                      ? Colors.green
                                      : const Color(0xFF1565C0),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SelectableText(
                                script,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info adicional
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠️ Notas Importantes:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• El script es seguro y no bloqueará tu web si falla\n'
                          '• Se ejecuta cuando la página termina de cargar\n'
                          '• Los datos se registran en tiempo real\n'
                          '• No requiere mantenimiento adicional',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFF1565C0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text('✓ ', style: TextStyle(color: Colors.green)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}


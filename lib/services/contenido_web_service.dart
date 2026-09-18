import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/modelos/seccion_web.dart';
import '../domain/modelos/evento_web.dart';

// ignore_for_file: avoid_print

class ContenidoWebService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<List<SeccionWeb>> obtenerSecciones(String empresaId) {
    if (empresaId.isEmpty) {
      print('❌ obtenerSecciones: empresaId está VACÍO — no se puede cargar contenido web');
      return Stream.value([]);
    }
    print('📂 obtenerSecciones: escuchando empresas/$empresaId/contenido_web');
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contenido_web')
        .snapshots()
        .map((snap) {
          print('📂 contenido_web: recibidos ${snap.docs.length} documentos');
          final lista = <SeccionWeb>[];
          for (final d in snap.docs) {
            try {
              final seccion = SeccionWeb.fromMap({...d.data(), 'id': d.id});
              lista.add(seccion);
              print('  ✅ ${d.id}: tipo=${seccion.tipo.id} nombre="${seccion.nombre}"');
            } catch (e, stack) {
              print('  ⚠️ Error parseando ${d.id}: $e');
              print('     Stack: ${stack.toString().split('\n').take(3).join(' | ')}');
            }
          }
          lista.sort((a, b) {
            try {
              final docA = snap.docs.firstWhere((d) => d.id == a.id);
              final docB = snap.docs.firstWhere((d) => d.id == b.id);
              final oa = (docA.data()['orden'] as num?)?.toInt() ?? 0;
              final ob = (docB.data()['orden'] as num?)?.toInt() ?? 0;
              return oa.compareTo(ob);
            } catch (_) {
              return 0;
            }
          });
          print('📂 contenido_web: devolviendo ${lista.length} secciones válidas');
          return lista;
        })
        .handleError((e) {
          print('❌ obtenerSecciones ERROR: $e');
          return <SeccionWeb>[];
        });
  }

  Future<void> guardarSeccion(String empresaId, SeccionWeb seccion) async {
    final docRef = _firestore
        .collection('empresas').doc(empresaId)
        .collection('contenido_web')
        .doc(seccion.id.isEmpty ? null : seccion.id);

    // Snapshot de la versión anterior antes de sobreescribir
    if (seccion.id.isNotEmpty) {
      try {
        final prev = await docRef.get();
        if (prev.exists && prev.data() != null) {
          final histRef = docRef.collection('historial').doc();
          await histRef.set({
            ...prev.data()!,
            'guardado_en': FieldValue.serverTimestamp(),
          });
          // Conservar máximo 10 versiones
          final old = await docRef.collection('historial')
              .orderBy('guardado_en', descending: true)
              .get();
          if (old.docs.length > 10) {
            for (final d in old.docs.skip(10)) {
              await d.reference.delete();
            }
          }
        }
      } catch (_) {}
    }

    final data = seccion.toMap();
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    data['orden'] = data['orden'] ?? 0;
    await docRef.set(data, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> obtenerHistorial(
      String empresaId, String seccionId) {
    return _firestore
        .collection('empresas').doc(empresaId)
        .collection('contenido_web').doc(seccionId)
        .collection('historial')
        .orderBy('guardado_en', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'_id': d.id, ...d.data()})
            .toList());
  }

  Future<void> restaurarVersionSeccion(
      String empresaId, String seccionId, Map<String, dynamic> version) async {
    final data = Map<String, dynamic>.from(version)
      ..remove('_id')
      ..remove('guardado_en');
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('contenido_web').doc(seccionId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> actualizarContenido(
      String empresaId, String seccionId, ContenidoSeccion contenido) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contenido_web')
        .doc(seccionId)
        .update({
      'contenido': contenido.toMap(),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reordenarSecciones(
      String empresaId, List<SeccionWeb> secciones) async {
    final batch = _firestore.batch();
    for (var i = 0; i < secciones.length; i++) {
      final ref = _firestore
          .collection('empresas').doc(empresaId)
          .collection('contenido_web').doc(secciones[i].id);
      batch.update(ref, {'orden': i, 'fecha_actualizacion': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  Future<void> toggleSeccion(
      String empresaId, String seccionId, bool activa) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contenido_web')
        .doc(seccionId)
        .update({
      'activa': activa,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina sección de Firestore → la web la vacía y oculta automáticamente
  Future<void> eliminarSeccion(String empresaId, String seccionId) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contenido_web')
        .doc(seccionId)
        .delete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IMÁGENES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Abre la galería del dispositivo, sube la imagen a Storage y devuelve URL
  Future<String?> subirImagenDesdeGaleria(String empresaId, String carpeta) async {
    try {
      final XFile? img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (img == null) return null;
      final file = File(img.path);
      final ref = _storage
          .ref()
          .child('empresas/$empresaId/$carpeta/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error subiendo imagen desde galería: $e');
      return null;
    }
  }

  /// Selecciona MÚLTIPLES imágenes de la galería, las sube y devuelve sus URLs.
  Future<List<String>> subirMultiplesImagenes(String empresaId, String carpeta) async {
    try {
      final List<XFile> imgs = await _picker.pickMultiImage(
        maxWidth: 1200, maxHeight: 1200, imageQuality: 85,
      );
      if (imgs.isEmpty) return [];
      final urls = <String>[];
      for (int i = 0; i < imgs.length; i++) {
        final ref = _storage.ref().child(
          'empresas/$empresaId/$carpeta/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        await ref.putFile(File(imgs[i].path), SettableMetadata(contentType: 'image/jpeg'));
        urls.add(await ref.getDownloadURL());
      }
      return urls;
    } catch (e) {
      return [];
    }
  }

  Future<String?> subirImagenSeccion(String empresaId, String seccionId) async {
    final url = await subirImagenDesdeGaleria(empresaId, 'secciones/$seccionId');
    if (url == null) return null;
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('contenido_web').doc(seccionId)
        .update({
      'contenido.imagen_url': url,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
    return url;
  }

  Future<void> eliminarImagenSeccion(String empresaId, String seccionId) async {
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('contenido_web').doc(seccionId)
        .update({
      'contenido.imagen_url': FieldValue.delete(),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> subirImagenItemCarta(
      String empresaId, String seccionId, String itemId) async {
    final url = await subirImagenDesdeGaleria(empresaId, 'carta/$seccionId/$itemId');
    if (url == null) return null;
    return await _actualizarImagenEnLista(empresaId, seccionId, itemId, 'items_carta', url);
  }

  Future<String?> subirImagenItemOferta(
      String empresaId, String seccionId, String itemId) async {
    final url = await subirImagenDesdeGaleria(empresaId, 'ofertas/$seccionId/$itemId');
    if (url == null) return null;
    return await _actualizarImagenEnLista(empresaId, seccionId, itemId, 'ofertas', url);
  }

  Future<void> eliminarImagenItem(
      String empresaId, String seccionId, String itemId,
      {String listaKey = 'items_carta'}) async {
    await _actualizarImagenEnLista(empresaId, seccionId, itemId, listaKey, null);
  }

  Future<String?> _actualizarImagenEnLista(String empresaId, String seccionId,
      String itemId, String listaKey, String? url) async {
    final docRef = _firestore
        .collection('empresas').doc(empresaId)
        .collection('contenido_web').doc(seccionId);
    final doc = await docRef.get();
    if (!doc.exists) return null;
    final contenido =
        Map<String, dynamic>.from(doc.data()!['contenido'] as Map? ?? {});
    final lista = List<Map<String, dynamic>>.from(
        (contenido[listaKey] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    final idx = lista.indexWhere((it) => it['id'] == itemId);
    if (idx >= 0) {
      if (url != null) {
        lista[idx] = {...lista[idx], 'imagen_url': url};
      } else {
        lista[idx] = Map<String, dynamic>.from(lista[idx])..remove('imagen_url');
      }
    }
    await docRef.update({
      'contenido.$listaKey': lista,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
    return url;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO CONTENIDO WEB
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<bool> obtenerEstadoContenidoWeb(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('contenido_web')
        .snapshots()
        .map((doc) => doc.exists ? (doc.data()!['activo'] ?? false) : false);
  }

  Future<void> activarContenidoWeb(String empresaId) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('contenido_web')
        .set({'activo': true, 'fecha_activacion': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
  }

  Future<void> desactivarContenidoWeb(String empresaId) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('contenido_web')
        .set({'activo': false}, SetOptions(merge: true));
  }

  Future<bool> estaActivoContenidoWeb(String empresaId) async {
    final doc = await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('contenido_web')
        .get();
    return doc.exists ? (doc.data()!['activo'] ?? false) : false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN DE CÓDIGO JAVASCRIPT
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // render(id, html, show):
  //   - show=true  → inyecta html y muestra el div (display:'')
  //   - show=false → vacía el div y lo oculta (display:'none')
  //
  // Esto permite:
  //   ✅ Toggle ON  → div aparece con contenido en tiempo real
  //   ✅ Toggle OFF → div se vacía y oculta automáticamente
  //   ✅ Eliminar   → docChanges() detecta el borrado y oculta el div
  //   ✅ Secciones ocultas en HTML (display:none) → se revelan al activar

  Future<String> generarCodigoJavaScript(String empresaId) async {
    final secciones = await obtenerSecciones(empresaId).first;
    final activas = secciones.where((s) => s.activa).toList();
    final buf = StringBuffer();

    buf.writeln('<!-- ── FLUIX CRM: scripts de integración ──────────────────────── -->');
    buf.writeln('<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js"></script>');
    buf.writeln('<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js"></script>');
    buf.writeln('<!-- marked.js convierte el Markdown del blog a HTML (obligatorio) -->');
    buf.writeln('<script src="https://cdn.jsdelivr.net/npm/marked@9/marked.min.js"></script>');
    buf.writeln('<script>');
    buf.writeln('(function(){');
    buf.writeln('  const cfg={apiKey:"AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",authDomain:"planeaapp-4bea4.firebaseapp.com",projectId:"planeaapp-4bea4"};');
    buf.writeln('  if(!firebase.apps.length) firebase.initializeApp(cfg);');
    buf.writeln('  const db=firebase.firestore();');
    buf.writeln('  const EMPRESA="$empresaId";');
    buf.writeln('  function render(id,html,show){const el=document.getElementById("fluixcrm_"+id);if(!el)return;el.innerHTML=html;el.style.display=(show===false)?"none":"";}');
    // Ping de estado: solo una vez por sesión de navegador para evitar escrituras en cada visita
    buf.writeln('  if(!sessionStorage.getItem("_fx_p")){sessionStorage.setItem("_fx_p","1");db.collection("empresas").doc(EMPRESA).collection("config_web").doc("script_status").set({ultimo_ping:firebase.firestore.FieldValue.serverTimestamp(),url:window.location.href},{merge:true}).catch(function(){});}');
    buf.writeln('  db.collection("empresas").doc(EMPRESA).collection("contenido_web").onSnapshot(snap=>{');
    buf.writeln('    snap.docChanges().forEach(ch=>{ if(ch.type==="removed") render(ch.doc.id,"",false); });');
    buf.writeln('    snap.forEach(doc=>{');
    buf.writeln('      const d=doc.data(), tipo=d.tipo||"texto", c=d.contenido||{};');
    buf.writeln('      if(!d.activa) { render(doc.id,"",false); return; }');
    buf.writeln('      let html="";');
    buf.writeln('      if(tipo==="texto"){ html=`<h3>\${c.titulo||""}</h3><p>\${c.texto||""}</p>\${c.imagen_url?`<img src="\${c.imagen_url}" style="max-width:100%;border-radius:8px">`:""}`; }');
    buf.writeln('      else if(tipo==="carta"){ html=(c.items_carta||[]).filter(p=>p.disponible!==false).map(p=>`<div style="border-bottom:1px solid #eee;padding:10px 0;display:flex;gap:12px;align-items:start">\${p.imagen_url?`<img src="\${p.imagen_url}" style="width:70px;height:70px;object-fit:cover;border-radius:8px">`:""}<div style="flex:1"><div><strong style="font-size:15px">\${p.nombre}</strong><span style="float:right;font-weight:bold;color:#e65100">\${p.precio}€</span></div><p style="margin:4px 0 0;color:#666;font-size:13px;line-height:1.4">\${p.descripcion||""}</p></div></div>`).join(""); }');
    buf.writeln('      else if(tipo==="galeria"){ html=`<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px">\${(c.imagenes_galeria||[]).map(i=>`<img src="\${i.url}" style="width:100%;border-radius:8px;object-fit:cover;aspect-ratio:1" loading="lazy">`).join("")}</div>`; }');
    buf.writeln('      else if(tipo==="ofertas"){ html=(c.ofertas||[]).filter(o=>o.activa).map(o=>`<div style="border:1px solid #eee;border-radius:8px;padding:14px;margin-bottom:12px">\${o.imagen_url?`<img src="\${o.imagen_url}" style="width:100%;border-radius:6px;margin-bottom:8px">`:""}  <h4 style="margin:0 0 6px">\${o.titulo}</h4><p style="color:#666;font-size:13px">\${o.descripcion||""}</p>\${o.precio_original?`<s style="color:#999">\${o.precio_original}€</s> `:""}\${o.precio_oferta?`<strong style="color:#e53935;font-size:18px">\${o.precio_oferta}€</strong>`:""}</div>`).join(""); }');
    buf.writeln('      else if(tipo==="horarios"){ html=`<table style="width:100%;border-collapse:collapse">\${(c.horarios||[]).map(h=>`<tr style="border-bottom:1px solid #f5f5f5"><td style="padding:8px 12px;font-weight:bold">\${h.dia}</td><td style="padding:8px 12px;color:\${h.cerrado?"#e53935":"#2e7d32"}">\${h.cerrado?"Cerrado":`\${h.apertura} – \${h.cierre}`}</td></tr>`).join("")}</table>`; }');
    buf.writeln('      render(doc.id, html, true);');
    buf.writeln('    });');
    buf.writeln('  });');
    buf.writeln('})();');
    buf.writeln('</script>');

    buf.writeln();
    buf.writeln('<!-- ═══════════════════════════════════════════════════════════ -->');
    buf.writeln('<!-- DIVS donde se inyectará el contenido.                       -->');
    buf.writeln('<!-- Pega cada div en el HTML de tu web en la posición deseada.  -->');
    buf.writeln('<!-- El script solo rellena el div si existe en la página actual -->');
    buf.writeln('<!-- ═══════════════════════════════════════════════════════════ -->');

    // Agrupar por página
    final porPagina = <String, List<SeccionWeb>>{};
    for (final s in activas) {
      (porPagina[s.pagina] ??= []).add(s);
    }
    for (final entry in porPagina.entries) {
      buf.writeln();
      buf.writeln('<!-- ── Página: ${entry.key} ─────────────────────────────── -->');
      for (final s in entry.value) {
        buf.writeln('<!-- ${s.nombre} (${s.tipo.nombre}) -->');
        buf.writeln('<div id="fluixcrm_${s.id}" data-fluix-pagina="${s.pagina}"></div>');
        buf.writeln();
      }
    }

    return buf.toString();
  }

  /// Genera el código completo con SEO, Analytics, Pixel, Popup, Banner,
  /// Contacto, Secciones dinámicas y Blog.
  Future<String> generarCodigoCompleto(String empresaId) async {
    final secciones = await obtenerSecciones(empresaId).first;
    final activas = secciones.where((s) => s.activa).toList();

    final seoSnap = await _seoDoc(empresaId).get();
    final seo = seoSnap.exists ? SeoConfig.fromMap(seoSnap.data()!) : const SeoConfig();

    final cfgSnap = await _configAvanzadaDoc(empresaId).get();
    final cfg = cfgSnap.exists
        ? ConfigWebAvanzada.fromMap(cfgSnap.data()!)
        : const ConfigWebAvanzada();

    final buf = StringBuffer();

    // ── ① SEO — pegar en <head> ───────────────────────────────────────────
    buf.writeln('<!-- ① PEGA ESTO EN EL <head> ─────────────────────────── -->');
    if (seo.tituloSeo.isNotEmpty || seo.descripcionSeo.isNotEmpty) {
      buf.writeln('<!-- SEO Meta Tags -->');
      if (seo.tituloSeo.isNotEmpty) buf.writeln('<title>${seo.tituloSeo}</title>');
      if (seo.descripcionSeo.isNotEmpty)
        buf.writeln('<meta name="description" content="${seo.descripcionSeo}">');
      if (seo.palabrasClave.isNotEmpty)
        buf.writeln('<meta name="keywords" content="${seo.palabrasClave}">');
      if (seo.imagenOg != null)
        buf.writeln('<meta property="og:image" content="${seo.imagenOg}">');
      buf.writeln('<meta name="robots" content="${seo.robotsContent}">');
    }
    if (seo.googleAnalyticsId != null && seo.googleAnalyticsId!.isNotEmpty) {
      buf.writeln('<!-- Google Analytics -->');
      buf.writeln('<script async src="https://www.googletagmanager.com/gtag/js?id=${seo.googleAnalyticsId}"></script>');
      buf.writeln('<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag("js",new Date());gtag("config","${seo.googleAnalyticsId}");</script>');
    }
    if (seo.pixelFacebook != null && seo.pixelFacebook!.isNotEmpty) {
      buf.writeln('<!-- Facebook Pixel -->');
      buf.writeln('<script>!function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version="2.0";n.queue=[];t=b.createElement(e);t.async=!0;t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window,document,"script","https://connect.facebook.net/en_US/fbevents.js");fbq("init","${seo.pixelFacebook}");fbq("track","PageView");</script>');
    }
    buf.writeln('<!-- ────────────────────────────────────────────────────── -->');
    buf.writeln();

    // ── ② Divs de contenido — poner donde quieras en el HTML ─────────────
    if (activas.isNotEmpty || cfg.contactoActivo) {
      buf.writeln('<!-- ② PON ESTOS DIVS DONDE QUIERAS EN TU WEB ─────────── -->');
      buf.writeln('<!-- TIP: añade style="display:none" para ocultar secciones. -->');
      buf.writeln('<!--      Se revelarán automáticamente al activarlas en la app -->');
      for (final s in activas) {
        buf.writeln('<!-- ${s.nombre} (${s.tipo.nombre}) -->');
        buf.writeln('<div id="fluixcrm_${s.id}"></div>');
        buf.writeln();
      }
      if (cfg.contactoActivo) {
        buf.writeln('<!-- Formulario de contacto -->');
        buf.writeln('<div id="fluixcrm_contacto"></div>');
        buf.writeln();
      }
      buf.writeln('<!-- Blog / Noticias -->');
      buf.writeln('<div id="fluixcrm_blog"></div>');
      buf.writeln('');
      buf.writeln('<!-- Reseñas de clientes (sincronizadas con la app) -->');
      buf.writeln('<div id="fluixcrm_resenas"></div>');
      buf.writeln('<!-- ────────────────────────────────────────────────────── -->');
      buf.writeln();
    }

    // ── ③ Script dinámico — pegar antes de </body> ───────────────────────
    buf.writeln('<!-- ③ PEGA ESTO ANTES DEL </body> ────────────────────── -->');
    buf.writeln('<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js"></script>');
    buf.writeln('<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js"></script>');
    buf.writeln('<script>');
    buf.writeln('(function(){');
    buf.writeln('  const cfg={apiKey:"AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",authDomain:"planeaapp-4bea4.firebaseapp.com",projectId:"planeaapp-4bea4"};');
    buf.writeln('  if(!firebase.apps.length) firebase.initializeApp(cfg);');
    buf.writeln('  const db=firebase.firestore();');
    buf.writeln('  const EMPRESA="$empresaId";');
    buf.writeln('  function render(id,html,show){const el=document.getElementById("fluixcrm_"+id);if(!el)return;el.innerHTML=html;el.style.display=(show===false)?"none":"";}');

    // GDPR Cookie banner
    if (cfg.gdprActivo) {
      final gdprTexto    = cfg.gdprTexto ?? 'Usamos cookies para mejorar tu experiencia en nuestra web.';
      final gdprPolitica = cfg.gdprPoliticaUrl ?? '#';
      buf.writeln('  (function(){if(localStorage.getItem("fluix_gdpr_ok"))return;var b=document.createElement("div");b.setAttribute("data-fluix-gdpr","1");b.style="position:fixed;bottom:0;left:0;right:0;background:#1e293b;color:#fff;padding:14px 20px;z-index:10000;display:flex;align-items:center;gap:14px;flex-wrap:wrap;font-family:sans-serif;";b.innerHTML=\'<span style="flex:1;font-size:13px;line-height:1.5">$gdprTexto</span><a href="$gdprPolitica" style="color:#94a3b8;font-size:12px;white-space:nowrap">Política de privacidad</a><button onclick="localStorage.setItem(\'fluix_gdpr_ok\',\'1\');this.closest(\'[data-fluix-gdpr]\').remove()" style="background:#3b82f6;color:#fff;border:none;padding:9px 18px;border-radius:6px;cursor:pointer;font-size:13px;white-space:nowrap">Aceptar</button>\';document.body.appendChild(b);})();');
    }

    // Banner
    if (cfg.bannerActivo && cfg.bannerTexto != null) {
      final bColor = cfg.bannerColor ?? '#1976D2';
      final bDest  = cfg.bannerUrlDestino ?? '#';
      buf.writeln('  (function(){const b=document.createElement("div");b.style="background:$bColor;color:#fff;padding:10px;text-align:center;font-size:14px;position:relative;z-index:999;";b.innerHTML=`<a href="$bDest" style="color:#fff;text-decoration:none;">${cfg.bannerTexto} ▸</a>`;document.body.insertBefore(b,document.body.firstChild);})();');
    }

    // Popup
    if (cfg.popupActivo && cfg.popupTitulo != null) {
      final botonHtml = cfg.popupBotonTexto != null
          ? '<a href="${cfg.popupBotonUrl ?? '#'}" style="background:#1976D2;color:#fff;padding:10px 24px;border-radius:8px;text-decoration:none;font-weight:bold">${cfg.popupBotonTexto}</a>'
          : '';
      buf.writeln('  setTimeout(function(){if(sessionStorage.getItem("fluixcrm_popup_shown"))return;sessionStorage.setItem("fluixcrm_popup_shown","1");const o=document.createElement("div");o.style="position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.5);z-index:9999;display:flex;align-items:center;justify-content:center;";o.innerHTML=`<div style="background:#fff;border-radius:12px;padding:28px;max-width:420px;width:90%;text-align:center;"><h3 style="margin:0 0 12px">${cfg.popupTitulo}</h3><p style="color:#555;margin:0 0 18px">${cfg.popupTexto ?? ""}</p>$botonHtml<br><button onclick="this.closest(\'.fluixcrm_overlay\').remove()" style="margin-top:14px;background:none;border:none;color:#888;cursor:pointer;font-size:13px">✕ Cerrar</button></div>\`;o.classList.add("fluixcrm_overlay");document.body.appendChild(o);o.addEventListener("click",function(e){if(e.target===o)o.remove();});},${cfg.popupRetrasoSeg * 1000});');
    }

    // WhatsApp widget flotante
    if (cfg.whatsappWidgetActivo && cfg.whatsappNumero != null) {
      final numero  = cfg.whatsappNumero!.replaceAll(RegExp(r'[^0-9+]'), '');
      final mensaje = Uri.encodeComponent(cfg.whatsappMensaje ?? 'Hola, me gustaría más información.');
      buf.writeln('  (function(){var a=document.createElement("a");a.href="https://wa.me/$numero?text=$mensaje";a.target="_blank";a.rel="noopener";a.title="WhatsApp";a.style="position:fixed;bottom:20px;right:20px;width:54px;height:54px;background:#25d366;border-radius:50%;display:flex;align-items:center;justify-content:center;z-index:9500;text-decoration:none;box-shadow:0 4px 14px rgba(0,0,0,.25);transition:transform .2s;";a.onmouseenter=function(){this.style.transform="scale(1.1)";};a.onmouseleave=function(){this.style.transform="scale(1)";};a.innerHTML=\'<svg width="26" height="26" viewBox="0 0 24 24" fill="white"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>\';document.body.appendChild(a);})();');
    }

    // Formulario de contacto
    if (cfg.contactoActivo) {
      buf.writeln('  (function(){const el=document.getElementById("fluixcrm_contacto");if(!el)return;el.innerHTML=`<div style="max-width:480px"><h3>${cfg.contactoTitulo ?? "Contáctanos"}</h3><form onsubmit="fluixEnviarContacto(event)" style="display:flex;flex-direction:column;gap:12px"><input name="nombre" placeholder="Tu nombre" required style="padding:10px;border:1px solid #ddd;border-radius:8px"><input name="email" type="email" placeholder="Tu email" required style="padding:10px;border:1px solid #ddd;border-radius:8px"><textarea name="mensaje" placeholder="Tu mensaje" rows="4" required style="padding:10px;border:1px solid #ddd;border-radius:8px;resize:vertical"></textarea><button type="submit" style="background:#1976D2;color:#fff;padding:12px;border:none;border-radius:8px;cursor:pointer;font-weight:bold">Enviar mensaje</button></form></div>`;window.fluixEnviarContacto=function(e){e.preventDefault();const fd=new FormData(e.target);db.collection("empresas").doc(EMPRESA).collection("contacto_web").add({nombre:fd.get("nombre"),email:fd.get("email"),mensaje:fd.get("mensaje"),fecha:firebase.firestore.FieldValue.serverTimestamp(),leido:false}).then(()=>{e.target.innerHTML="<p style=\'color:green;font-weight:bold\'>✅ Mensaje enviado.</p>";}).catch(err=>{alert("Error: "+err.message);});};})();');
    }

    // RESERVAS WEB
    // Inyectar en #fluixcrm_reservas
    buf.writeln('  // Formulario de Reserva Web con Empleados');
    buf.writeln('  (function(){');
    buf.writeln('    const el=document.getElementById("fluixcrm_reservas");');
    buf.writeln('    if(!el) return;');
    buf.writeln('    var empleados=[];var empleadoSel=null;');
    buf.writeln('    db.collection("empresas").doc(EMPRESA).collection("empleados").where("activo","==",true).get().then(function(snap){');
    buf.writeln('      empleados=snap.docs.map(function(d){return{id:d.id,nombre:d.data().nombre||"Sin nombre"};});');
    buf.writeln('      renderFormulario();');
    buf.writeln('    }).catch(function(){renderFormulario();});');
    buf.writeln('    function renderFormulario(){');
    buf.writeln('      var empleadosHTML=empleados.length>0?"<label style=\\"font-size:13px;color:#555;margin:8px 0 4px;display:block\\">Empleado preferido (opcional)</label><select name=\\"empleado\\" style=\\"padding:12px;border:1px solid #ddd;border-radius:8px;width:100%\\"><option value=\\"\\">Sin preferencia</option>"+empleados.map(function(e){return"<option value=\\""+e.id+"\\">"+e.nombre+"</option>";}).join("")+"</select>":"";');
    buf.writeln('      el.innerHTML="<div style=\\"max-width:480px;border:1px solid #eee;padding:24px;border-radius:12px\\"><h3>📅 Reservar Mesa / Cita</h3><form onsubmit=\\"fluixReserva(event)\\" style=\\"display:flex;flex-direction:column;gap:14px\\"><input name=\\"nombre\\" placeholder=\\"Tu nombre\\" required style=\\"padding:12px;border:1px solid #ddd;border-radius:8px\\"><input name=\\"telefono\\" type=\\"tel\\" placeholder=\\"Tu teléfono\\" required style=\\"padding:12px;border:1px solid #ddd;border-radius:8px\\"><div style=\\"display:flex;gap:10px\\"><input name=\\"fecha\\" type=\\"date\\" required style=\\"padding:12px;border:1px solid #ddd;border-radius:8px;flex:1\\"><input name=\\"hora\\" type=\\"time\\" required style=\\"padding:12px;border:1px solid #ddd;border-radius:8px;flex:1\\"></div><input name=\\"personas\\" type=\\"number\\" min=\\"1\\" placeholder=\\"Nº Personas\\" style=\\"padding:12px;border:1px solid #ddd;border-radius:8px\\">"+empleadosHTML+"<button type=\\"submit\\" style=\\"background:#1976D2;color:#fff;padding:14px;border:none;border-radius:8px;cursor:pointer;font-weight:bold;font-size:16px\\">Solicitar Reserva</button></form></div>";');
    buf.writeln('    }');
    buf.writeln('    window.fluixReserva=function(e){');
    buf.writeln('      e.preventDefault();');
    buf.writeln('      const fd=new FormData(e.target);');
    buf.writeln('      const fechaStr = fd.get("fecha") + "T" + fd.get("hora") + ":00";');
    buf.writeln('      const fecha = new Date(fechaStr);');
    buf.writeln('      const empleadoId=fd.get("empleado")||null;');
    buf.writeln('      const empleadoNombre=empleadoId?empleados.find(function(e){return e.id===empleadoId;})?.nombre:null;');
    buf.writeln('      db.collection("empresas").doc(EMPRESA).collection("reservas").add({');
    buf.writeln('        nombre_cliente: fd.get("nombre"),');
    buf.writeln('        telefono_cliente: fd.get("telefono"),');
    buf.writeln('        personas: fd.get("personas") ? parseInt(fd.get("personas")) : 1,');
    buf.writeln('        fecha: firebase.firestore.Timestamp.fromDate(fecha),');
    buf.writeln('        fecha_hora: fecha.toISOString(),');
    buf.writeln('        estado: "PENDIENTE",');
    buf.writeln('        origen: "web",');
    buf.writeln('        empleado_asignado: empleadoId,');
    buf.writeln('        empleado_nombre: empleadoNombre,');
    buf.writeln('        fecha_creacion: firebase.firestore.FieldValue.serverTimestamp()');
    buf.writeln('      }).then(function(){');
    buf.writeln('        if(empleadoId&&empleadoNombre){');
    buf.writeln('          db.collection("empresas").doc(EMPRESA).collection("estadisticas").doc("empleados_rendimiento").set({');
    buf.writeln('            empleados:{[empleadoNombre]:{empleado_id:empleadoId,total_reservas:firebase.firestore.FieldValue.increment(1),ultima_actualizacion:firebase.firestore.FieldValue.serverTimestamp()}}');
    buf.writeln('          },{merge:true}).catch(function(e){console.warn("Stats update error:",e);});');
    buf.writeln('        }');
    buf.writeln('        e.target.innerHTML="<div style=\'text-align:center;padding:20px\'><h3 style=\'color:green\'>✅ ¡Solicitud enviada!</h3><p>Te confirmaremos pronto.</p></div>";');
    buf.writeln('      }).catch(err=>{alert("Error: "+err.message);});');
    buf.writeln('    };');
    buf.writeln('  })();');

    // Secciones dinámicas con control de visibilidad y detección de eliminados
    buf.writeln('  db.collection("empresas").doc(EMPRESA).collection("contenido_web").onSnapshot(snap=>{');
    buf.writeln('    snap.docChanges().forEach(ch=>{ if(ch.type==="removed") render(ch.doc.id,"",false); });');
    buf.writeln('    snap.forEach(doc=>{');
    buf.writeln('      const d=doc.data(), tipo=d.tipo||"texto", c=d.contenido||{};');
    buf.writeln('      if(!d.activa) { render(doc.id,"",false); return; }');
    buf.writeln('      let html="";');
    buf.writeln('      if(tipo==="texto"){ html=`<h3>\${c.titulo||""}</h3><p>\${c.texto||""}</p>\${c.imagen_url?`<img src="\${c.imagen_url}" style="max-width:100%;border-radius:8px">`:""}`; }');
    buf.writeln('      else if(tipo==="carta"){ html=(c.items_carta||[]).filter(p=>p.disponible!==false).map(p=>`<div style="border-bottom:1px solid #eee;padding:10px 0;display:flex;gap:12px;align-items:start">\${p.imagen_url?`<img src="\${p.imagen_url}" style="width:70px;height:70px;object-fit:cover;border-radius:8px">`:""}<div style="flex:1"><div><strong style="font-size:15px">\${p.nombre}</strong><span style="float:right;font-weight:bold;color:#e65100">\${p.precio}€</span></div><p style="margin:4px 0 0;color:#666;font-size:13px;line-height:1.4">\${p.descripcion||""}</p></div></div>`).join(""); }');
    buf.writeln('      else if(tipo==="galeria"){ html=`<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px">\${(c.imagenes_galeria||[]).map(i=>`<img src="\${i.url}" style="width:100%;border-radius:8px;object-fit:cover;aspect-ratio:1" loading="lazy">`).join("")}</div>`; }');
    buf.writeln('      else if(tipo==="ofertas"){ html=(c.ofertas||[]).filter(o=>o.activa).map(o=>`<div style="border:1px solid #eee;border-radius:8px;padding:14px;margin-bottom:12px">\${o.imagen_url?`<img src="\${o.imagen_url}" style="width:100%;border-radius:6px;margin-bottom:8px">`:""}  <h4 style="margin:0 0 6px">\${o.titulo}</h4><p style="color:#666;font-size:13px">\${o.descripcion||""}</p>\${o.precio_original?`<s style="color:#999">\${o.precio_original}€</s> `:""}\${o.precio_oferta?`<strong style="color:#e53935;font-size:18px">\${o.precio_oferta}€</strong>`:""}</div>`).join(""); }');
    buf.writeln('      else if(tipo==="horarios"){ html=`<table style="width:100%;border-collapse:collapse">\${(c.horarios||[]).map(h=>`<tr style="border-bottom:1px solid #f5f5f5"><td style="padding:8px 12px;font-weight:bold">\${h.dia}</td><td style="padding:8px 12px;color:\${h.cerrado?"#e53935":"#2e7d32"}">\${h.cerrado?"Cerrado":`\${h.apertura} – \${h.cierre}`}</td></tr>`).join("")}</table>`; }');
    buf.writeln('      render(doc.id, html, true);');
    buf.writeln('    });');
    buf.writeln('  });');

    // Reseñas / Valoraciones
    buf.writeln('  (function(){');
    buf.writeln('    var el=document.getElementById("fluixcrm_resenas");if(!el)return;');
    buf.writeln('    el.innerHTML="<p style=\'color:#999;text-align:center\'>Cargando reseñas…</p>";');
    buf.writeln('    db.collection("empresas").doc(EMPRESA).collection("valoraciones").orderBy("fecha_creacion","desc").limit(10).get().then(function(snap){');
    buf.writeln('      if(snap.empty){el.innerHTML="";return;}');
    buf.writeln('      var total=snap.size,suma=0;');
    buf.writeln('      var items=snap.docs.map(function(d){var v=d.data();suma+=v.estrellas||v.calificacion||0;return v;});');
    buf.writeln('      var media=(suma/total).toFixed(1);');
    buf.writeln('      var estrellas=function(n){var s="";for(var i=1;i<=5;i++)s+=\'<svg width="14" height="14" viewBox="0 0 24 24" fill="\'+(i<=Math.round(n)?"#c9a24a":"#e2d8c9")+\'" xmlns="http://www.w3.org/2000/svg"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>\';return s;};');
    buf.writeln('      var html=\'<div style="font-family:var(--font-sans,sans-serif)">\'+');
    buf.writeln('        \'<div style="display:flex;align-items:center;gap:12px;margin-bottom:1.5rem;padding-bottom:1rem;border-bottom:1px solid var(--border,#e2d8c9)">\'+');
    buf.writeln('          \'<span style="font-family:var(--font-serif,serif);font-size:3rem;font-weight:400;line-height:1">\'+media+\'</span>\'+');
    buf.writeln('          \'<div><div style="display:flex;gap:2px">\'+estrellas(parseFloat(media))+\'</div><div style="font-size:12px;color:var(--muted,#8a7b6e);margin-top:4px">\'+total+\' reseña\'+(total!==1?"s":"")+\'</div></div>\'+');
    buf.writeln('        \'</div>\'+');
    buf.writeln('        items.slice(0,5).map(function(v){');
    buf.writeln('          var stars=v.estrellas||v.calificacion||0;');
    buf.writeln('          var nombre=v.cliente_nombre||v.nombre||v.autor||"Cliente";');
    buf.writeln('          var texto=v.comentario||v.texto||v.resena||"";');
    buf.writeln('          var fecha=v.fecha_creacion?.toDate?v.fecha_creacion.toDate().toLocaleDateString("es-ES"):"";');
    buf.writeln('          return\'<div style="padding:1rem 0;border-bottom:1px solid var(--border,#e2d8c9)">\'+');
    buf.writeln('            \'<div style="display:flex;justify-content:space-between;margin-bottom:6px">\'+');
    buf.writeln('              \'<div style="display:flex;gap:2px">\'+estrellas(stars)+\'</div>\'+');
    buf.writeln('              \'<span style="font-size:11px;color:var(--muted,#8a7b6e)">\'+fecha+\'</span>\'+');
    buf.writeln('            \'</div>\'+');
    buf.writeln('            (texto?\'<p style="font-size:.88rem;line-height:1.6;margin:0 0 6px">\'+texto+\'</p>\':\'\') +');
    buf.writeln('            \'<span style="font-size:.78rem;font-weight:600;color:var(--primary,#6b1e2a)">\'+nombre+\'</span>\'+');
    buf.writeln('          \'</div>\';');
    buf.writeln('        }).join("")+');
    buf.writeln('      \'</div>\';');
    buf.writeln('      el.innerHTML=html;');
    buf.writeln('    }).catch(function(){el.innerHTML="";});');
    buf.writeln('  })();');
    buf.writeln('');

    // Blog
    buf.writeln('  db.collection("empresas").doc(EMPRESA).collection("blog").where("publicada","==",true).orderBy("fecha_publicacion","desc").limit(6).onSnapshot(snap=>{');
    buf.writeln('    const el=document.getElementById("fluixcrm_blog");if(!el)return;');
    buf.writeln('    if(snap.empty){el.innerHTML="<p>Sin noticias por el momento.</p>";return;}');
    buf.writeln('    el.innerHTML=`<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:18px">\${snap.docs.map(d=>{const b=d.data();return`<article style="border:1px solid #eee;border-radius:10px;overflow:hidden">\${b.imagen_url?`<img src="\${b.imagen_url}" style="width:100%;height:160px;object-fit:cover">`:"<div style=\\"height:6px;background:#1976D2\\"></div>"}<div style="padding:14px"><h4 style="margin:0 0 8px">\${b.titulo}</h4><p style="color:#666;font-size:13px;margin:0 0 10px">\${b.resumen||""}</p><small style="color:#999">\${new Date(b.fecha_publicacion?.toDate?.()??b.fecha_publicacion).toLocaleDateString("es-ES")}</small></div></article>`}).join("")}</div>`;');
    buf.writeln('  });');

    buf.writeln('})();');
    buf.writeln('</script>');
    buf.writeln('<!-- ────────────────────────────────────────────────────── -->');

    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ITEMS GENÉRICOS (data-fluix)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda la lista de items genéricos de una sección de tipo `generico`
  Future<void> guardarItemsGenericos(
      String empresaId, String seccionId, List<Map<String, dynamic>> items) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contenido_web')
        .doc(seccionId)
        .update({
      'contenido.items': items,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza el nombre de una sección
  Future<void> actualizarNombreSeccion(
      String empresaId, String seccionId, String nombre) async {
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contenido_web')
        .doc(seccionId)
        .update({
      'nombre': nombre,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERADOR DE SCRIPT HOSTINGER (data-fluix)
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Fluix Web SDK — script completo ─────────────────────────────────────
  // Detecta módulos data-fluix-* en el DOM y conecta con Firestore.
  // Uso en HTML: <div data-fluix-agenda></div>  → agenda en tiempo real
  //              <div data-fluix-catalogo></div> → catálogo
  //              <div data-fluix-blog></div>      → blog/noticias
  //              <div data-fluix-contacto></div>  → formulario de contacto
  //              <div data-fluix-resenas></div>   → valoraciones
  //              <div data-fluix-seccion="id"></div> → sección personalizada
  // Atributos de config: data-fluix-limite, data-fluix-tipo, data-fluix-ciudad, data-fluix-categoria

  /// Genera el Fluix Web SDK para Hostinger
  String generarScriptHostinger(String empresaId) {
    final sdk = _fluixWebSdk.replaceAll('__EMPRESA__', empresaId);
    return '<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js"></script>\n'
        '<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js"></script>\n'
        '<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-auth-compat.js"></script>\n'
        '<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js"></script>\n'
        '<script>\n$sdk\n</script>\n';
  }

  /// Contenido del service worker que el cliente debe subir a /firebase-messaging-sw.js
  static String generarServiceWorkerPush() => '''
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');
firebase.initializeApp({
  apiKey:"AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",
  authDomain:"planeaapp-4bea4.firebaseapp.com",
  projectId:"planeaapp-4bea4",
  messagingSenderId:"1085482191658",
  appId:"1:1085482191658:web:c5461353b123ab92d62c53"
});
const messaging = firebase.messaging();
messaging.onBackgroundMessage(function(payload) {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'Nueva actualización', {
    body: n.body || '',
    icon: n.icon || '/favicon.ico',
    badge: '/favicon.ico',
    data: payload.data || {}
  });
});
''';

  // ── Push config ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> obtenerConfigPush(String empresaId) async {
    final doc = await _firestore
        .collection('empresas').doc(empresaId)
        .collection('config_web').doc('push_config')
        .get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> guardarConfigPush(String empresaId, String vapidKey) async {
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('config_web').doc('push_config')
        .set({'vapid_key': vapidKey}, SetOptions(merge: true));
  }

  // ── CDN config ───────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> obtenerConfigCdn(String empresaId) {
    return _firestore
        .collection('empresas').doc(empresaId)
        .collection('config_web').doc('cdn_config')
        .snapshots()
        .map((doc) => doc.exists ? doc.data()! : <String, dynamic>{});
  }

  Future<void> guardarConfigCdn(String empresaId, Map<String, String> cfg) async {
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('config_web').doc('cdn_config')
        .set(cfg, SetOptions(merge: true));
  }

  // Raw JS SDK — usa __EMPRESA__ como placeholder; se reemplaza en tiempo real
  static const String _fluixWebSdk = r'''
(function(){
  /* ── Firebase ── */
  var CFG={apiKey:"AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",authDomain:"planeaapp-4bea4.firebaseapp.com",projectId:"planeaapp-4bea4",storageBucket:"planeaapp-4bea4.firebasestorage.app",messagingSenderId:"1085482191658",appId:"1:1085482191658:web:c5461353b123ab92d62c53"};
  var app=(firebase.apps||[]).find(function(a){return a&&a.name==="FluixApp";})||firebase.initializeApp(CFG,"FluixApp");
  var db=firebase.firestore();
  var auth=firebase.auth();
  var EMPRESA="__EMPRESA__";

  /* ── Helpers ── */
  function fcfg(el,k,def){return el.getAttribute("data-fluix-"+k)||def||"";}
  function fmtFecha(ts){
    var d=ts&&ts.toDate?ts.toDate():(ts?new Date(ts):null);
    if(!d||isNaN(d))return"";
    return d.toLocaleDateString("es-ES",{day:"2-digit",month:"2-digit",year:"numeric"});
  }
  function fmtCarta(ts){
    var d=ts&&ts.toDate?ts.toDate():(ts?new Date(ts):null);
    if(!d||isNaN(d))return{dia:"",mes:"",anio:""};
    var M=["ENE","FEB","MAR","ABR","MAY","JUN","JUL","AGO","SEP","OCT","NOV","DIC"];
    return{dia:String(d.getDate()).padStart(2,"0"),mes:M[d.getMonth()],anio:d.getFullYear()};
  }
  function wField(ce,campo,item){
    var v=item[campo],tag=ce.tagName.toLowerCase();
    if(v===undefined||v===null){if(tag==="img")ce.style.display="none";return;}
    if(campo==="fecha"){ce.textContent=fmtFecha(v);return;}
    if(tag==="img"){ce.src=v||"";ce.style.display=v?"":"none";return;}
    if(tag==="a"){ce.href=v||"#";return;}
    ce.textContent=v;
  }
  function fillFields(root,item){
    root.querySelectorAll("[data-fluix-campo]").forEach(function(ce){wField(ce,ce.getAttribute("data-fluix-campo"),item);});
  }
  function renderTpl(container,tpl,items){
    var cur={};
    container.querySelectorAll("[data-fluix-id]").forEach(function(el){cur[el.getAttribute("data-fluix-id")]=el;});
    var del=Object.assign({},cur);
    items.forEach(function(item){
      var id=item.id||Math.random().toString(36).slice(2),el=cur[id];
      if(!el){var cl=tpl.content.cloneNode(true);el=cl.firstElementChild;el.setAttribute("data-fluix-id",id);container.appendChild(el);}
      delete del[id];
      fillFields(el,item);
    });
    Object.values(del).forEach(function(el){el.remove();});
  }

  /* ── SEO automático: inyecta <title>, meta y JSON-LD por contenido ── */
  function injectSeo(titulo,desc,img,jsonld){
    var h=document.head;
    if(titulo)document.title=titulo;
    function setM(sel,attr,val,content){if(!val)return;var m=h.querySelector(sel)||document.createElement("meta");m.setAttribute(attr,val);if(content!==undefined)m.content=content;if(!m.parentNode)h.appendChild(m);}
    setM('meta[name="description"]',"name","description",desc||"");
    setM('meta[property="og:title"]',"property","og:title",titulo||"");
    setM('meta[property="og:description"]',"property","og:description",desc||"");
    if(img)setM('meta[property="og:image"]',"property","og:image",img);
    setM('meta[property="og:type"]',"property","og:type","website");
    if(jsonld){var s=document.getElementById("fluix-jsonld")||document.createElement("script");s.id="fluix-jsonld";s.type="application/ld+json";s.textContent=JSON.stringify(jsonld);if(!s.parentNode)h.appendChild(s);}
  }

  /* ══ Módulo: data-fluix-agenda ══════════════════════════════════════ */
  function modAgenda(){
    document.querySelectorAll("[data-fluix-agenda]").forEach(function(el){
      var limite=parseInt(fcfg(el,"limite","50")),tipos=fcfg(el,"tipo","").split(",").map(function(s){return s.trim();}).filter(Boolean),ciudad=fcfg(el,"ciudad",""),detalleUrl=fcfg(el,"detalle-url","?evento="),tpl=el.querySelector("template[data-fluix-item]");
      db.collection("empresas").doc(EMPRESA).collection("eventos").where("activo","==",true).orderBy("fecha").onSnapshot(function(snap){
        var items=[];
        snap.forEach(function(doc){var d=doc.data();d.id=doc.id;if(d.eliminado)return;if(d.activo===false||(!d.activo&&d.publicado===false))return;if(tipos.length&&tipos.indexOf(d.tipo||"")<0)return;if(ciudad&&d.ciudad!==ciudad)return;items.push(d);});
        items=items.slice(0,limite);
        if(!items.length){el.innerHTML='<p class="fluix-vacio">Sin eventos próximos.</p>';return;}
        // Añadir data-tipo y data-fecha para que los filtros client-side funcionen
        if(tpl){
          renderTpl(el,tpl,items);
          el.querySelectorAll("[data-fluix-id]").forEach(function(card,i){
            if(i<items.length){card.setAttribute("data-tipo",items[i].tipo||"");card.setAttribute("data-fecha",items[i].fecha&&items[i].fecha.toDate?items[i].fecha.toDate().toISOString():(items[i].fecha||""));}
          });
          return;
        }
        el.innerHTML=items.map(function(ev){
          var f=fmtCarta(ev.fecha),img=ev.imagen_url?'<img class="ev-img" src="'+ev.imagen_url+'" alt="" loading="lazy">':'';
          var fechaISO=ev.fecha&&ev.fecha.toDate?ev.fecha.toDate().toISOString():"";
          return'<a class="ev-card" href="'+detalleUrl+ev.id+'" data-fluix-id="'+ev.id+'" data-tipo="'+(ev.tipo||"")+'" data-ciudad="'+(ev.ciudad||"")+'" data-fecha="'+fechaISO+'">'
            +'<div class="ev-left">'+img+'<div class="ev-date"><span class="ev-dmes">'+f.mes+'</span><span class="ev-dnum">'+f.dia+'</span><span class="ev-danio">'+f.anio+'</span></div></div>'
            +'<div class="ev-body"><span class="ev-tipo">'+(ev.tipo||"Evento")+'</span>'
            +'<div class="ev-titulo">'+(ev.titulo||"")+'</div>'
            +(ev.subtitulo?'<div class="ev-subtitulo">'+ev.subtitulo+'</div>':"")
            +(ev.lugar?'<div class="ev-lugar">'+ev.lugar+(ev.ciudad&&ev.ciudad!==ev.lugar?", "+ev.ciudad:"")+'</div>':"")
            +'<div class="ev-foot"><span class="ev-hora">'+(ev.hora||"")+'</span><span class="ev-btn">Ver más</span></div>'
            +'</div></a>';
        }).join("");
      });
    });
  }

  /* ══ Módulo: data-fluix-agenda-detalle ══════════════════════════════ */
  function modAgendaDetalle(){
    var el=document.querySelector("[data-fluix-agenda-detalle]");if(!el)return;
    var id=new URLSearchParams(window.location.search).get("evento");
    if(!id){el.style.display="none";return;}
    el.style.display="";
    db.collection("empresas").doc(EMPRESA).collection("eventos").doc(id).get().then(function(doc){
      if(!doc.exists){el.innerHTML="<p>Evento no encontrado.</p>";return;}
      var ev=doc.data();ev.id=doc.id;
      ev.fecha_fmt=fmtFecha(ev.fecha);
      var tpl=el.querySelector("template[data-fluix-item]");
      if(tpl){var cl=tpl.content.cloneNode(true);fillFields(cl.firstElementChild,ev);el.appendChild(cl);}
      else fillFields(el,ev);
      injectSeo(ev.titulo,ev.descripcion||ev.subtitulo,ev.imagen_url,{"@context":"https://schema.org","@type":"Event",name:ev.titulo||"",description:ev.descripcion||ev.subtitulo||"",image:ev.imagen_url||"",startDate:ev.fecha&&ev.fecha.toDate?ev.fecha.toDate().toISOString():""});
    });
  }

  /* ══ Módulo: data-fluix-catalogo ════════════════════════════════════ */
  function modCatalogo(){
    document.querySelectorAll("[data-fluix-catalogo]").forEach(function(el){
      var limite=parseInt(fcfg(el,"limite","50")),cat=fcfg(el,"categoria",""),tpl=el.querySelector("template[data-fluix-item]");
      db.collection("empresas").doc(EMPRESA).collection("catalogo_web").where("activo","==",true).orderBy("orden").onSnapshot(function(snap){
        var items=[];
        snap.forEach(function(doc){var d=doc.data();d.id=doc.id;if(cat&&d.categoria!==cat)return;items.push(d);});
        items=items.slice(0,limite);
        if(!items.length){el.innerHTML="";return;}
        if(tpl){renderTpl(el,tpl,items);return;}
        el.innerHTML=items.map(function(it){
          return'<div class="fluix-cat-item" data-fluix-id="'+it.id+'">'
            +(it.imagen_url?'<img class="fluix-cat-img" src="'+it.imagen_url+'" alt="'+it.nombre+'" loading="lazy">':"")
            +'<div class="fluix-cat-body">'
            +(it.tag?'<span class="fluix-cat-tag">'+it.tag+'</span>':"")
            +'<h3 class="fluix-cat-nombre">'+it.nombre+'</h3>'
            +(it.campo_autor?'<span class="fluix-cat-autor">'+it.campo_autor+'</span>':"")
            +(it.descripcion?'<p class="fluix-cat-desc">'+it.descripcion+'</p>':"")
            +(it.precio?'<span class="fluix-cat-precio">'+it.precio+'</span>':"")
            +(it.precio_digital?'<span class="fluix-cat-precio-digital">'+it.precio_digital+'</span>':"")
            +(it.stripe_link?'<a href="'+it.stripe_link+'" target="_blank" rel="noopener" class="fluix-cat-comprar">Comprar</a>':"")
            +'</div></div>';
        }).join("");
      });
    });
  }

  /* ══ Módulo: data-fluix-catalogo-detalle ════════════════════════════ */
  function modCatalogoDetalle(){
    var el=document.querySelector("[data-fluix-catalogo-detalle]");if(!el)return;
    var id=new URLSearchParams(window.location.search).get("item");
    if(!id){el.style.display="none";return;}
    el.style.display="";
    db.collection("empresas").doc(EMPRESA).collection("catalogo_web").doc(id).get().then(function(doc){
      if(!doc.exists){el.innerHTML="<p>Elemento no encontrado.</p>";return;}
      var it=doc.data();it.id=doc.id;
      fillFields(el,it);
      injectSeo(it.nombre,it.descripcion,it.imagen_url,{"@context":"https://schema.org","@type":"Product",name:it.nombre||"",description:it.descripcion||"",image:it.imagen_url||""});
    });
  }

  /* ══ Módulo: data-fluix-blog ════════════════════════════════════════ */
  function modBlog(){
    document.querySelectorAll("[data-fluix-blog]").forEach(function(el){
      var limite=parseInt(fcfg(el,"limite","10")),tipo=fcfg(el,"tipo","");
      var tpl=el.querySelector("template[data-fluix-blog-card]")||el.querySelector("template[data-fluix-item]");
      if(!tpl)return;
      db.collection("empresas").doc(EMPRESA).collection("blog").where("publicada","==",true).orderBy("fecha_publicacion","desc").onSnapshot(function(snap){
        el.querySelectorAll("[data-fluix-post-id]").forEach(function(e){e.remove();});
        var n=0;
        snap.forEach(function(doc){
          if(n>=limite)return;
          var b=doc.data();b.id=doc.id;
          if(b.eliminado)return;
          if(tipo&&b.tipo!==tipo)return;
          n++;
          var cl=tpl.content.cloneNode(true),art=cl.firstElementChild;
          art.setAttribute("data-fluix-post-id",doc.id);
          art.querySelectorAll("[data-fluix-campo]").forEach(function(ce){
            var c=ce.getAttribute("data-fluix-campo");
            if(c==="imagen_url"){ce.src=b.imagen_url||"";ce.style.display=b.imagen_url?"":"none";}
            else if(c==="link"){var u=new URL(window.location.href);u.searchParams.set("post",b.slug||doc.id);ce.href=u.toString();}
            else if(c==="fecha"){var ts=b.fecha_publicacion,d=ts&&ts.toDate?ts.toDate():new Date(ts);ce.textContent=d.toLocaleDateString("es-ES");}
            else ce.textContent=b[c]||"";
          });
          el.appendChild(cl);
        });
      });
    });
  }

  /* ══ Módulo: data-fluix-blog-post ═══════════════════════════════════ */
  function modBlogPost(){
    var el=document.querySelector("[data-fluix-blog-post]");if(!el)return;
    var slug=new URLSearchParams(window.location.search).get("post");
    if(!slug)return;
    el.style.display="";
    db.collection("empresas").doc(EMPRESA).collection("blog").where("slug","==",slug).where("publicada","==",true).limit(1).get().then(function(snap){
      if(snap.empty){el.innerHTML="<p>Artículo no encontrado.</p>";return;}
      var b=snap.docs[0].data();
      var todasImgs=[b.imagen_url].concat(b.imagenes||[]).filter(Boolean);
      el.querySelectorAll("[data-fluix-campo]").forEach(function(ce){
        var c=ce.getAttribute("data-fluix-campo");
        if(c==="imagen_url"){
          if(todasImgs.length>1){
            ce.outerHTML=_buildCarousel(todasImgs,"fluix-post-carousel");
          } else {
            ce.src=b.imagen_url||"";ce.style.display=b.imagen_url?"":"none";
          }
        } else if(c==="contenido"){if(window.marked)ce.innerHTML=marked.parse(b.contenido||"");else ce.textContent=b.contenido||"";}
        else if(c==="fecha"){var ts=b.fecha_publicacion,d=ts&&ts.toDate?ts.toDate():new Date(ts);ce.textContent=d.toLocaleDateString("es-ES");}
        else ce.textContent=b[c]||"";
      });
      injectSeo(b.titulo,b.resumen||b.seoMetaDescription,b.imagen_url,{"@context":"https://schema.org","@type":"Article",headline:b.titulo||"",description:b.resumen||"",image:b.imagen_url||"",datePublished:b.fecha_publicacion&&b.fecha_publicacion.toDate?b.fecha_publicacion.toDate().toISOString():"",author:b.autor?{"@type":"Person",name:b.autor}:undefined});
    });
  }

  /* ── Helper: carrusel HTML ligero ────────────────────────────────── */
  function _buildCarousel(imgs,idPrefix){
    var id=idPrefix+Math.random().toString(36).slice(2);
    var slides=imgs.map(function(u,i){return'<div class="fluix-slide" style="min-width:100%;scroll-snap-align:start"><img src="'+u+'" style="width:100%;height:100%;object-fit:cover" loading="lazy"></div>';}).join("");
    var dots=imgs.map(function(_,i){return'<span class="fluix-dot" data-i="'+i+'" style="display:inline-block;width:8px;height:8px;border-radius:50%;background:'+(i===0?"#fff":"rgba(255,255,255,.5)")+';margin:0 3px;cursor:pointer;transition:all .2s"></span>';}).join("");
    setTimeout(function(){
      var wrap=document.getElementById(id);if(!wrap)return;
      var track=wrap.querySelector(".fluix-track");
      var dotEls=wrap.querySelectorAll(".fluix-dot");
      var cur=0;
      function go(n){cur=Math.max(0,Math.min(n,imgs.length-1));track.scrollTo({left:cur*track.offsetWidth,behavior:"smooth"});dotEls.forEach(function(d,i){d.style.background=i===cur?"#fff":"rgba(255,255,255,.5)";d.style.width=i===cur?"18px":"8px";});}
      dotEls.forEach(function(d){d.addEventListener("click",function(){go(parseInt(d.getAttribute("data-i")));});});
      wrap.querySelector(".fluix-prev").addEventListener("click",function(){go(cur-1);});
      wrap.querySelector(".fluix-next").addEventListener("click",function(){go(cur+1);});
    },0);
    return '<div id="'+id+'" style="position:relative;overflow:hidden;border-radius:inherit">'
      +'<div class="fluix-track" style="display:flex;overflow:hidden;scroll-snap-type:x mandatory;height:100%">'+slides+'</div>'
      +'<button class="fluix-prev" style="position:absolute;left:8px;top:50%;transform:translateY(-50%);background:rgba(0,0,0,.4);color:#fff;border:none;border-radius:50%;width:32px;height:32px;cursor:pointer;font-size:16px">‹</button>'
      +'<button class="fluix-next" style="position:absolute;right:8px;top:50%;transform:translateY(-50%);background:rgba(0,0,0,.4);color:#fff;border:none;border-radius:50%;width:32px;height:32px;cursor:pointer;font-size:16px">›</button>'
      +'<div style="position:absolute;bottom:10px;left:0;right:0;text-align:center">'+dots+'</div>'
      +'</div>';
  }

  /* ══ Módulo: data-fluix-contacto ════════════════════════════════════ */
  function modContacto(){
    document.querySelectorAll("[data-fluix-contacto]").forEach(function(el){
      var titulo=fcfg(el,"titulo","Contáctanos");
      var form=el.tagName.toLowerCase()==="form"?el:el.querySelector("form");
      if(!form){
        el.innerHTML='<form><h3>'+titulo+'</h3>'
          +'<input name="nombre" placeholder="Tu nombre" required style="display:block;width:100%;padding:10px;margin:6px 0;border:1px solid #ddd;border-radius:6px">'
          +'<input name="email" type="email" placeholder="Tu email" required style="display:block;width:100%;padding:10px;margin:6px 0;border:1px solid #ddd;border-radius:6px">'
          +'<textarea name="mensaje" rows="4" placeholder="Tu mensaje" required style="display:block;width:100%;padding:10px;margin:6px 0;border:1px solid #ddd;border-radius:6px;resize:vertical"></textarea>'
          +'<button type="submit" style="background:#1976D2;color:#fff;border:none;padding:12px 24px;border-radius:6px;cursor:pointer;font-size:14px">Enviar</button></form>';
        form=el.querySelector("form");
      }
      form.addEventListener("submit",function(e){
        e.preventDefault();
        var fd=new FormData(e.target);
        db.collection("empresas").doc(EMPRESA).collection("contacto_web").add({
          nombre:fd.get("nombre"),email:fd.get("email"),mensaje:fd.get("mensaje"),
          fecha:firebase.firestore.FieldValue.serverTimestamp(),leido:false
        }).then(function(){e.target.innerHTML='<p style="color:green;font-weight:bold">✅ Mensaje enviado.</p>';})
          .catch(function(err){alert("Error: "+err.message);});
      });
    });
  }

  /* ══ Módulo: data-fluix-resenas ═════════════════════════════════════ */
  function modResenas(){
    document.querySelectorAll("[data-fluix-resenas]").forEach(function(el){
      var limite=parseInt(fcfg(el,"limite","5")),tpl=el.querySelector("template[data-fluix-item]");
      db.collection("empresas").doc(EMPRESA).collection("valoraciones").orderBy("fecha_creacion","desc").limit(limite).get().then(function(snap){
        if(snap.empty){el.innerHTML="";return;}
        var suma=0,items=snap.docs.map(function(d){var v=d.data();v.id=d.id;suma+=v.estrellas||v.calificacion||0;return v;});
        if(tpl){
          items.forEach(function(v){
            v.fecha=fmtFecha(v.fecha_creacion);
            v.nombre=v.cliente_nombre||v.nombre||"Cliente";
            v.texto=v.comentario||v.texto||"";
            var cl=tpl.content.cloneNode(true);fillFields(cl.firstElementChild,v);el.appendChild(cl);
          });
          return;
        }
        var media=(suma/items.length).toFixed(1);
        el.innerHTML='<div style="font-size:2rem;font-weight:700">'+media+' ★</div><p>'+items.length+' reseña'+(items.length!==1?'s':"")+'</p>'
          +items.map(function(v){
            return'<div style="padding:1rem 0;border-bottom:1px solid #eee">'
              +'<div>'+"★".repeat(Math.round(v.estrellas||v.calificacion||0))+'</div>'
              +(v.comentario||v.texto?'<p style="margin:.5rem 0">'+(v.comentario||v.texto)+'</p>':"")
              +'<strong>'+(v.cliente_nombre||v.nombre||"Cliente")+'</strong>'
              +'</div>';
          }).join("");
      });
    });
  }

  /* ══ Módulo: data-fluix-seccion ═════════════════════════════════════ */
  function modSecciones(){
    document.querySelectorAll("[data-fluix-seccion]").forEach(function(el){
      var sid=el.getAttribute("data-fluix-seccion"),tpl=el.querySelector("template[data-fluix-plantilla]"),lista=tpl?el.querySelector("[data-fluix-lista]"):null;
      db.collection("empresas").doc(EMPRESA).collection("contenido_web").doc(sid).onSnapshot(function(doc){
        if(!doc.exists)return;
        var d=doc.data();
        el.style.display=d.activa===false?"none":"";
        var items=(d.contenido&&d.contenido.items)||[];
        if(tpl&&lista){
          var cur={};
          lista.querySelectorAll("[data-fluix-item]").forEach(function(e){cur[e.getAttribute("data-fluix-item")]=e;});
          var del=Object.assign({},cur);
          items.forEach(function(item){
            var e=cur[item.id];
            if(!e){var cl=tpl.content.cloneNode(true);e=cl.firstElementChild;e.setAttribute("data-fluix-item",item.id);lista.appendChild(e);}
            delete del[item.id];
            e.style.display=item.disponible===false?"none":"";
            fillFields(e,item);
          });
          Object.values(del).forEach(function(e){e.remove();});
        }
      });
    });
  }

  /* ══ Módulo: data-fluix-push ════════════════════════════════════════ */
  function modPush(){
    document.querySelectorAll("[data-fluix-push]").forEach(function(el){
      if(!("Notification" in window)){el.style.display="none";return;}
      var texto=el.getAttribute("data-fluix-texto")||"Activar notificaciones";
      var btn=document.createElement("button");
      btn.textContent=texto;
      btn.style.cssText="background:#E11D48;color:#fff;border:none;padding:12px 24px;border-radius:8px;cursor:pointer;font-size:14px;font-weight:600";
      function marcarActivo(){btn.textContent="✓ Notificaciones activadas";btn.disabled=true;btn.style.background="#10B981";}
      function marcarBloqueado(){btn.textContent="Notificaciones bloqueadas";btn.disabled=true;btn.style.background="#94A3B8";}
      function suscribir(){
        db.collection("empresas").doc(EMPRESA).collection("config_web").doc("push_config").get().then(function(doc){
          var vapidKey=doc.exists&&doc.data()?doc.data().vapid_key:null;
          if(!vapidKey||!firebase.messaging){return;}
          navigator.serviceWorker.ready.then(function(sw){
            firebase.messaging().getToken({vapidKey:vapidKey,serviceWorkerRegistration:sw}).then(function(token){
              if(!token)return;
              db.collection("empresas").doc(EMPRESA).collection("suscriptores_web").doc(token).set({token:token,fecha:firebase.firestore.FieldValue.serverTimestamp(),url:window.location.href,activo:true},{merge:true});
            }).catch(function(){});
          }).catch(function(){});
        }).catch(function(){});
      }
      if(Notification.permission==="granted"){marcarActivo();suscribir();}
      else if(Notification.permission==="denied"){marcarBloqueado();}
      else{btn.addEventListener("click",function(){Notification.requestPermission().then(function(p){if(p==="granted"){marcarActivo();suscribir();}else marcarBloqueado();});});}
      el.innerHTML="";el.appendChild(btn);
    });
  }

  /* ══ Módulo: data-fluix-seleccion-nazari ═══════════════════════════ */
  function modSeleccionNazari(){
    document.querySelectorAll("[data-fluix-seleccion-nazari]").forEach(function(el){
      var limite=parseInt(fcfg(el,"limite","50"));
      var soloLibroMes=el.getAttribute("data-fluix-libro-del-mes")==="true";
      var tpl=el.querySelector("template[data-fluix-item]");
      db.collection("empresas").doc(EMPRESA).collection("seleccion_nazari")
        .where("activo","==",true)
        .orderBy("orden")
        .onSnapshot(function(snap){
          var items=[];
          snap.forEach(function(doc){
            var d=doc.data();d.id=doc.id;
            if(soloLibroMes&&!d.es_libro_del_mes)return;
            items.push(d);
          });
          items=items.slice(0,limite);
          if(!items.length){el.innerHTML="";return;}
          if(tpl){
            renderTpl(el,tpl,items.map(function(it){
              return{id:it.id,titulo:it.titulo,autor:it.autor,imagen_url:it.imagen,
                nota_editorial:it.nota_editorial,es_libro_del_mes:it.es_libro_del_mes,
                slug:it.slug};
            }));
            return;
          }
          el.innerHTML=items.map(function(it){
            var esLibroMes=it.es_libro_del_mes;
            return'<div class="fluix-naz-item" data-fluix-id="'+it.id+'">'
              +(it.imagen?'<div class="fluix-naz-cover" style="position:relative">'
                +(esLibroMes?'<span class="fluix-naz-badge">Libro del mes</span>':"")
                +'<img class="fluix-naz-img" src="'+it.imagen+'" alt="'+it.titulo+'" loading="lazy">'
                +'</div>':"")
              +'<div class="fluix-naz-body">'
              +'<h3 class="fluix-naz-titulo">'+it.titulo+'</h3>'
              +(it.autor?'<span class="fluix-naz-autor">'+it.autor+'</span>':"")
              +(it.nota_editorial?'<p class="fluix-naz-nota">'+it.nota_editorial+'</p>':"")
              +'</div></div>';
          }).join("");
        });
    });
  }

  /* ══ Bootstrap: detectar módulos y arrancar ═════════════════════════ */
  auth.signInAnonymously().then(function(){
    var mods=[];
    function detect(sel,fn,id){if(document.querySelector(sel)){fn();mods.push(id);}}
    detect("[data-fluix-agenda]",               modAgenda,            "agenda");
    detect("[data-fluix-agenda-detalle]",       modAgendaDetalle,     "agenda-detalle");
    detect("[data-fluix-catalogo]",             modCatalogo,          "catalogo");
    detect("[data-fluix-catalogo-detalle]",     modCatalogoDetalle,   "catalogo-detalle");
    detect("[data-fluix-blog]",                 modBlog,              "blog");
    detect("[data-fluix-blog-post]",            modBlogPost,          "blog-post");
    detect("[data-fluix-contacto]",             modContacto,          "contacto");
    detect("[data-fluix-resenas]",              modResenas,           "resenas");
    detect("[data-fluix-seccion]",              modSecciones,         "secciones");
    detect("[data-fluix-push]",                 modPush,              "push");
    detect("[data-fluix-seleccion-nazari]",     modSeleccionNazari,   "seleccion-nazari");
    // Reportar módulos detectados en Firestore
    if(mods.length){
      db.collection("empresas").doc(EMPRESA).collection("config_web").doc("sdk_status").set({
        modulos:mods,url:window.location.href,ts:firebase.firestore.FieldValue.serverTimestamp()
      },{merge:true}).catch(function(){});
    }
    console.log("%cFluix Web SDK%c activo · "+mods.length+" módulo(s): ["+mods.join(", ")+"]","color:#1976D2;font-weight:bold","color:inherit");
  }).catch(function(e){console.error("Fluix SDK: "+e.message);});

})();
''';


  // ═══════════════════════════════════════════════════════════════════════════
  // SDK_STATUS — módulos detectados en la web
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<Map<String, dynamic>> obtenerSdkStatus(String empresaId) {
    return _firestore
        .collection('empresas').doc(empresaId)
        .collection('config_web').doc('sdk_status')
        .snapshots()
        .map((doc) => doc.exists ? doc.data()! : <String, dynamic>{});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BLOG / NOTICIAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve los dos bloques HTML que el admin pega UNA VEZ en su web.
  /// El script (generarScriptHostinger) los detecta y rellena desde Firestore.
  Map<String, String> generarPlantillaBlog() {
    const listado = '''<!-- ── BLOQUE 1: Lista de artículos del blog ──────────── -->
<!-- Pega donde quieras mostrar las tarjetas de posts.      -->
<!-- Diseña .blog-card con tu propio CSS.                   -->
<!-- Opcional: añade marked.js en el <head> para Markdown   -->
<!--   <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script> -->
<div data-fluix-blog>
  <template data-fluix-blog-card>
    <article class="blog-card">
      <a data-fluix-campo="link">
        <img data-fluix-campo="imagen_url" alt="">
        <div class="blog-card-body">
          <span data-fluix-campo="categoria" class="badge"></span>
          <h3 data-fluix-campo="titulo"></h3>
          <p data-fluix-campo="resumen"></p>
          <div class="blog-card-meta">
            <span data-fluix-campo="autor"></span>
            <span data-fluix-campo="fecha"></span>
          </div>
        </div>
      </a>
    </article>
  </template>
</div>''';

    const articulo = '''<!-- ── BLOQUE 2: Artículo completo ───────────────────── -->
<!-- Pega en la misma página o en una página de detalle.    -->
<!-- Se muestra cuando la URL contiene ?post=slug-del-post  -->
<div data-fluix-blog-post style="display:none">
  <img data-fluix-campo="imagen_url" class="post-hero" alt="">
  <span data-fluix-campo="categoria" class="badge"></span>
  <h1 data-fluix-campo="titulo"></h1>
  <div class="post-meta">
    <span data-fluix-campo="autor"></span>
    <span data-fluix-campo="fecha"></span>
  </div>
  <div data-fluix-campo="contenido" class="post-content"></div>
  <div data-fluix-campo="etiquetas" class="post-tags"></div>
</div>''';

    return {'listado': listado, 'articulo': articulo};
  }

  CollectionReference<Map<String, dynamic>> _blogCol(String empresaId) =>
      _firestore.collection('empresas').doc(empresaId).collection('blog');

  CollectionReference<Map<String, dynamic>> _categoriasCol(String empresaId) =>
      _firestore.collection('empresas').doc(empresaId).collection('blog_categorias');

  /// Stream de entradas NO eliminadas, filtrado en cliente para evitar índice compuesto
  Stream<List<EntradaBlog>> obtenerBlog(String empresaId) {
    return _blogCol(empresaId)
        .where('eliminado', isEqualTo: false)
        .orderBy('fecha_publicacion', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs
            .map((d) => EntradaBlog.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Stream paginado filtrado por tipo — requiere índice compuesto tipo+fecha_publicacion
  Stream<List<EntradaBlog>> obtenerBlogPorTipo(String empresaId, String tipo, {int limite = 50}) {
    return _blogCol(empresaId)
        .where('tipo', isEqualTo: tipo)
        .orderBy('fecha_publicacion', descending: true)
        .limit(limite)
        .snapshots()
        .map((s) => s.docs
            .map((d) => EntradaBlog.fromMap({...d.data(), 'id': d.id}))
            .where((e) => !e.eliminado)
            .toList());
  }

  /// Stream filtrado por seccion_id (secciones dinámicas data-fluix)
  Stream<List<EntradaBlog>> obtenerBlogSeccion(String empresaId, String seccionId) {
    return _blogCol(empresaId)
        .where('seccion_id', isEqualTo: seccionId)
        .where('eliminado', isEqualTo: false)
        .orderBy('fecha_publicacion', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs
            .map((d) => EntradaBlog.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> guardarEntradaBlog(String empresaId, EntradaBlog entrada) async {
    final data = entrada.toMap();
    data.remove('id');
    if (entrada.id.isEmpty) {
      data['fecha_creacion'] = FieldValue.serverTimestamp();
    } else {
      // Antes de sobrescribir, guardar la versión anterior (máximo 10 versiones)
      await _guardarVersionAnterior(empresaId, entrada.id);
    }
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    data['fecha_publicacion'] = Timestamp.fromDate(entrada.fechaPublicacion);
    await _blogCol(empresaId)
        .doc(entrada.id.isEmpty ? null : entrada.id)
        .set(data, SetOptions(merge: true));
  }

  /// Actualiza campos adicionales de una entrada de blog (ej: contenido_html pre-renderizado).
  Future<void> actualizarCamposExtra(
      String empresaId, String entradaId, Map<String, dynamic> campos) async {
    if (entradaId.isEmpty) return;
    await _blogCol(empresaId).doc(entradaId).update({
      ...campos,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Guarda una snapshot de la versión actual antes de sobrescribir.
  Future<void> _guardarVersionAnterior(String empresaId, String entradaId) async {
    try {
      final doc = await _blogCol(empresaId).doc(entradaId).get();
      if (!doc.exists) return;
      final versionesCol = _blogCol(empresaId).doc(entradaId).collection('versiones');
      // Guardar version snapshot
      await versionesCol.add({
        ...doc.data()!,
        'guardada_en': FieldValue.serverTimestamp(),
      });
      // Mantener solo las últimas 10 versiones (borrar excedente)
      final allVers = await versionesCol.orderBy('guardada_en', descending: true).get();
      if (allVers.docs.length > 10) {
        for (final d in allVers.docs.skip(10)) await d.reference.delete();
      }
    } catch (_) {
      // No bloquear el guardado si falla el historial
    }
  }

  /// Obtiene el historial de versiones de una entrada.
  Future<List<Map<String, dynamic>>> obtenerVersiones(String empresaId, String entradaId) async {
    final snap = await _blogCol(empresaId)
        .doc(entradaId)
        .collection('versiones')
        .orderBy('guardada_en', descending: true)
        .limit(10)
        .get();
    return snap.docs.map((d) => {...d.data(), 'version_id': d.id}).toList();
  }

  /// Restaura una versión anterior como contenido actual.
  Future<void> restaurarVersion(String empresaId, String entradaId, Map<String, dynamic> versionData) async {
    final data = Map<String, dynamic>.from(versionData)
      ..remove('version_id')
      ..remove('guardada_en');
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    await _blogCol(empresaId).doc(entradaId).set(data, SetOptions(merge: true));
  }

  Future<void> crearEntradaBlogEjemplo(String empresaId) async {
    final entrada = EntradaBlog(
      id: '',
      titulo: '¡Bienvenidos a nuestro blog!',
      slug: 'bienvenidos-a-nuestro-blog',
      resumen: 'Este es nuestro primer artículo. Aquí compartiremos novedades, consejos y todo lo relacionado con nuestro negocio.',
      contenido: '# ¡Bienvenidos a nuestro blog!\n\n'
          'Estamos muy emocionados de lanzar este espacio donde compartiremos todo lo relacionado con nuestro negocio.\n\n'
          '## ¿Qué encontrarás aquí?\n\n'
          '- **Novedades**: Las últimas noticias sobre nuestros productos y servicios.\n'
          '- **Consejos**: Tips y trucos para sacar el máximo partido a lo que ofrecemos.\n'
          '- **Historias**: Casos de éxito y testimonios de nuestros clientes.\n\n'
          '## Sobre nosotros\n\n'
          'Llevamos años trabajando con pasión para ofrecer el mejor servicio posible. '
          'Este blog es una extensión de ese compromiso: queremos estar más cerca de ti '
          'y compartir lo que nos mueve cada día.\n\n'
          '---\n\n'
          '*¡No olvides suscribirte para no perderte ninguna actualización!*',
      estado: EstadoBlog.publicado,
      fechaPublicacion: DateTime.now(),
      autor: 'Equipo',
      etiquetas: ['bienvenida', 'novedades'],
      destacado: true,
      seoMetaTitle: 'Bienvenidos a nuestro blog — Noticias y consejos',
      seoMetaDescription: 'Descubre las últimas novedades, consejos y noticias de nuestro negocio en nuestro blog oficial.',
      seoKeywords: ['blog', 'novedades', 'noticias'],
    );
    await guardarEntradaBlog(empresaId, entrada);
  }

  /// Soft-delete: marca eliminado=true en lugar de borrar físicamente
  Future<void> eliminarEntradaBlog(String empresaId, String entradaId) async {
    await _blogCol(empresaId).doc(entradaId).update({
      'eliminado': true,
      'fecha_eliminacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarCampoEntradaBlog(
      String empresaId, String entradaId, Map<String, dynamic> campos) async {
    await _blogCol(empresaId).doc(entradaId).update(campos);
  }

  Future<void> togglePublicarBlog(
      String empresaId, String entradaId, bool publicar) async {
    await _blogCol(empresaId).doc(entradaId).update({
      'estado': publicar ? 'publicado' : 'borrador',
      'publicada': publicar,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleDestacadoBlog(
      String empresaId, String entradaId, bool destacado) async {
    await _blogCol(empresaId).doc(entradaId).update({
      'destacado': destacado,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Aplica una operación en lote a una lista de entradas
  Future<void> accionEnLote({
    required String empresaId,
    required List<String> ids,
    required String accion, // 'publicar' | 'borrador' | 'eliminar' | 'categoria:{id}'
  }) async {
    final batches = <WriteBatch>[];
    var batch = _firestore.batch();
    var ops = 0;
    for (final id in ids) {
      final ref = _blogCol(empresaId).doc(id);
      if (accion == 'publicar') {
        batch.update(ref, {
          'estado': 'publicado', 'publicada': true,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
      } else if (accion == 'borrador') {
        batch.update(ref, {
          'estado': 'borrador', 'publicada': false,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
      } else if (accion == 'eliminar') {
        batch.update(ref, {
          'eliminado': true,
          'fecha_eliminacion': FieldValue.serverTimestamp(),
        });
      } else if (accion.startsWith('categoria:')) {
        batch.update(ref, {
          'categoria_id': accion.substring(10),
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
      }
      ops++;
      if (ops == 500) {
        batches.add(batch);
        batch = _firestore.batch();
        ops = 0;
      }
    }
    if (ops > 0) batches.add(batch);
    for (final b in batches) {
      await b.commit();
    }
  }

  /// Duplica una entrada: nuevo slug con sufijo -copia, estado borrador
  Future<void> duplicarEntradaBlog(String empresaId, EntradaBlog original) async {
    final baseSlug = original.slug.isEmpty
        ? _slugFromTitle(original.titulo)
        : original.slug;
    final newSlug = await _slugUnico(empresaId, baseSlug);
    final data = original.toMap();
    data.remove('id');
    data['titulo'] = '${original.titulo} (copia)';
    data['slug'] = newSlug;
    data['estado'] = 'borrador';
    data['publicada'] = false;
    data['eliminado'] = false;
    data['fecha_creacion'] = FieldValue.serverTimestamp();
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    data['fecha_publicacion'] = Timestamp.fromDate(DateTime.now());
    data['visitas'] = 0;
    await _blogCol(empresaId).add(data);
  }

  Future<bool> slugDisponible(
      String empresaId, String slug, {String? excludeId}) async {
    final snap = await _blogCol(empresaId)
        .where('slug', isEqualTo: slug)
        .limit(5)
        .get();
    final docs = snap.docs.where((d) {
      if (d.id == excludeId) return false;
      return d.data()['eliminado'] != true;
    }).toList();
    return docs.isEmpty;
  }

  Future<String> _slugUnico(String empresaId, String base) async {
    if (await slugDisponible(empresaId, base)) return base;
    var i = 2;
    while (true) {
      final candidate = '$base-copia${i > 2 ? '-$i' : ''}';
      if (await slugDisponible(empresaId, candidate)) return candidate;
      i++;
    }
  }

  String slugFromTituloPublic(String titulo) => _slugFromTitle(titulo);

  String _slugFromTitle(String titulo) {
    return titulo
        .toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  // ── Eventos ─────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _eventosCol(String empresaId) =>
      _firestore.collection('empresas').doc(empresaId).collection('eventos');

  Stream<List<EventoWeb>> obtenerEventos(String empresaId) {
    return _eventosCol(empresaId)
        .where('eliminado', isEqualTo: false)
        .orderBy('fecha')
        .limit(500)
        .snapshots()
        .map((s) => s.docs
            .map((d) => EventoWeb.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> guardarEvento(String empresaId, EventoWeb evento) async {
    final data = evento.toMap();
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    if (evento.id.isEmpty) data['fecha_creacion'] = FieldValue.serverTimestamp();
    await _eventosCol(empresaId)
        .doc(evento.id.isEmpty ? null : evento.id)
        .set(data, SetOptions(merge: true));
  }

  Future<void> eliminarEvento(String empresaId, String eventoId) async {
    await _eventosCol(empresaId).doc(eventoId).update({'eliminado': true});
  }

  Future<void> toggleActivoEvento(String empresaId, String eventoId, bool activo) async {
    await _eventosCol(empresaId).doc(eventoId).update({
      'activo': activo,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> crearEventosEjemplo(String empresaId) async {
    final ahora = DateTime.now();
    final eventos = [
      EventoWeb(
        id: '', titulo: 'Presentación: La Granada Invisible',
        descripcion: 'Carmen Ruiz Lozano presenta su nueva novela con lectura de fragmentos y firma de ejemplares.',
        fecha: ahora.add(const Duration(days: 14)),
        lugar: 'Librería Picasso, Granada',
        tipo: TipoEvento.presentacion,
        hora: '19:00 h',
        ciudad: 'Granada',
        activo: true,
      ),
      EventoWeb(
        id: '', titulo: 'Feria del Libro de Granada 2026',
        descripcion: 'Editorial Nazarí estará presente con caseta propia. Descuentos y firmas durante todos los días.',
        fecha: ahora.add(const Duration(days: 42)),
        lugar: 'Paseo del Salón',
        tipo: TipoEvento.feria,
        hora: '10:00 – 21:30 h',
        ciudad: 'Granada',
        activo: true,
      ),
      EventoWeb(
        id: '', titulo: 'Taller de Escritura Creativa',
        descripcion: 'Taller intensivo de dos jornadas sobre narrativa andaluza contemporánea. Plazas limitadas.',
        fecha: ahora.add(const Duration(days: 21)),
        lugar: 'Casa de los Tiros, Granada',
        tipo: TipoEvento.taller,
        hora: '10:00 – 14:00 h',
        ciudad: 'Granada',
        activo: true,
      ),
    ];
    for (final ev in eventos) {
      await guardarEvento(empresaId, ev);
    }
  }

  // ── Importación masiva — datos web Editorial Nazarí ─────────────────────────

  /// Retorna true si ya hay datos importados de la web.
  Future<bool> hayDatosImportadosNazari(String empresaId) async {
    final snap = await _eventosCol(empresaId)
        .where('_importado', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> importarEventosNazariDesdeWeb(String empresaId) async {
    final eventos = _eventosNazariData();
    final col = _eventosCol(empresaId);
    var batch = _firestore.batch();
    var cnt = 0;
    for (final ev in eventos) {
      final doc = col.doc(ev['id'] as String);
      batch.set(doc, {
        'titulo':      ev['titulo'],
        'subtitulo':   ev['subtitulo'] ?? '',
        'descripcion': ev['descripcion'] ?? '',
        'fecha':       Timestamp.fromDate(DateTime.parse('${ev['fecha']}T12:00:00')),
        'lugar':       ev['lugar'] ?? '',
        'ciudad':      ev['ciudad'] ?? '',
        'hora':        ev['hora'] ?? '',
        'tipo':        ev['tipo'],
        'activo':      true,
        'eliminado':   false,
        '_importado':  true,
        '_fuente':     'web-nazari',
        if ((ev['autor_nombre'] as String?)?.isNotEmpty == true)
          'autor_nombre': ev['autor_nombre'],
        'fecha_creacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      cnt++;
      if (cnt == 400) {
        await batch.commit();
        batch = _firestore.batch();
        cnt = 0;
      }
    }
    if (cnt > 0) await batch.commit();
  }

  Future<void> importarBlogNazariDesdeWeb(String empresaId) async {
    final entradas = _blogNazariData();
    final col = _blogCol(empresaId);
    var batch = _firestore.batch();
    var cnt = 0;
    for (final p in entradas) {
      final doc = col.doc(p['id'] as String);
      batch.set(doc, {
        'titulo':            p['titulo'],
        'slug':              p['slug'],
        'resumen':           p['resumen'] ?? '',
        'contenido':         '',
        'autor':             p['autor'] ?? '',
        'categoria_id':      p['tipo'] == 'entrevista' ? 'Entrevistas' : 'Noticias',
        'tipo':              p['tipo'],
        'estado':            'publicado',
        'publicada':         true,
        'fecha_publicacion': Timestamp.fromDate(DateTime.parse('${p['fecha']}T12:00:00')),
        'etiquetas':         <String>[],
        'imagenes':          <String>[],
        'destacado':         false,
        'visitas':           0,
        'eliminado':         false,
        'seo':               {'meta_title': '', 'meta_description': '', 'keywords': <String>[]},
        if ((p['imagen_url'] as String?)?.isNotEmpty == true) 'imagen_url': p['imagen_url'],
        if ((p['url_externa'] as String?)?.isNotEmpty == true) 'url_externa': p['url_externa'],
        '_importado':  true,
        '_fuente':     'web-nazari',
        'fecha_creacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      cnt++;
      if (cnt == 400) {
        await batch.commit();
        batch = _firestore.batch();
        cnt = 0;
      }
    }
    if (cnt > 0) await batch.commit();

    // FIFO: mantener máximo 150 entradas por tipo (noticia / entrevista)
    await _recortarBlogPorTipo(col, 'noticia', 150);
    await _recortarBlogPorTipo(col, 'entrevista', 150);
  }

  Future<void> _recortarBlogPorTipo(
      CollectionReference<Map<String, dynamic>> col,
      String tipo,
      int maximo) async {
    final snap = await col
        .orderBy('fecha_publicacion', descending: true)
        .get();
    final deTipo = snap.docs
        .where((d) => d.data()['tipo'] == tipo && d.data()['eliminado'] != true)
        .toList();
    if (deTipo.length <= maximo) return;
    final sobran = deTipo.sublist(maximo); // los más antiguos
    var delBatch = _firestore.batch();
    var delCnt = 0;
    for (final d in sobran) {
      delBatch.delete(d.reference);
      delCnt++;
      if (delCnt == 400) {
        await delBatch.commit();
        delBatch = _firestore.batch();
        delCnt = 0;
      }
    }
    if (delCnt > 0) await delBatch.commit();
  }

  // ── Datos estáticos de la web Nazarí ─────────────────────────────────────────

  static List<Map<String, dynamic>> _eventosNazariData() => [
    {'id':'ev-001','tipo':'Presentación','titulo':"'El canto triste del cuervo' en la Feria del Libro de Jaén",'subtitulo':'José Prados Osuna firma ejemplares','fecha':'2026-05-16','hora':'18:30 – 20:25 h','lugar':'Feria del Libro de Jaén, c/ Roldán y Marín','ciudad':'Jaén','descripcion':'José Prados Osuna firma ejemplares de su última novela El canto triste del cuervo en la Feria del Libro de Jaén.'},
    {'id':'ev-002','tipo':'Presentación','titulo':"'Intramuros' en Sevilla",'subtitulo':'José Piñero Mira presenta su colección de relatos','fecha':'2026-05-16','hora':'20:30 – 22:00 h','lugar':'Sala Griot, c/ Factores 18','ciudad':'Sevilla','descripcion':'Presentación de Intramuros, colección de relatos de José Piñero Mira.'},
    {'id':'ev-003','tipo':'Presentación','titulo':"'Noviembre' en Salar",'subtitulo':'Juan de Dios Villanueva Roa presenta su poemario','fecha':'2026-05-22','hora':'19:30 – 21:00 h','lugar':'Salón de Plenos del Ayuntamiento de Salar','ciudad':'Salar (Granada)','descripcion':'Presentación de Noviembre, último poemario de Juan de Dios Villanueva Roa.'},
    {'id':'ev-004','tipo':'Presentación','titulo':"'Las doce cosechas' en Algeciras",'subtitulo':'Maite Cuesta presenta su nueva novela','fecha':'2026-05-22','hora':'20:00 – 21:30 h','lugar':'Casa Regional de Ceuta en Algeciras, c/ José Luis Cano 1','ciudad':'Algeciras (Cádiz)','descripcion':'Presentación de Las doce cosechas, nueva novela de Maite Cuesta.'},
    {'id':'ev-005','tipo':'Presentación','titulo':"'Caminando con tus ojos' en Atarfe",'subtitulo':'Irene Bosch Blanco presenta su primera novela','fecha':'2026-05-27','hora':'19:30 – 21:00 h','lugar':'Centro Cultural Medina Elvira, Avda. de la Diputación S/N','ciudad':'Atarfe (Granada)','descripcion':'Presentación de Caminando con tus ojos, ópera prima de Irene Bosch Blanco.'},
    {'id':'ev-006','tipo':'Presentación','titulo':"'La gestión del silencio' en Gijón",'subtitulo':'Manuel Bayona presenta sus artículos sobre gestión sanitaria','fecha':'2026-05-28','hora':'19:00 – 20:30 h','lugar':'Salón de actos de la Escuela de Comercio, c/ Francisco Tomás y Valiente 1','ciudad':'Gijón (Asturias)','descripcion':'Presentación de La gestión del silencio de Manuel Bayona.'},
    {'id':'ev-007','tipo':'Presentación','titulo':"'Creo que te quiero' en la Feria del Libro de Pegalajar",'subtitulo':'Dulce López Rodríguez firma ejemplares','fecha':'2026-05-30','hora':'11:00 – 14:00 y 16:00 – 19:30 h','lugar':'Feria del Libro de Pegalajar, Parque de La Charca','ciudad':'Pegalajar (Jaén)','descripcion':'Dulce López Rodríguez firma ejemplares de Creo que te quiero en Pegalajar.'},
    {'id':'ev-008','tipo':'Presentación','titulo':"'La habitación 320' en Barcelona",'subtitulo':'El Grupo Bojador presenta su colección de relatos','fecha':'2026-05-31','hora':'12:00 – 14:00 h','lugar':'Café de la Ópera, La Rambla 74','ciudad':'Barcelona','descripcion':'El Grupo Bojador presenta La habitación 320 en el Café de la Ópera de Barcelona.'},
    {'id':'ev-009','tipo':'Presentación','titulo':"'La gestión del silencio' en Oviedo",'subtitulo':'Manuel Bayona en el Aula Clarín de la Universidad de Oviedo','fecha':'2026-06-01','hora':'19:00 – 20:30 h','lugar':'Aula Clarín, edificio histórico Universidad, c/ San Francisco','ciudad':'Oviedo (Asturias)','descripcion':'Presentación de La gestión del silencio en el Aula Clarín de la Universidad de Oviedo.'},
    {'id':'ev-010','tipo':'Presentación','titulo':"'La gestión del silencio' en Madrid",'subtitulo':'Manuel Bayona ante directivos del Ministerio de Sanidad','fecha':'2026-06-09','hora':'13:00 – 14:30 h','lugar':'Plató de TV de Redacción Médica, c/ Rufino González 23 BIS','ciudad':'Madrid','descripcion':'Presentación de La gestión del silencio con el Director General de Ordenación Profesional del Ministerio de Sanidad.'},
    {'id':'ev-011','tipo':'Presentación','titulo':"'Espejos' en Madrid",'subtitulo':'Óscar Vázquez Mínguez presenta su poemario de 52 poemas','fecha':'2026-06-09','hora':'19:00 – 20:30 h','lugar':'Biblioteca Pública Manuel Vázquez Montalbán, c/ Francos Rodríguez 67','ciudad':'Madrid','descripcion':'Óscar Vázquez Mínguez presenta Espejos, acompañado por Carolina Illescas y el editor Alejandro Santiago.'},
    {'id':'ev-012','tipo':'Presentación','titulo':"Premio Volantones 2026 de Microrrelatos en Granada",'subtitulo':'Concesión del premio de la Asociación de Amigos de la Base Aérea de Armilla','fecha':'2026-06-05','hora':'19:00 – 20:30 h','lugar':'Sala Val del Omar, Biblioteca de Andalucía, c/ Profesor Sainz Cantero 6','ciudad':'Granada','descripcion':'Presentación del Premio Volantones 2026 de Microrrelatos y concesión del galardón.'},
    {'id':'ev-013','tipo':'Presentación','titulo':"'Trampantojos' en la Feria del Libro de Madrid",'subtitulo':'Ana Grandal firma su colección de 75 microrrelatos','fecha':'2026-06-10','hora':'17:30 – 18:00 h','lugar':'Caseta 170 de Sin Tarima Libros, Feria del Libro de Madrid','ciudad':'Madrid','descripcion':'Ana Grandal firma ejemplares de Trampantojos en la Feria del Libro de Madrid.'},
    {'id':'ev-014','tipo':'Presentación','titulo':"'Destilación' en Granada",'subtitulo':'Paula R. Bouzas presenta su poemario en el Colegio de Farmacéuticos','fecha':'2026-06-17','hora':'20:00 – 21:30 h','lugar':'Colegio Oficial de Farmacéuticos de Granada, c/ San Jerónimo 16','ciudad':'Granada','descripcion':'Presentación de Destilación, poemario de Paula R. Bouzas.'},
    {'id':'ev-015','tipo':'Presentación','titulo':"'Al tercer día' en Isla Cristina",'subtitulo':'David Macías Gómez presenta su novela histórica','fecha':'2026-07-13','hora':'21:00 – 22:30 h','lugar':'CIT Garum, Muelle Marina S/N','ciudad':'Isla Cristina (Huelva)','descripcion':'Presentación de Al tercer día, nueva novela de David Macías Gómez.'},
    {'id':'ev-016','tipo':'Presentación','titulo':"Conferencia «Cátaros en el Pirineo catalán»",'subtitulo':'Jesús Ávila Granados, autor de El holocausto cátaro','fecha':'2026-08-08','hora':'18:00 – 19:30 h','lugar':"Casals de Jubilats de Tírvia, Carrer de la Plaça de la Monja 1",'ciudad':"Tírvia (Lleida)",'descripcion':"Conferencia «Cátaros en el Pirineo catalán» a cargo de Jesús Ávila Granados."},
    {'id':'ev-017','tipo':'Presentación','titulo':"'Al tercer día' en la Feria del Libro de Alájar",'subtitulo':'David Macías Gómez presenta su novela histórica','fecha':'2026-08-12','hora':'20:00 – 21:30 h','lugar':"Biblioteca Pública Municipal «Arias Montano» (Centro Multifuncional)",'ciudad':'Alájar (Huelva)','descripcion':'Presentación de Al tercer día en la Feria del Libro de Alájar.'},
    {'id':'ev-018','tipo':'Presentación','titulo':"'La gestión del silencio' en Candás",'subtitulo':'Manuel Bayona presenta su obra sobre gestión sanitaria','fecha':'2026-09-17','hora':'19:00 – 20:30 h','lugar':"Biblioteca Pública Municipal «Carlos González Posada», Sala Benito d'Auxa",'ciudad':'Candás (Asturias)','descripcion':'Presentación de La gestión del silencio de Manuel Bayona en Candás.','autor_nombre':'Manuel Bayona García'},
    {'id':'ev-019','tipo':'Presentación','titulo':"'Destilación' en Ribadavia",'subtitulo':'Paula R. Bouzas presenta su poemario','fecha':'2026-08-14','hora':'','lugar':'Ribadavia','ciudad':'Ribadavia (Ourense)','descripcion':'Presentación de Destilación, poemario de Paula R. Bouzas, en Ribadavia.'},
    {'id':'ev-020','tipo':'Presentación','titulo':"'El mundial que España no ganó' en Torrelavega",'subtitulo':'Presentación en Torrelavega','fecha':'2026-08-14','hora':'','lugar':'Torrelavega','ciudad':'Torrelavega (Cantabria)','descripcion':'Presentación de El mundial que España no ganó en Torrelavega.'},
    {'id':'ev-021','tipo':'Presentación','titulo':"'El mundial que España no ganó' en Granada",'subtitulo':'Javier Ruiz Barquín presenta su diario íntimo','fecha':'2026-09-16','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Presentación de El mundial que España no ganó en Granada.','autor_nombre':'Javier Ruiz Barquín'},
    {'id':'ev-022','tipo':'Presentación','titulo':"'La habitación 320' en Granada",'subtitulo':'El Grupo Bojador presenta su colección de relatos','fecha':'2026-09-24','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'El Grupo Bojador presenta La habitación 320 en Granada.'},
    {'id':'ev-023','tipo':'Presentación','titulo':"'El jardín de Irene' en Granada",'subtitulo':'Presentación en el barrio de La Chana, Granada','fecha':'2026-10-23','hora':'','lugar':'La Chana, Granada','ciudad':'Granada','descripcion':'Presentación de El jardín de Irene en el barrio de La Chana de Granada.'},
    {'id':'ev-024','tipo':'Presentación','titulo':"'Mujeres y guerra' en Granada",'subtitulo':'Presentación en Granada','fecha':'2026-05-01','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Presentación del libro Mujeres y guerra en Granada.'},
    {'id':'ev-025','tipo':'Presentación','titulo':"'Huyendo a Granada' — Ruta literaria",'subtitulo':'Ruta literaria por la ciudad de Granada','fecha':'2026-05-03','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Ruta literaria por los escenarios de Huyendo a Granada, con Victoria Eugenia Muñoz.'},
    {'id':'ev-026','tipo':'Presentación','titulo':"'Maneras de estar tumbada' en Granada",'subtitulo':'Presentación en Granada','fecha':'2026-05-05','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Presentación del libro de Mar Navarro G.'},
    {'id':'ev-027','tipo':'Presentación','titulo':"'Al tercer día' en Granada",'subtitulo':'David Macías Gómez presenta su novela histórica','fecha':'2026-05-06','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Presentación de Al tercer día, novela histórica de David Macías Gómez, en Granada.'},
    {'id':'ev-028','tipo':'Presentación','titulo':"'Cómodamente adormecido' en Granada",'subtitulo':'Juan Quero presenta su novela','fecha':'2026-05-10','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Presentación de Cómodamente adormecido de Juan Quero en Granada.'},
    {'id':'ev-029','tipo':'Presentación','titulo':"'Al tercer día' — segunda presentación",'subtitulo':'David Macías Gómez presenta su novela','fecha':'2026-05-11','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Segunda presentación de Al tercer día de David Macías Gómez.'},
    {'id':'ev-030','tipo':'Presentación','titulo':"'Los ríos nunca miran atrás' en Granada",'subtitulo':'José Luis Monroy Antón presenta su novela','fecha':'2026-05-14','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Presentación de Los ríos nunca miran atrás en Granada.'},
    {'id':'ev-031','tipo':'Presentación','titulo':"'Nostalgias' en Granada",'subtitulo':'Susana Collado Vázquez presenta su poemario','fecha':'2026-05-14','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Presentación del poemario Nostalgias de Susana Collado Vázquez en Granada.'},
    {'id':'ev-032','tipo':'Presentación','titulo':"'Caminando con tus ojos' en el Café Literario de Atarfe",'subtitulo':'Irene Bosch Blanco presenta su novela','fecha':'2026-04-22','hora':'','lugar':'Café Literario de Atarfe','ciudad':'Atarfe (Granada)','descripcion':'Encuentro con autores durante la semana del libro en Atarfe.'},
    {'id':'ev-033','tipo':'Presentación','titulo':"'Caminando con tus ojos' en La Ciutadella",'subtitulo':'Irene Bosch Blanco presenta su novela en Menorca','fecha':'2026-04-17','hora':'','lugar':'Antigua farmacia Llabrés','ciudad':'Ciutadella (Menorca)','descripcion':'Irene Bosch Blanco presentó su novela en la antigua farmacia Llabrés de Ciutadella.'},
    {'id':'ev-034','tipo':'Presentación','titulo':"'Caminando con tus ojos' en Ferrerías",'subtitulo':'Presentación en la Biblioteca de Ferrerías','fecha':'2026-04-16','hora':'','lugar':'Biblioteca Municipal de Ferrerías','ciudad':'Ferrerías (Menorca)','descripcion':'Irene Bosch Blanco presentó su novela en la Biblioteca de Ferrerías.'},
    {'id':'ev-035','tipo':'Presentación','titulo':"'Caminando con tus ojos' en Es Migjorn Gran",'subtitulo':'Encuentro con el Club de Jubilados','fecha':'2026-04-15','hora':'','lugar':'Club de Jubilados','ciudad':'Es Migjorn Gran (Menorca)','descripcion':'El Club de Jubilados de Es Migjorn Gran recibió a Irene Bosch Blanco para presentar su libro.'},
    {'id':'ev-036','tipo':'Presentación','titulo':"'Las doce cosechas' en Ceuta",'subtitulo':'Maite Cuesta presenta su novela','fecha':'2026-04-15','hora':'','lugar':'Biblioteca Pública del Estado','ciudad':'Ceuta','descripcion':'Presentación de la novela de Maite Cuesta en la Biblioteca Pública del Estado en Ceuta.'},
    {'id':'ev-037','tipo':'Presentación','titulo':"'Caminando con tus ojos' en el CEIP Pere Casasnovas",'subtitulo':'Taller literario para alumnos de primaria','fecha':'2026-04-14','hora':'','lugar':'CEIP Pere Casasnovas','ciudad':'Ciutadella (Menorca)','descripcion':'Irene Bosch Blanco realizó un taller para alumnos de sexto de primaria.'},
    {'id':'ev-038','tipo':'Presentación','titulo':"'Tú y el amor' en Orihuela",'subtitulo':'Jesús Paredes Ortiz presenta su poemario','fecha':'2026-04-13','hora':'','lugar':'Biblioteca Pública Municipal María Moliner','ciudad':'Orihuela (Alicante)','descripcion':'Presentación del poemario de Jesús Paredes Ortiz.'},
    {'id':'ev-039','tipo':'Presentación','titulo':"'El canto triste del cuervo' en Granada",'subtitulo':'José Prados Osuna presenta su novela histórica','fecha':'2026-04-10','hora':'','lugar':'Biblioteca de Andalucía','ciudad':'Granada','descripcion':'Presentación de la novela histórica de José Prados Osuna en la Biblioteca de Andalucía.'},
    {'id':'ev-040','tipo':'Presentación','titulo':"'La gestión del silencio' en Málaga",'subtitulo':'Manuel Bayona presenta su libro','fecha':'2026-03-26','hora':'','lugar':'Colegio Oficial de Médicos de Málaga','ciudad':'Málaga','descripcion':'Presentación del libro de Manuel Bayona en el Colegio Oficial de Médicos de Málaga.'},
    {'id':'ev-041','tipo':'Presentación','titulo':"'Lagrimaciendo sobre el vacío' en Íllora",'subtitulo':'Ana Barea Arco presenta su poemario','fecha':'2026-04-10','hora':'','lugar':'Biblioteca Pública Municipal','ciudad':'Íllora (Granada)','descripcion':'Presentación del poemario de Ana Barea Arco en Íllora.'},
    {'id':'ev-042','tipo':'Presentación','titulo':"'Destilación' en el Carmen de la Victoria (Granada)",'subtitulo':'Paula R. Bouzas presenta su poemario','fecha':'2026-03-27','hora':'','lugar':'Carmen de la Victoria','ciudad':'Granada','descripcion':'Presentación en un espacio íntimo de Granada.'},
    {'id':'ev-043','tipo':'Presentación','titulo':"'La vieja inquietud del aire' en Córdoba",'subtitulo':'Diego Castillo Barco presenta su libro','fecha':'2026-03-21','hora':'','lugar':'Biblioteca Pública Grupo Cántico','ciudad':'Córdoba','descripcion':'Presentación del libro de Diego Castillo Barco en Córdoba.'},
    {'id':'ev-044','tipo':'Presentación','titulo':"'La gestión del silencio' en Huelma",'subtitulo':'Manuel Bayona presenta su libro','fecha':'2026-03-20','hora':'','lugar':'Huelma','ciudad':'Huelma (Jaén)','descripcion':'Presentación de la obra de Manuel Bayona García en Huelma.'},
    {'id':'ev-045','tipo':'Presentación','titulo':"'Las doce cosechas' en Granada",'subtitulo':'Maite Cuesta presenta su novela','fecha':'2026-03-25','hora':'','lugar':'Biblioteca Pública Municipal Francisco Ayala','ciudad':'Granada','descripcion':'Presentación de la nueva novela de Maite Cuesta en la Biblioteca Francisco Ayala.'},
    {'id':'ev-046','tipo':'Presentación','titulo':"'Los ríos nunca miran atrás' en Jerte",'subtitulo':'José Luis Monroy Antón en el Festival Despierta 26','fecha':'2026-03-25','hora':'','lugar':'Festival Despierta 26','ciudad':'Jerte (Cáceres)','descripcion':'Presentación de la obra de José Luis Monroy Antón en el Festival Literario Despierta 26.'},
    {'id':'ev-047','tipo':'Presentación','titulo':"'Caminando con tus ojos' en la ONCE (Granada)",'subtitulo':'Irene Bosch Blanco presenta su novela','fecha':'2026-03-19','hora':'','lugar':'Sede de la ONCE en Granada','ciudad':'Granada','descripcion':'Irene Bosch Blanco presentó su libro en la sede de la ONCE en Granada.'},
    {'id':'ev-048','tipo':'Presentación','titulo':"'Los ríos nunca miran atrás' en Granada",'subtitulo':'Presentación en el Cuarto Real de Santo Domingo','fecha':'2026-04-15','hora':'','lugar':'Cuarto Real de Santo Domingo','ciudad':'Granada','descripcion':'Presentación de la novela de José Luis Monroy Antón.'},
    {'id':'ev-049','tipo':'Presentación','titulo':"'Caminando con tus ojos' en La Cocina de Molinos",'subtitulo':'Presentación en Granada','fecha':'2026-03-12','hora':'','lugar':'La Cocina de Molinos','ciudad':'Granada','descripcion':'Presentación en el corazón de Granada ante un público con conocimiento personal de la discapacidad.'},
    {'id':'ev-050','tipo':'Presentación','titulo':"'Caminando con tus ojos' en el CEIP La Inmaculada",'subtitulo':'Taller con alumnos','fecha':'2026-03-09','hora':'','lugar':'CEIP Ecoescuela La Inmaculada','ciudad':'Granada','descripcion':'Encuentro entre Irene Bosch y alumnos del colegio.'},
    {'id':'ev-051','tipo':'Presentación','titulo':"'La gestión del silencio' en Granada",'subtitulo':'Manuel Bayona presenta su libro','fecha':'2026-02-27','hora':'','lugar':'Atrio del Hotel Palacio Santa Paula','ciudad':'Granada','descripcion':'Presentación de Manuel Bayona en el Hotel Palacio Santa Paula de Granada.'},
    {'id':'ev-052','tipo':'Presentación','titulo':"'Crónica de un profesor de instituto' en Salobreña",'subtitulo':'Daniel Morales Escobar presenta su libro','fecha':'2026-02-27','hora':'','lugar':'Salobreña','ciudad':'Salobreña (Granada)','descripcion':'Presentación en Salobreña de la obra de Daniel Morales Escobar.'},
    {'id':'ev-053','tipo':'Presentación','titulo':"'Crónica de un profesor de instituto' en Granada",'subtitulo':'Presentación del libro de Daniel Morales Escobar','fecha':'2026-02-20','hora':'','lugar':'Granada','ciudad':'Granada','descripcion':'Presentación de Crónica de un profesor de instituto en Granada.'},
    {'id':'ev-054','tipo':'Presentación','titulo':"'Cómodamente adormecido' en el ciclo Letras Compartidas de Mijas",'subtitulo':'Juan Quero presenta su novela en Mijas','fecha':'2025-04-22','hora':'','lugar':'Ciclo Letras Compartidas','ciudad':'Mijas (Málaga)','descripcion':'Presentación de Cómodamente adormecido en el ciclo Letras Compartidas de Mijas.'},
    {'id':'ev-055','tipo':'Presentación','titulo':"'Cómodamente adormecido' en El Patio de Fuengirola",'subtitulo':'Juan Quero presenta su novela','fecha':'2025-04-22','hora':'','lugar':'El Patio, Fuengirola TV','ciudad':'Fuengirola (Málaga)','descripcion':'Entrevista y presentación de Juan Quero en El Patio de Fuengirola TV.'},
    {'id':'ev-056','tipo':'Presentación','titulo':"'El jardín de Estocolmo' en Melilla",'subtitulo':'Antonio César Morón presenta su novela','fecha':'2023-06-14','hora':'','lugar':'La Librería de Melilla','ciudad':'Melilla','descripcion':'Presentación de El jardín de Estocolmo en La Librería de Melilla.'},
  ];

  static List<Map<String, dynamic>> _blogNazariData() => [];

  // ── Autores (colección `autores`) ────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> obtenerAutores(String empresaId) {
    return _firestore
        .collection('empresas').doc(empresaId)
        .collection('autores')
        .orderBy('nombre')
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Categorías ──────────────────────────────────────────────────────────────

  Stream<List<CategoriaBlog>> obtenerCategorias(String empresaId) {
    return _categoriasCol(empresaId)
        .orderBy('orden')
        .snapshots()
        .map((s) => s.docs
            .map((d) => CategoriaBlog.fromMap({...d.data(), 'id': d.id}))
            .where((c) => !c.eliminado)
            .toList())
        .handleError((_) {
          // Sin índice: fallback sin orden
          return _categoriasCol(empresaId).snapshots().map((s) => s.docs
              .map((d) => CategoriaBlog.fromMap({...d.data(), 'id': d.id}))
              .where((c) => !c.eliminado)
              .toList());
        });
  }

  Future<void> guardarCategoria(String empresaId, CategoriaBlog cat) async {
    final data = cat.toMap();
    await _categoriasCol(empresaId)
        .doc(cat.id.isEmpty ? null : cat.id)
        .set(data, SetOptions(merge: true));
  }

  Future<void> eliminarCategoria(String empresaId, String catId) async {
    // Verifica si hay artículos en uso (filtro eliminado en cliente)
    final uso = await _blogCol(empresaId)
        .where('categoria_id', isEqualTo: catId)
        .limit(5)
        .get();
    final enUso = uso.docs.any((d) => d.data()['eliminado'] != true);
    if (enUso) {
      throw Exception('No se puede eliminar: hay artículos en esta categoría');
    }
    await _categoriasCol(empresaId).doc(catId).update({'eliminado': true});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEO
  // ═══════════════════════════════════════════════════════════════════════════

  DocumentReference<Map<String, dynamic>> _seoDoc(String empresaId) =>
      _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('seo_web');

  Stream<SeoConfig> obtenerSeoConfig(String empresaId) {
    return _seoDoc(empresaId).snapshots().map((doc) =>
        doc.exists ? SeoConfig.fromMap(doc.data()!) : const SeoConfig());
  }

  Future<void> guardarSeoConfig(String empresaId, SeoConfig seo) async {
    await _seoDoc(empresaId).set(
        {...seo.toMap(), 'actualizado': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN AVANZADA (popup, banner, contacto)
  // ═══════════════════════════════════════════════════════════════════════════

  DocumentReference<Map<String, dynamic>> _configAvanzadaDoc(String empresaId) =>
      _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('web_avanzada');

  Stream<ConfigWebAvanzada> obtenerConfigAvanzada(String empresaId) {
    return _configAvanzadaDoc(empresaId).snapshots().map((doc) =>
        doc.exists
            ? ConfigWebAvanzada.fromMap(doc.data()!)
            : const ConfigWebAvanzada());
  }

  Future<void> guardarConfigAvanzada(
      String empresaId, ConfigWebAvanzada config) async {
    await _configAvanzadaDoc(empresaId).set(
        {...config.toMap(), 'actualizado': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN FORMULARIO DE RESERVAS WEB
  // Guarda en: empresas/{id}/configuracion/reservas_web
  // El formulario HTML la lee en tiempo real para bloquear horas/fechas
  // ══════════════════════════════���════════════════════════════════════════════

  DocumentReference<Map<String, dynamic>> _configReservasWebDoc(String empresaId) =>
      _firestore
          .collection('empresas')
          .doc(empresaId)
          .collection('configuracion')
          .doc('reservas_web');

  Stream<ConfigReservasWeb> obtenerConfigReservasWeb(String empresaId) {
    return _configReservasWebDoc(empresaId).snapshots().map((doc) =>
        doc.exists
            ? ConfigReservasWeb.fromMap(doc.data()!)
            : const ConfigReservasWeb());
  }

  Future<void> guardarConfigReservasWeb(
      String empresaId, ConfigReservasWeb config) async {
    await _configReservasWebDoc(empresaId).set(
        {...config.toMap(), 'actualizado': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  // ── Galería de imágenes web ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerGaleria(String empresaId) async {
    final snap = await _firestore
        .collection('empresas').doc(empresaId)
        .collection('galeria_web')
        .orderBy('subida', descending: true)
        .limit(100)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> agregarAGaleria(String empresaId, String url) async {
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('galeria_web')
        .add({'url': url, 'subida': FieldValue.serverTimestamp()});
  }

  Future<void> eliminarDeGaleria(String empresaId, String id) async {
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('galeria_web').doc(id).delete();
  }

  // ── Estado del script en la web ───────────────────────────────────────────

  Stream<DateTime?> obtenerUltimoPingScript(String empresaId) {
    return _firestore
        .collection('empresas').doc(empresaId)
        .collection('config_web').doc('script_status')
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final ts = doc.data()?['ultimo_ping'];
          if (ts is Timestamp) return ts.toDate();
          return null;
        });
  }

  Stream<List<Map<String, dynamic>>> obtenerGaleriaStream(String empresaId) {
    return _firestore
        .collection('empresas').doc(empresaId)
        .collection('galeria_web')
        .orderBy('subida', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CATÁLOGO EDITORIAL (libros + autores)
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> obtenerLibros(String empresaId) {
    return _firestore
        .collection('empresas').doc(empresaId)
        .collection('libros')
        .orderBy('titulo')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> guardarLibro(
      String empresaId, String? slug, Map<String, dynamic> data) async {
    final col = _firestore.collection('empresas').doc(empresaId).collection('libros');
    final id = (slug != null && slug.isNotEmpty) ? slug : null;
    if (id != null) {
      await col.doc(id).set({...data, 'fecha_actualizacion': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    } else {
      await col.add({...data, 'fecha_creacion': FieldValue.serverTimestamp()});
    }
  }

  Future<void> toggleActivoLibro(String empresaId, String slug, bool activo) async {
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('libros').doc(slug)
        .update({'activo': activo});
  }

  Future<void> eliminarLibro(String empresaId, String slug) async {
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('libros').doc(slug)
        .delete();
  }

  /// Genera un ID de Firestore determinista desde el nombre del autor,
  /// igual que el script de importación (`naz-${slug}`).
  static String _autorSlugId(String nombre) {
    final slug = nombre.toLowerCase()
        .replaceAll(RegExp(r'[àáâãäåā]'), 'a')
        .replaceAll(RegExp(r'[èéêëē]'), 'e')
        .replaceAll(RegExp(r'[ìíîïī]'), 'i')
        .replaceAll(RegExp(r'[òóôõöō]'), 'o')
        .replaceAll(RegExp(r'[ùúûüū]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'naz-$slug';
  }

  Future<void> guardarAutor(
      String empresaId, String? docId, Map<String, dynamic> data) async {
    final col = _firestore.collection('empresas').doc(empresaId).collection('autores');
    final nombre = data['nombre'] as String? ?? '';

    // Usar ID determinista para evitar duplicados al crear nuevos autores
    final id = (docId != null && docId.isNotEmpty)
        ? docId
        : _autorSlugId(nombre);

    final isNew = docId == null || docId.isEmpty;
    await col.doc(id).set({
      ...data,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
      if (isNew) 'fecha_creacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> eliminarAutor(String empresaId, String docId) async {
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('autores').doc(docId)
        .delete();
  }

  /// Elimina autores duplicados (mismo nombre normalizado) conservando
  /// el registro con más datos (bio + foto + género + lugar).
  /// Devuelve el número de documentos eliminados.
  Future<int> dedupAutores(String empresaId) async {
    final col  = _firestore.collection('empresas').doc(empresaId).collection('autores');
    final snap = await col.get();

    // Agrupar por nombre normalizado
    final grupos = <String, List<DocumentSnapshot>>{};
    for (final doc in snap.docs) {
      final d      = doc.data();
      final nombre = (d['nombre'] as String? ?? '').trim();
      if (nombre.isEmpty) continue;
      final key = _autorSlugId(nombre); // mismo hash que el ID determinista
      grupos[key] = [...(grupos[key] ?? []), doc];
    }

    var batch   = _firestore.batch();
    var cnt     = 0;
    var deleted = 0;

    for (final grupo in grupos.values) {
      if (grupo.length <= 1) continue;

      // Puntuar cada doc: más datos = mayor puntuación
      int score(DocumentSnapshot doc) {
        final d = doc.data() as Map<String, dynamic>;
        int s = 0;
        if ((d['bio']         as String? ?? '').isNotEmpty) s += 6;
        if ((d['foto']        as String? ?? '').isNotEmpty) s += 5;
        if ((d['foto_url']    as String? ?? '').isNotEmpty) s += 5;
        if ((d['descripcion'] as String? ?? '').isNotEmpty) s += 3;
        if ((d['genero']      as String? ?? '').isNotEmpty) s += 2;
        if ((d['lugar']       as String? ?? '').isNotEmpty) s += 2;
        // Preferir IDs con prefijo naz- (importación canónica)
        if (doc.id.startsWith('naz-')) s += 10;
        return s;
      }

      final sorted = [...grupo]..sort((a, b) => score(b) - score(a));

      // Conservar el más rico; si su ID no es determinista, re-escribirlo
      final keeper = sorted.first;
      final keepId = _autorSlugId(
          ((keeper.data() as Map<String, dynamic>)['nombre'] as String? ?? ''));
      if (keeper.id != keepId) {
        // Mover al ID canónico
        final kData = keeper.data() as Map<String, dynamic>;
        batch.set(col.doc(keepId), {
          ...kData,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.delete(keeper.reference);
        cnt += 2;
      }

      // Eliminar el resto
      for (final dup in sorted.skip(1)) {
        batch.delete(dup.reference);
        deleted++;
        cnt++;
        if (cnt >= 490) {
          await batch.commit();
          batch = _firestore.batch();
          cnt   = 0;
        }
      }
    }
    if (cnt > 0) await batch.commit();
    return deleted;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CATÁLOGO WEB GENÉRICO — catalogo_web (sync tiempo real a la web)
  // ═══════════════════════════════════════════════════════════════════════════

  CollectionReference<Map<String, dynamic>> _catalogoCol(String empresaId) =>
      _firestore.collection('empresas').doc(empresaId).collection('catalogo_web');

  Stream<List<Map<String, dynamic>>> obtenerCatalogoWeb(String empresaId) {
    return _catalogoCol(empresaId)
        .snapshots()
        .map((snap) {
          final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          docs.sort((a, b) =>
              ((a['orden'] as num?)?.toInt() ?? 9999)
              .compareTo((b['orden'] as num?)?.toInt() ?? 9999));
          return docs;
        });
  }

  /// Stream de catálogo filtrado por seccion_id (secciones dinámicas data-fluix)
  Stream<List<Map<String, dynamic>>> obtenerCatalogoWebSeccion(
      String empresaId, String seccionId) {
    return _catalogoCol(empresaId)
        .where('seccion_id', isEqualTo: seccionId)
        .snapshots()
        .map((snap) {
          final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          docs.sort((a, b) =>
              ((a['orden'] as num?)?.toInt() ?? 9999)
              .compareTo((b['orden'] as num?)?.toInt() ?? 9999));
          return docs;
        });
  }

  Future<void> guardarItemCatalogo(
      String empresaId, String? docId, Map<String, dynamic> data) async {
    if (docId != null && docId.isNotEmpty) {
      await _catalogoCol(empresaId).doc(docId).set(
          {...data, 'fecha_actualizacion': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      // Sincronizar datos en seleccion_nazari si el libro está en la Selección
      unawaited(_sincronizarEnSeleccion(empresaId, docId, data));
    } else {
      // Determinar orden contando documentos existentes
      int orden = 0;
      try {
        final snap = await _catalogoCol(empresaId).get();
        orden = snap.docs.length;
      } catch (_) {}
      data['orden'] = orden;
      await _catalogoCol(empresaId)
          .add({...data, 'fecha_creacion': FieldValue.serverTimestamp()});
    }
  }

  Future<void> _sincronizarEnSeleccion(
      String empresaId, String catalogoId, Map<String, dynamic> data) async {
    try {
      final snap = await _firestore
          .collection('empresas').doc(empresaId)
          .collection('seleccion_nazari')
          .where('catalogo_id', isEqualTo: catalogoId)
          .get();
      if (snap.docs.isEmpty) return;
      final titulo  = data['nombre']      as String? ?? data['titulo'] as String? ?? '';
      final autor   = data['campo_autor'] as String? ?? data['autor']  as String? ?? '';
      final imagen  = data['imagen_url']  as String? ?? data['imagen'] as String? ?? '';
      final precio  = data['precio']      as String? ?? '';
      final stripe  = data['stripe_link'] as String? ?? '';
      final slug    = (data['slug'] as String?)?.isNotEmpty == true
          ? data['slug'] as String : catalogoId;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          if (titulo.isNotEmpty)  'titulo': titulo,
          if (autor.isNotEmpty)   'autor':  autor,
          if (imagen.isNotEmpty)  'imagen': imagen,
          if (precio.isNotEmpty)  'precio': precio,
          if (stripe.isNotEmpty)  'stripe_link': stripe,
          'slug': slug,
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> toggleActivoItemCatalogo(
      String empresaId, String docId, bool activo) async {
    await _catalogoCol(empresaId).doc(docId).update({
      'activo': activo,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarItemCatalogo(String empresaId, String docId) async {
    await _catalogoCol(empresaId).doc(docId).delete();
  }

  Future<void> toggleLibroDelMesCatalogo(
      String empresaId, String docId, bool actual) async {
    final col = _catalogoCol(empresaId);
    final batch = _firestore.batch();
    // Quitar libro del mes de cualquier otro item
    final actuales = await col.where('es_libro_del_mes', isEqualTo: true).get();
    for (final d in actuales.docs) {
      batch.update(d.reference, {'es_libro_del_mes': false});
    }
    if (!actual) {
      batch.update(col.doc(docId), {'es_libro_del_mes': true});
    }
    await batch.commit();
  }

  /// Migra libros existentes de la colección `libros` a `catalogo_web`.
  Future<int> migrarLibrosACatalogoWeb(String empresaId) async {
    final snap = await _firestore
        .collection('empresas').doc(empresaId)
        .collection('libros').get();
    if (snap.docs.isEmpty) return 0;
    int migrados = 0;
    for (var i = 0; i < snap.docs.length; i++) {
      final l = snap.docs[i].data();
      final payLink = (l['payment_link'] as String? ?? '').isNotEmpty
          ? l['payment_link'] as String
          : (l['payment_link_test'] as String? ?? '');
      await _catalogoCol(empresaId).doc(snap.docs[i].id).set({
        'nombre':      l['titulo'] ?? l['nombre'] ?? '',
        'descripcion': l['sinopsis'] ?? l['descripcion'] ?? '',
        'precio':      l['precio'] ?? '',
        'precio_digital': l['precioEbook'] ?? '',
        'imagen_url':  l['imagen_url'] ?? '',
        'activo':      l['activo'] ?? true,
        'orden':       i,
        'slug':        l['slug'] ?? snap.docs[i].id,
        'tag':         l['tag'] ?? '',
        'categoria':   l['genero'] ?? '',
        'campo_autor': l['autor'] ?? '',
        'campo_isbn':  l['isbn'] ?? '',
        'campo_paginas': l['paginas']?.toString() ?? '',
        'campo_formato': l['formato'] ?? '',
        'campo_dimensiones': l['dimensiones'] ?? '',
        'campo_anio':  l['anio']?.toString() ?? '',
        'campo_mes':   l['mes'] ?? '',
        if (payLink.isNotEmpty) 'stripe_link': payLink,
        'origen':      'libros',
        'migrado_en':  FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      migrados++;
    }
    return migrados;
  }

  /// Sincroniza los Payment Links de Stripe desde `libros` a `catalogo_web`.
  /// Lee todos los libros con `payment_link` y los escribe en `stripe_link`
  /// del item correspondiente en `catalogo_web` (por slug o por ID del doc).
  /// Devuelve el nº de items actualizados.
  Future<int> sincronizarLinksStripe(String empresaId) async {
    final librosSnap = await _firestore
        .collection('empresas').doc(empresaId)
        .collection('libros').get();
    if (librosSnap.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    int actualizados = 0;

    for (final libroDoc in librosSnap.docs) {
      final l = libroDoc.data();
      final payLink = (l['payment_link'] as String? ?? '').isNotEmpty
          ? l['payment_link'] as String
          : (l['payment_link_test'] as String? ?? '');
      if (payLink.isEmpty) continue;

      final slug = l['slug'] as String? ?? '';

      // Buscar en catalogo_web por doc ID (mismo que libros) o por slug
      final candidatos = <DocumentReference<Map<String, dynamic>>>[];

      // 1. Mismo ID de documento
      candidatos.add(_catalogoCol(empresaId).doc(libroDoc.id));

      // 2. Buscar por slug si es diferente al id
      if (slug.isNotEmpty && slug != libroDoc.id) {
        final porSlug = await _catalogoCol(empresaId)
            .where('slug', isEqualTo: slug).limit(1).get();
        if (porSlug.docs.isNotEmpty) {
          candidatos.add(porSlug.docs.first.reference);
        }
      }

      for (final ref in candidatos) {
        batch.set(ref, {'stripe_link': payLink}, SetOptions(merge: true));
      }
      actualizados++;
    }

    if (actualizados > 0) await batch.commit();
    return actualizados;
  }

  /// Importa un producto del catálogo de pedidos al catálogo web.
  Future<void> importarProductoComoItemCatalogo(
      String empresaId, Map<String, dynamic> producto) async {
    final nombre = producto['nombre'] as String? ?? '';
    final precio = (producto['precio'] as num?)?.toDouble() ?? 0.0;
    await guardarItemCatalogo(empresaId, null, {
      'nombre':      nombre,
      'descripcion': producto['descripcion'] as String? ?? '',
      'precio':      precio > 0 ? '${precio.toStringAsFixed(2)} €' : '',
      'imagen_url':  producto['imagenUrl'] as String? ?? producto['imagen_url'] as String? ?? '',
      'categoria':   producto['categoria'] as String? ?? '',
      'activo':      true,
      'origen':      'productos',
      'producto_id': producto['id'] as String? ?? '',
    });
  }

  Stream<List<Map<String, dynamic>>> obtenerProductosCatalogo(String empresaId) {
    return _firestore
        .collection('empresas').doc(empresaId)
        .collection('productos')
        .where('activo', isEqualTo: true)
        .orderBy('nombre')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((_) => <Map<String, dynamic>>[]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATOS DE EJEMPLO — Editorial Nazarí
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> crearLibroEjemploNazari(String empresaId) async {
    const slug = 'la-granada-invisible';
    final data = <String, dynamic>{
      'slug':        slug,
      'titulo':      'La Granada Invisible',
      'autor':       'Carmen Ruiz Lozano',
      'autorExtra':  'Prólogo de Miguel Ángel Fernández',
      'genero':      'Narrativa contemporánea',
      'coleccion':   'Voces del Sur',
      'tag':         'Novedad',
      'precio':      '16,50 €',
      'precioEbook': '6,99 €',
      'isbn':        '978-84-99999-00-1',
      'paginas':     '312',
      'mes':         'Septiembre',
      'anio':        2026,
      'formato':     'Rústica con solapas',
      'dimensiones': '14 × 21 cm',
      'imagen_url':  '',
      'sinopsis':
          'Una historia sobre la memoria, la identidad y los barrios que desaparecen sin '
          'que nadie los llore. Carmen Ruiz Lozano nos lleva de la mano por las callejuelas '
          'del Albaicín de los años ochenta, donde una niña descubre que su ciudad guarda '
          'secretos que los adultos prefieren olvidar.\n\n'
          'Con una prosa delicada y precisa, La Granada Invisible es un homenaje a quienes '
          'construyeron la ciudad con sus manos y desaparecieron de sus páginas de historia.',
      'bio':
          'Carmen Ruiz Lozano (Granada, 1979) es profesora de Literatura en la Universidad '
          'de Granada y autora de los poemarios Raíces de Agua y El color del viento. '
          'La Granada Invisible es su primera novela.',
      'activo': true,
      'fecha_creacion': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('libros').doc(slug)
        .set(data, SetOptions(merge: true));
  }

  Future<void> crearAutorEjemploNazari(String empresaId) async {
    final data = <String, dynamic>{
      'nombre':      'Carmen Ruiz Lozano',
      'genero':      'Narrativa contemporánea',
      'lugar':       'Granada · 1979',
      'descripcion': 'Profesora de Literatura y narradora granadina, autora de La Granada Invisible.',
      'bio':
          'Carmen Ruiz Lozano nació en Granada en 1979. Doctora en Filología Hispánica por '
          'la Universidad de Granada, compagina la docencia universitaria con la escritura.\n\n'
          'Su obra poética —Raíces de Agua (2012) y El color del viento (2018)— ha sido '
          'reconocida con el Premio Jóvenes Creadores de Andalucía y traducida al italiano '
          'y al francés.\n\n'
          'La Granada Invisible (2026), su primera novela, surge de la investigación oral '
          'que llevó a cabo entre vecinos del Albaicín durante más de cinco años.',
      'foto_url': '',
      'activo':   true,
      'fecha_creacion': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('empresas').doc(empresaId)
        .collection('autores').add(data);
  }

  Future<void> crearNoticiaEjemplo(String empresaId) async {
    final noticia = EntradaBlog(
      id: '',
      titulo: 'Editorial Nazarí en la Feria del Libro de Granada 2026',
      slug: 'editorial-nazari-feria-libro-granada-2026',
      resumen:
          'Estaremos presentes con caseta propia del 6 al 15 de junio. '
          'Presentaciones, firmas y descuentos exclusivos en todos nuestros títulos.',
      contenido:
          '# Editorial Nazarí en la Feria del Libro de Granada 2026\n\n'
          'Un año más, **Editorial Nazarí** estará presente en la **Feria del Libro de Granada**, '
          'que se celebra del **6 al 15 de junio de 2026** en el Paseo del Salón.\n\n'
          '## ¿Dónde encontrarnos?\n\n'
          'Puedes visitarnos en la **caseta nº 24**, situada junto al estanque central. '
          'El horario de atención será de 10:00 a 14:00 h y de 17:30 a 21:30 h todos los días.\n\n'
          '## Presentaciones y firmas\n\n'
          '| Fecha | Hora | Evento |\n'
          '|-------|------|--------|\n'
          '| 7 de junio | 19:00 h | Presentación de *La Granada Invisible* con Carmen Ruiz Lozano |\n'
          '| 10 de junio | 18:00 h | Firma de libros — colección Voces del Sur |\n'
          '| 14 de junio | 19:30 h | Mesa redonda: «El futuro de la narrativa andaluza» |\n\n'
          '## Descuentos exclusivos\n\n'
          'Durante toda la feria, los visitantes de nuestra caseta disfrutarán de un **15 % de '
          'descuento** en todos los títulos del catálogo y del **20 % en packs de colección**.\n\n'
          '---\n\n'
          '*¿Tienes alguna pregunta? Escríbenos a [info@editorialnazari.com](mailto:info@editorialnazari.com) '
          'o llámanos al 958 00 00 00.*',
      estado: EstadoBlog.publicado,
      fechaPublicacion: DateTime.now(),
      autor: 'Redacción Editorial Nazarí',
      etiquetas: ['feria del libro', 'granada', 'eventos', '2026'],
      destacado: true,
      tipo: 'noticia',
      seoMetaTitle: 'Editorial Nazarí en la Feria del Libro de Granada 2026',
      seoMetaDescription:
          'Visítanos en la caseta nº 24 de la Feria del Libro de Granada del 6 al 15 de junio. '
          'Presentaciones, firmas y un 15 % de descuento en todo el catálogo.',
      seoKeywords: ['editorial nazarí', 'feria del libro granada', 'presentación libros'],
    );
    await guardarEntradaBlog(empresaId, noticia);
  }
}

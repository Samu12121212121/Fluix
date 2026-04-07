import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/modelos/seccion_web.dart';

// ignore_for_file: avoid_print

class ContenidoWebService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<List<SeccionWeb>> obtenerSecciones(String empresaId) {
    return _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contenido_web')
        .snapshots()
        .map((snap) {
          final lista = snap.docs
              .map((d) => SeccionWeb.fromMap({...d.data(), 'id': d.id}))
              .toList();
          lista.sort((a, b) {
            final oa = (snap.docs.firstWhere((d) => d.id == a.id).data()['orden'] ?? 0) as int;
            final ob = (snap.docs.firstWhere((d) => d.id == b.id).data()['orden'] ?? 0) as int;
            return oa.compareTo(ob);
          });
          return lista;
        });
  }

  Future<void> guardarSeccion(String empresaId, SeccionWeb seccion) async {
    final data = seccion.toMap();
    data['fecha_actualizacion'] = FieldValue.serverTimestamp();
    data['orden'] = data['orden'] ?? 0;
    await _firestore
        .collection('empresas')
        .doc(empresaId)
        .collection('contenido_web')
        .doc(seccion.id.isEmpty ? null : seccion.id)
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
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error subiendo imagen desde galería: $e');
      return null;
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

    buf.writeln('<!--  CONTENIDO DINÁMICO PLANEAGUADA CRM -->');
    buf.writeln('<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js"></script>');
    buf.writeln('<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js"></script>');
    buf.writeln('<script>');
    buf.writeln('(function(){');
    buf.writeln('  const cfg={apiKey:"AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",authDomain:"planeaapp-4bea4.firebaseapp.com",projectId:"planeaapp-4bea4"};');
    buf.writeln('  if(!firebase.apps.length) firebase.initializeApp(cfg);');
    buf.writeln('  const db=firebase.firestore();');
    buf.writeln('  const EMPRESA="$empresaId";');
    buf.writeln('  function render(id,html,show){const el=document.getElementById("fluixcrm_"+id);if(!el)return;el.innerHTML=html;el.style.display=(show===false)?"none":"";}');
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
    buf.writeln('<!-- ═══════════════════════════════════════════════════════ -->');
    buf.writeln('<!-- DIVS donde se inyectará el contenido.                   -->');
    buf.writeln('<!-- Pega cada uno donde quieras en tu HTML.                 -->');
    buf.writeln('<!-- TIP: añade style="display:none" para secciones ocultas. -->');
    buf.writeln('<!--      Se mostrarán automáticamente al activarlas en la app -->');
    buf.writeln('<!-- ═══════════════════════════════════════════════════════ -->');
    for (final s in activas) {
      buf.writeln('<!-- ${s.nombre} (${s.tipo.nombre}) -->');
      buf.writeln('<div id="fluixcrm_${s.id}"></div>');
      buf.writeln();
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

    // Formulario de contacto
    if (cfg.contactoActivo) {
      buf.writeln('  (function(){const el=document.getElementById("fluixcrm_contacto");if(!el)return;el.innerHTML=`<div style="max-width:480px"><h3>${cfg.contactoTitulo ?? "Contáctanos"}</h3><form onsubmit="fluixEnviarContacto(event)" style="display:flex;flex-direction:column;gap:12px"><input name="nombre" placeholder="Tu nombre" required style="padding:10px;border:1px solid #ddd;border-radius:8px"><input name="email" type="email" placeholder="Tu email" required style="padding:10px;border:1px solid #ddd;border-radius:8px"><textarea name="mensaje" placeholder="Tu mensaje" rows="4" required style="padding:10px;border:1px solid #ddd;border-radius:8px;resize:vertical"></textarea><button type="submit" style="background:#1976D2;color:#fff;padding:12px;border:none;border-radius:8px;cursor:pointer;font-weight:bold">Enviar mensaje</button></form></div>`;window.fluixEnviarContacto=function(e){e.preventDefault();const fd=new FormData(e.target);db.collection("empresas").doc(EMPRESA).collection("contacto_web").add({nombre:fd.get("nombre"),email:fd.get("email"),mensaje:fd.get("mensaje"),fecha:firebase.firestore.FieldValue.serverTimestamp(),leido:false}).then(()=>{e.target.innerHTML="<p style=\'color:green;font-weight:bold\'>✅ Mensaje enviado.</p>";}).catch(err=>{alert("Error: "+err.message);});};})();');
    }

    // RESERVAS WEB
    // Inyectar en #fluixcrm_reservas
    buf.writeln('  // Formulario de Reserva Web');
    buf.writeln('  (function(){');
    buf.writeln('    const el=document.getElementById("fluixcrm_reservas");');
    buf.writeln('    if(!el) return;');
    buf.writeln('    el.innerHTML=`<div style="max-width:480px;border:1px solid #eee;padding:24px;border-radius:12px"><h3>📅 Reservar Mesa / Cita</h3><form onsubmit="fluixReserva(event)" style="display:flex;flex-direction:column;gap:14px"><input name="nombre" placeholder="Tu nombre" required style="padding:12px;border:1px solid #ddd;border-radius:8px"><input name="telefono" type="tel" placeholder="Tu teléfono" required style="padding:12px;border:1px solid #ddd;border-radius:8px"><div style="display:flex;gap:10px"><input name="fecha" type="date" required style="padding:12px;border:1px solid #ddd;border-radius:8px;flex:1"><input name="hora" type="time" required style="padding:12px;border:1px solid #ddd;border-radius:8px;flex:1"></div><input name="personas" type="number" min="1" placeholder="Nº Personas" style="padding:12px;border:1px solid #ddd;border-radius:8px"><button type="submit" style="background:#1976D2;color:#fff;padding:14px;border:none;border-radius:8px;cursor:pointer;font-weight:bold;font-size:16px">Solicitar Reserva</button></form></div>`;');
    buf.writeln('    window.fluixReserva=function(e){');
    buf.writeln('      e.preventDefault();');
    buf.writeln('      const fd=new FormData(e.target);');
    buf.writeln('      const fechaStr = fd.get("fecha") + "T" + fd.get("hora") + ":00";');
    buf.writeln('      const fecha = new Date(fechaStr);');
    buf.writeln('      db.collection("empresas").doc(EMPRESA).collection("reservas").add({');
    buf.writeln('        nombre_cliente: fd.get("nombre"),');
    buf.writeln('        telefono_cliente: fd.get("telefono"),');
    buf.writeln('        personas: fd.get("personas") ? parseInt(fd.get("personas")) : 1,');
    buf.writeln('        fecha: firebase.firestore.Timestamp.fromDate(fecha),');
    buf.writeln('        fecha_hora: fecha.toISOString(),');
    buf.writeln('        estado: "PENDIENTE",');
    buf.writeln('        origen: "web",');
    buf.writeln('        fecha_creacion: firebase.firestore.FieldValue.serverTimestamp()');
    buf.writeln('      }).then(()=>{');
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
  // BLOG / NOTICIAS
  // ═══════════════════════════════════════════════════════════════════════════

  CollectionReference<Map<String, dynamic>> _blogCol(String empresaId) =>
      _firestore.collection('empresas').doc(empresaId).collection('blog');

  Stream<List<EntradaBlog>> obtenerBlog(String empresaId) {
    return _blogCol(empresaId)
        .orderBy('fecha_publicacion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => EntradaBlog.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> guardarEntradaBlog(String empresaId, EntradaBlog entrada) async {
    final data = entrada.toMap();
    data['fecha_publicacion'] = FieldValue.serverTimestamp();
    await _blogCol(empresaId)
        .doc(entrada.id.isEmpty ? null : entrada.id)
        .set(data, SetOptions(merge: true));
  }

  Future<void> eliminarEntradaBlog(String empresaId, String entradaId) async {
    await _blogCol(empresaId).doc(entradaId).delete();
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
}

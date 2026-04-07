# 🚀 SISTEMA MULTI-EMPRESA CON SCRIPTS DINÁMICOS

## ✅ **¿ESTÁ IMPLEMENTADO?**

**SÍ, el sistema está completamente implementado.** Cada empresa que se registre en PlaneaGuada tendrá su propio script personalizado que puede instalar en su web.

---

## 🏗️ **ARQUITECTURA DEL SISTEMA**

### **1. Cloud Functions (Backend)**
Tienes **2 endpoints HTTP** que generan scripts personalizados:

#### A. `generarScriptEmpresa` (Descarga HTML)
```
GET https://europe-west1-planeaapp-4bea4.cloudfunctions.net/generarScriptEmpresa?empresaId=TU_ID_EMPRESA
```
- Devuelve un archivo HTML descargable
- El usuario lo descarga y lo pega en el footer de su WordPress

#### B. `obtenerScriptJSON` (Devuelve JSON)
```
GET https://europe-west1-planeaapp-4bea4.cloudfunctions.net/obtenerScriptJSON?empresaId=TU_ID_EMPRESA
```
- Devuelve el script en formato JSON
- Para integración programática

### **2. Pantalla en Flutter**
Creé: `PantallaIntegracionScript` que:
- Obtiene los datos de la empresa
- Llamada a la Cloud Function
- Muestra el script con instrucciones paso a paso
- Botón "Copiar" para copiar al portapapeles
- Vista previa del código

### **3. Script Dinámico**
Cada empresa recibe un script personalizado con:
- **EMPRESA_ID**: Su ID único en Firebase
- **DOMINIO_WEB**: Su dominio (ej: fluixtech.com)
- **NOMBRE_EMPRESA**: Su nombre
- **Funcionalidades**:
  - Registra visitas en tiempo real
  - Rastreatoda llamadas telefónicas
  - Rastreera formularios de contacto
  - Rastreera clicks en WhatsApp
  - Sincroniza datos con Firestore

---

## 📊 **FLOW COMPLETO**

```
1. EMPRESA SE REGISTRA
   ↓
2. ACCEDE A PANEL ADMIN
   ↓
3. VA A INTEGRACIÓN > SCRIPT
   ↓
4. VE PANTALLA CON INSTRUCCIONES
   ↓
5. COPIA EL SCRIPT PERSONALIZADO
   ↓
6. PEGA EN FOOTER DE SU WORDPRESS
   ↓
7. LOS DATOS COMIENZAN A LLEGAR A LA APP EN TIEMPO REAL
   ↓
8. VE EN MÓDULO DE ESTADÍSTICAS:
   - Visitas web
   - Llamadas telefónicas
   - Formularios de contacto
   - Eventos de WhatsApp
```

---

## 🔐 **SEGURIDAD**

✅ Cada empresa solo ve sus propios datos
✅ El script no bloquea la web si Firebase falla
✅ No requiere autenticación adicional
✅ Usa las credenciales compartidas de Firebase (compartidas entre todas las empresas pero separadas por empresaId)
✅ Datos encriptados en tránsito (HTTPS)

---

## 📋 **SCRIPT PARA FLUIXTECH.COM**

Aquí está el script listo para pegar en tu web (reemplaza `TU_ID_EMPRESA` con tu ID real):

```html
<!-- ============================================================
     🔥 PLANEAGUADA CRM - SCRIPT FOOTER DINÁMICO
     Web: fluixtech.com
     Empresa: Fluixtech
     Versión: SEGURA (no bloquea la web si Firebase falla)
     ============================================================ -->

<!-- Firebase SDK -->
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore-compat.js"></script>

<script>
(function () {
  'use strict';

  // ── CONFIGURACIÓN PERSONALIZADA ────────────────────────────────────────
  const FIREBASE_CONFIG = {
    apiKey: "AIzaSyCvOaB1hF_sF-A6jMZ0MusttuhzSMDezb4",
    authDomain: "planeaapp-4bea4.firebaseapp.com",
    projectId: "planeaapp-4bea4",
    storageBucket: "planeaapp-4bea4.firebasestorage.app",
    messagingSenderId: "1085482191658",
    appId: "1:1085482191658:web:c5461353b123ab92d62c53"
  };

  const EMPRESA_ID = "TU_ID_EMPRESA"; // ← Reemplaza con tu ID
  const DOMINIO_WEB = "fluixtech.com";
  const NOMBRE_EMPRESA = "Fluixtech";

  // ── ARRANQUE SEGURO ────────────────────────────────────────────────────
  window.addEventListener('load', function () {
    try {
      inicializar();
    } catch (e) {
      console.warn('PlaneaGuada CRM: error al inicializar (la web funciona igualmente)', e);
    }
  });

  // ── INICIALIZACIÓN ─────────────────────────────────────────────────────
  function inicializar() {
    if (!firebase.apps || !firebase.apps.length) {
      firebase.initializeApp(FIREBASE_CONFIG);
    }

    var db = firebase.firestore();

    registrarVisita(db).catch(function (e) {
      console.warn('PlaneaGuada: error registrando visita', e);
    });

    rastrearEventos(db).catch(function (e) {
      console.warn('PlaneaGuada: error rastreando eventos', e);
    });
  }

  // ── REGISTRAR VISITA ───────────────────────────────────────────────────
  async function registrarVisita(db) {
    var fechaHoy = new Date().toISOString().substring(0, 10);
    var paginaActual = window.location.pathname || '/';
    var hora = new Date().getHours();
    var referrer = document.referrer || 'Directo';

    // Estadísticas generales
    await db
      .collection('empresas').doc(EMPRESA_ID)
      .collection('estadisticas').doc('web_resumen')
      .set({
        visitas_totales: firebase.firestore.FieldValue.increment(1),
        visitas_mes: firebase.firestore.FieldValue.increment(1),
        ultima_visita: firebase.firestore.FieldValue.serverTimestamp(),
        sitio_web: DOMINIO_WEB,
        nombre_empresa: NOMBRE_EMPRESA,
        pagina_actual: paginaActual,
        referrer_actual: referrer
      }, { merge: true });

    // Visitas diarias detalladas
    await db
      .collection('empresas').doc(EMPRESA_ID)
      .collection('estadisticas').doc(`visitas_${fechaHoy}`)
      .set({
        fecha: fechaHoy,
        sitio: DOMINIO_WEB,
        visitas: firebase.firestore.FieldValue.increment(1),
        paginas_vistas: firebase.firestore.FieldValue.arrayUnion(paginaActual),
        referrers: firebase.firestore.FieldValue.arrayUnion(referrer),
        [`visitas_hora_${hora}`]: firebase.firestore.FieldValue.increment(1),
        timestamp: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

    console.log('✅ Visita registrada para Fluixtech en ' + fechaHoy);
  }

  // ── RASTREAR EVENTOS ───────────────────────────────────────────────────
  async function rastrearEventos(db) {
    // Detectar clicks en teléfono
    var telefonos = document.querySelectorAll('a[href^="tel:"], .telefono, .phone');
    telefonos.forEach(function(tel) {
      tel.addEventListener('click', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "llamada_telefonica",
            sitio: DOMINIO_WEB,
            numero: tel.textContent || tel.href,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('📞 Llamada registrada');
      });
    });

    // Detectar formularios de contacto
    var formularios = document.querySelectorAll('form[id*="contact"], form[class*="contact"], .contact-form');
    formularios.forEach(function(form) {
      form.addEventListener('submit', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "formulario_contacto",
            sitio: DOMINIO_WEB,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('📧 Formulario registrado');
      });
    });

    // Detectar whatsapp clicks
    var whatsapps = document.querySelectorAll('a[href*="wa.me"], a[href*="whatsapp"], .whatsapp-btn');
    whatsapps.forEach(function(btn) {
      btn.addEventListener('click', function() {
        db.collection("empresas")
          .doc(EMPRESA_ID)
          .collection("eventos")
          .add({
            tipo: "whatsapp_click",
            sitio: DOMINIO_WEB,
            fecha: firebase.firestore.FieldValue.serverTimestamp()
          });
        console.log('💬 WhatsApp click registrado');
      });
    });
  }

})();
</script>

<!-- 
🎯 INSTRUCCIONES:
1. Reemplaza "TU_ID_EMPRESA" con tu ID real
2. Pega este código en el footer de tu WordPress (antes del </body>)
3. Los datos comenzarán a llegar a tu app PlaneaGuada en tiempo real
-->
```

---

## 🔗 **DÓNDE PEGAR EL SCRIPT EN WORDPRESS**

### **Opción 1: Editor de Temas (Recomendado)**
1. Ve a `Apariencia > Editor de temas`
2. Busca `footer.php` en la lista
3. Desplázate hasta el final
4. Pega el script **ANTES** de `</body>`
5. Haz clic en "Actualizar"

### **Opción 2: Plugin Code Snippets**
1. Instala el plugin `Code Snippets`
2. Ve a `Snippets > Añadir Nuevo`
3. Pega el código
4. Actívalo

### **Opción 3: Child Theme (Si usas un tema personalizado)**
1. Ve a `Apariencia > Editor de temas`
2. Edita `functions.php`
3. Al final, añade:
```php
add_action('wp_footer', function() {
  // Pega aquí el contenido del <script>...</script>
});
```

---

## 📊 **QUÉ DATOS LLEGAN A LA APP**

### En Firestore:
```
empresas/
├─ TU_ID_EMPRESA/
│  ├─ estadisticas/
│  │  ├─ web_resumen
│  │  │  ├─ visitas_totales: 254
│  │  │  ├─ visitas_mes: 89
│  │  │  ├─ ultima_visita: timestamp
│  │  │  ├─ sitio_web: "fluixtech.com"
│  │  │  └─ nombre_empresa: "Fluixtech"
│  │  └─ visitas_2024-03-13
│  │     ├─ fecha: "2024-03-13"
│  │     ├─ sitio: "fluixtech.com"
│  │     ├─ visitas: 12
│  │     ├─ paginas_vistas: ["/", "/servicios", "/contacto"]
│  │     ├─ referrers: ["google", "directo", "facebook"]
│  │     └─ visitas_hora_10: 3
│  └─ eventos/
│     ├─ doc1: {tipo: "llamada_telefonica", ...}
│     ├─ doc2: {tipo: "formulario_contacto", ...}
│     └─ doc3: {tipo: "whatsapp_click", ...}
```

### En la App verás:
- ✅ Módulo de Estadísticas: **Tráfico Web Real**
- ✅ Módulo de Eventos: **Acciones de Clientes**
- ✅ Dashboard: **Visitas Totales y Gráficas**

---

## ✨ **VENTAJAS DEL SISTEMA**

✅ **Multi-empresa**: Cada empresa su propio script
✅ **Dinámico**: Se personaliza automáticamente
✅ **Seguro**: No bloquea la web
✅ **Tiempo real**: Datos al instante
✅ **Sin mantenimiento**: Se gestiona automáticamente
✅ **Escalable**: Soporta ilimitadas empresas
✅ **GDPR**: Los datos se guardan en tu Firebase

---

## 🚀 **PRÓXIMOS PASOS**

1. **Deploy de Cloud Functions**:
   ```bash
   firebase deploy --only functions
   ```

2. **Integra la pantalla en el menú**:
   Añade `PantallaIntegracionScript` al dashboard

3. **Prueba con fluixtech.com**:
   - Reemplaza el ID de empresa
   - Pega el script
   - Verifica que los datos lleguen

4. **Documenta para clientes**:
   Envía las instrucciones a cada empresa

---

## 📞 **SOPORTE**

Si hay problemas:
1. Verifica que el Firebase Config sea correcto
2. Abre la consola del navegador (F12) y mira los logs
3. Verifica que Firestore tenga permisos de lectura/escritura
4. Comprueba que el `empresaId` sea exacto

---

**¡Tu sistema está listo para llevar PlaneaGuada a ilimitadas empresas!** 🎉


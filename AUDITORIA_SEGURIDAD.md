# 🔒 AUDITORÍA DE SEGURIDAD COMPLETA — FLUIX CRM
**Fecha:** 5 abril 2026  
**Auditor:** Consultor Senior Seguridad — Apps B2B Flutter + Firebase  
**Versión analizada:** Código fuente completo (Flutter + Cloud Functions)

---

## PARTE 1 — REGLAS DE FIRESTORE

### 1.1 Análisis de Funciones Helper (Líneas 7-45)
Las funciones `perteneceAEmpresa()`, `esPropietario()`, `esAdminOPropietario()` y `esStaffOSuperior()` están **bien diseñadas**. Verifican autenticación + existencia del documento de usuario + empresa_id correcta + rol. ✅

### 1.2 Vulnerabilidades Encontradas

---

#### 🔴 V-FR01: Documento raíz de empresa con lectura pública
**Archivo:** `firestore.rules:92`  
**Regla:** `allow read: if true;`

```
match /empresas/{empresaId} {
  allow read: if true;  // ← CUALQUIER persona sin autenticar
```

**Riesgo:** Cualquier persona (sin siquiera autenticarse) puede leer el documento raíz de TODAS las empresas. Esto expone: nombre de empresa, email de contacto, tipo de negocio, teléfono, dirección, sector, horarios.

**Exploit:** `GET /empresas` → enumera todas las empresas registradas con sus datos de contacto.

**Fix recomendado:**
```
allow read: if perteneceAEmpresa(empresaId);
// Si la web necesita leer datos básicos, crear una colección
// empresas_publicas/ con solo nombre y horarios.
```

---

#### 🔴 V-FR02: Suscripción con lectura pública
**Archivo:** `firestore.rules:202`  
**Regla:** `allow read: if true;`

```
match /suscripcion/{docId} {
  allow read: if perteneceAEmpresa(empresaId);
  allow read: if true;  // ← Sobrescribe la regla anterior
```

**Riesgo:** Cualquier persona puede leer el plan, precio que paga, fecha de vencimiento y estado de suscripción de cualquier empresa. Información comercial sensible.

**Exploit:** Enumerar empresas y saber cuáles tienen suscripción vencida (potencial phishing dirigido).

**Fix:**
```
match /suscripcion/{docId} {
  allow read: if perteneceAEmpresa(empresaId);
  allow write: if false;
}
```

---

#### 🔴 V-FR03: Estadísticas con lectura pública
**Archivo:** `firestore.rules:208`  
**Regla:** `allow read: if true;`

```
match /estadisticas/{docId}/{subcol}/{subId} {
  allow read: if true;
```

**Riesgo:** Las estadísticas incluyen visitas web, ingresos, número de pedidos, métricas de negocio. Un competidor puede ver el volumen de negocio de cualquier empresa.

**Fix:**
```
allow read: if perteneceAEmpresa(empresaId);
```

---

#### 🔴 V-FR04: Nóminas legibles por cualquier empleado (Staff)
**Archivo:** `firestore.rules:170`

```
match /nominas/{nominaId} {
  allow read: if esStaffOSuperior(empresaId);
```

**Riesgo:** Un empleado con rol `staff` puede leer las nóminas de TODOS los empleados de la empresa. Esto incluye salario bruto, deducciones IRPF, bases de cotización, importes líquidos. **Violación directa del RGPD** — datos de nómina son categoría especial.

**Exploit:** Un empleado curioso hace `db.collection('empresas/X/nominas').get()` y ve los salarios de todos sus compañeros.

**Fix:**
```
match /nominas/{nominaId} {
  // Solo admin/propietario ven todas las nóminas
  allow read: if esAdminOPropietario(empresaId);
  // Un empleado solo ve sus propias nóminas
  allow read: if esStaffOSuperior(empresaId)
    && resource.data.empleado_id == uid();
  allow write: if esAdminOPropietario(empresaId);
}
```

---

#### 🔴 V-FR05: Valoraciones y reseñas con escritura pública total
**Archivo:** `firestore.rules:119-129`

```
match /valoraciones/{valoracionId} {
  allow read: if true;
  allow create: if true;  // ← Sin autenticación, sin rate-limit
```

**Riesgo:** Cualquier persona puede crear valoraciones falsas masivamente para cualquier empresa. Sin validación de campos, sin captcha, sin rate-limiting.

**Exploit:** Script que crea 10.000 reseñas de 1 estrella para una empresa competidora en minutos.

**Fix:** Añadir al menos validación del tamaño de datos y considerar rate-limiting por IP en Cloud Functions:
```
allow create: if true
  && request.resource.data.keys().hasAll(['cliente', 'calificacion'])
  && request.resource.data.calificacion is int
  && request.resource.data.calificacion >= 1
  && request.resource.data.calificacion <= 5;
```

---

#### 🔴 V-FR06: Pedidos con `allow create: if true` — inyección de datos
**Archivo:** `firestore.rules:136, 143`

```
match /pedidos/{pedidoId} {
  allow create: if true;
match /pedidos_whatsapp/{pedidoId} {
  allow create: if true;
```

**Riesgo:** Cualquiera puede crear pedidos fraudulentos en cualquier empresa. Un atacante podría llenar la cola de pedidos con basura, causar confusión, o inyectar datos de XSS en campos como `notas_cliente`.

---

#### 🟡 V-FR07: Colecciones `invitaciones` y `login_intentos` SIN reglas explícitas
**Archivo:** `firestore.rules` — ausencia

Las colecciones `invitaciones/{token}` y `login_intentos/{email}` no tienen reglas en `firestore.rules`. La regla por defecto (`allow read, write: if false` en línea 268) las protege, **PERO** el servicio `FuerzaBrutaService` escribe directamente desde el cliente Flutter a `login_intentos/`.

**Riesgo:** Si el cliente Flutter intenta escribir en `login_intentos/`, el write será **rechazado** por Firestore. El servicio de fuerza bruta **no funciona** en producción.

**Exploit:** Fuerza bruta ilimitada — el contador nunca se incrementa porque el write falla silenciosamente (el catch en línea 121 silencia el error).

**Fix:** Añadir reglas para `login_intentos` o migrar la lógica anti-brute-force a Cloud Functions.

---

#### 🟡 V-FR08: Fallback wildcard demasiado amplio
**Archivo:** `firestore.rules:231-234`

```
match /{subcollection}/{documentId} {
  allow read: if perteneceAEmpresa(empresaId);
  allow write: if esAdminOPropietario(empresaId);
}
```

**Riesgo:** Cualquier subcolección futura (ej: `finiquitos`, `gastos`, `embargos_empresa`) hereda automáticamente estas reglas. Un admin puede leer/escribir cualquier subcolección nueva sin revisión explícita.

---

### 1.3 Resumen Firestore Rules

| Colección | Lectura | Escritura | Estado |
|-----------|---------|-----------|--------|
| `empresas/{id}` (raíz) | 🔴 PÚBLICA | ✅ Propietario | CRÍTICO |
| `empresas/{id}/suscripcion` | 🔴 PÚBLICA | ✅ Solo Functions | CRÍTICO |
| `empresas/{id}/estadisticas` | 🔴 PÚBLICA | ✅ Empresa | CRÍTICO |
| `empresas/{id}/nominas` | 🟡 Staff+ (todo) | ✅ Admin+ | IMPORTANTE |
| `empresas/{id}/valoraciones` | PÚBLICA (ok) | 🔴 PÚBLICA | CRÍTICO |
| `empresas/{id}/pedidos` | ✅ Staff+ | 🔴 create: true | IMPORTANTE |
| `empresas/{id}/clientes` | ✅ Staff+ | ✅ Admin+ | OK |
| `empresas/{id}/facturas` | ✅ Admin+ | ✅ Admin+ | OK |
| `login_intentos` | ❌ Sin reglas | ❌ Sin reglas | ROTO |
| `invitaciones` | ❌ Sin reglas | ❌ Sin reglas | Solo Functions OK |

---

## PARTE 2 — CLOUD FUNCTIONS

### 2.1 Funciones Callable — Verificación de Autenticación

| Función | Auth check | Empresa check | Admin check | Estado |
|---------|-----------|---------------|-------------|--------|
| `crearCuentaConPlan` | ✅ | N/A | ✅ `verificarPropietarioPlatforma` | OK |
| `actualizarPlanEmpresa` | ✅ | N/A | ✅ | OK |
| `listarCuentasClientes` | ✅ | N/A | ✅ | OK |
| `actualizarModulosSegunPlan` | ✅ | N/A | ✅ | OK |
| `migracionPlanesV2` | ✅ | N/A | ✅ | OK |
| `firmarXMLVerifactu` | ✅ | ✅ | N/A | OK |
| `remitirVerifactu` | ✅ | ❌ | N/A | 🟡 |
| `storeGmbToken` | 🔴 NO | 🔴 NO | N/A | **CRÍTICO** |
| `obtenerFichasNegocio` | 🔴 NO | 🔴 NO | N/A | **CRÍTICO** |
| `guardarFichaSeleccionada` | 🔴 NO | 🔴 NO | N/A | **CRÍTICO** |
| `desconectarGoogleBusiness` | 🔴 NO | 🔴 NO | N/A | **CRÍTICO** |
| `inicializarEmpresa` | 🔴 NO | 🔴 NO | N/A | **CRÍTICO** |
| `enviarEmailConPdf` | 🔴 NO | 🔴 NO | N/A | **CRÍTICO** |
| `enviarDocumentacionFiniquito` | 🔴 NO | 🔴 NO | N/A | **CRÍTICO** |
| `importarFestivosEspana` | 🔴 NO | 🔴 NO | N/A | **IMPORTANTE** |

---

#### 🔴 V-CF01: 8+ Cloud Functions callable sin verificación de autenticación
**Archivos:** `gmbTokens.ts:120-193`, `index.ts:827-878, 1013-1075, 1805-1987`

Funciones como `storeGmbToken`, `obtenerFichasNegocio`, `guardarFichaSeleccionada`, `desconectarGoogleBusiness`, `inicializarEmpresa`, `enviarEmailConPdf`, `enviarDocumentacionFiniquito`, `importarFestivosEspana` **no verifican `request.auth`**.

**Riesgo para `storeGmbToken`:** Un atacante puede enviar un `serverAuthCode` con cualquier `empresaId` y sobreescribir los tokens OAuth de Google Business Profile de cualquier empresa. Puede tomar control completo de la ficha de Google del negocio.

**Riesgo para `enviarEmailConPdf`:** Un atacante puede enviar emails con PDF adjunto desde el servidor SMTP de la plataforma a cualquier dirección, suplantando la identidad de cualquier empresa. Ideal para phishing.

**Riesgo para `enviarDocumentacionFiniquito`:** Expone documentos de finiquito (nóminas, carta de despido, certificado SEPE) a cualquier persona que conozca el `finiquitoId` y `empresaId`.

**Fix para TODAS estas funciones:**
```typescript
export const storeGmbToken = onCall(
  { region: REGION },
  async (request) => {
    // AÑADIR ESTO al inicio de cada función:
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "No autenticado");
    }
    const uid = request.auth.uid;
    const userDoc = await db.collection("usuarios").doc(uid).get();
    if (!userDoc.exists || userDoc.data()?.empresa_id !== empresaId) {
      throw new HttpsError("permission-denied", "Sin permiso para esta empresa");
    }
    // ... resto de la función
```

---

#### 🔴 V-CF02: `crearEmpresaHTTP` — endpoint HTTP sin autenticación
**Archivo:** `index.ts:884-933`

```typescript
export const crearEmpresaHTTP = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    // NO verifica autenticación NI token secreto
    const { empresaId, nombre, dominio, telefono, direccion } = req.body;
    await empresaRef.set(empresaData, { merge: true });
```

**Riesgo:** Cualquier persona puede crear/sobreescribir empresas en Firestore con `merge: true`. Un atacante podría cambiar el nombre, teléfono y dominio de cualquier empresa existente.

**Fix:** Eliminar esta función o protegerla con token secreto como `webhookPagoWeb`.

---

#### 🔴 V-CF03: `generarScriptEmpresa` y `obtenerScriptJSON` — exponen Firebase API Key
**Archivo:** `index.ts:581-821`

Estas funciones HTTP públicas generan scripts que contienen la API Key de Firebase hardcodeada:
```typescript
const FIREBASE_CONFIG = {
  apiKey: "AIzaSyCvOaB1hF_sF-A6jMZ0MusttuhzSMDezb4",
```

**Riesgo:** Si bien las API Keys de Firebase son semi-públicas (se envían al cliente), el script también da acceso directo de escritura a estadísticas sin autenticación (porque la regla dice `allow write: if perteneceAEmpresa` pero el script no se autentica).

---

#### 🟡 V-CF04: Webhook Stripe acepta eventos sin verificación de firma
**Archivo:** `index.ts:962-967`

```typescript
if (webhookSec && sig) {
  event = stripe.webhooks.constructEvent(rawBody, sig, webhookSec);
} else {
  console.warn("⚠️ Stripe webhook sin verificación de firma (modo dev)");
  event = req.body as Stripe.Event;  // ← BYPASS TOTAL
}
```

**Riesgo:** Si `STRIPE_WEBHOOK_SECRET` no está configurado (el .env tiene un placeholder), **cualquier petición POST se acepta como evento válido**. Un atacante podría fabricar un evento `checkout.session.completed` falso y activar suscripciones gratis.

**Fix:**
```typescript
if (!webhookSec) {
  console.error("❌ STRIPE_WEBHOOK_SECRET no configurada");
  res.status(500).json({ error: "Webhook no configurado" });
  return;
}
if (!sig) {
  res.status(400).json({ error: "Firma de Stripe ausente" });
  return;
}
event = stripe.webhooks.constructEvent(rawBody, sig, webhookSec);
```

---

#### 🟡 V-CF05: `webhookPagoWeb` devuelve `tempPassword` en la respuesta HTTP
**Archivo:** `gestionCuentas.ts:827`

```typescript
res.status(200).json({
  ok: true,
  cuentaCreada,
  tempPassword: cuentaCreada ? tempPassword : undefined,
});
```

**Riesgo:** Si `crearCuentaAuto` es true, la contraseña temporal se devuelve en texto plano en la respuesta HTTP. Si el atacante tiene el `FLUIX_WEBHOOK_SECRET`, obtiene contraseñas de cuentas recién creadas.

---

#### 🟡 V-CF06: `storeGmbToken` devuelve `access_token` al cliente
**Archivo:** `gmbTokens.ts:193`

```typescript
return { success: true, access_token: tokens.access_token };
```

**Riesgo:** El access_token de Google Business Profile se devuelve al cliente Flutter. Si la app es decompilada o el tráfico interceptado, el atacante obtiene acceso a la API de Google Business del negocio.

**Fix:** No devolver el access_token. El cliente no lo necesita — las operaciones GMB se hacen desde Cloud Functions.

---

## PARTE 3 — ALMACENAMIENTO SEGURO EN FLUTTER

### 3.1 Uso de `flutter_secure_storage` — ✅ CORRECTO

| Servicio | Datos guardados | Storage | Estado |
|----------|----------------|---------|--------|
| `BiometriaService` | UID, email, flag activa | `FlutterSecureStorage` (encrypted) | ✅ OK |
| `CertificadoRepository` | Bytes .p12, password | `FlutterSecureStorage` (encrypted) | ✅ OK |
| `CertificadoDigitalService` | Bytes .p12, password | `FlutterSecureStorage` (encrypted) | ✅ OK |
| `GmbAuthService` | Estado conexión local | `FlutterSecureStorage` | ✅ OK |

### 3.2 Uso de `SharedPreferences` — ✅ ACEPTABLE

| Servicio | Datos guardados | Sensible? |
|----------|----------------|-----------|
| `AppConfigService` | Tema, color, prefs notif | ❌ No sensible |
| `TiempoTareaService` | ID tarea activa, timestamp | ❌ No sensible |
| `BriefingService` | Fecha último briefing | ❌ No sensible |

**Conclusión:** SharedPreferences se usa solo para datos no sensibles. ✅

### 3.3 Hardcoded Secrets en Código Dart

---

#### 🔴 V-FS01: Credenciales de admin hardcodeadas en el código fuente
**Archivo:** `lib/core/utils/admin_initializer.dart:10-11`

```dart
static const String adminEmail    = 'samuel.corcho@fluixtech.com';
static const String adminPassword = 'D3?papanata';
```

**Riesgo:** La contraseña del administrador de la plataforma está en texto plano en el código fuente. Cualquier persona que decompile el APK/IPA obtiene acceso completo como admin. Si este repositorio se sube a GitHub (aunque sea privado), cualquier colaborador ve la contraseña.

**Exploit:** `apktool d fluixcrm.apk` → buscar en assets/flutter_assets → encontrar la contraseña.

**Fix INMEDIATO:**
1. Cambiar la contraseña del admin en Firebase Auth
2. Eliminar las constantes del código fuente
3. Envolver todo uso de `AdminInitializer` en `if (kDebugMode)`

---

#### 🔴 V-FS02: Credenciales expuestas en la pantalla de login en producción
**Archivo:** `lib/features/autenticacion/pantallas/pantalla_login.dart:98-166`

El cuadro "Credenciales de Demo" con email y contraseña del admin es visible **en producción** (no está envuelto en `kDebugMode`). `kDebugMode` se importa pero no se usa para condicionar este widget.

**Fix:**
```dart
if (kDebugMode) ...[
  // Cuadro de credenciales demo (líneas 98-166)
],
```

---

#### 🟡 V-FS03: Firebase API Keys en el código Dart generado para embeds web
**Archivo:** `lib/services/contenido_web_service.dart:248`

```dart
buf.writeln('  const cfg={apiKey:"AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU"...');
```

Las API Keys de Firebase son semi-públicas por diseño, pero tener **dos API Keys diferentes** (una en `firebase_options.dart` y otra en los scripts embed) sugiere que una de ellas puede estar incorrecta o tener permisos más amplios. Revisar restricciones de API Key en la consola de GCP.

---

#### 🔴 V-FS04: `credentials.json` (Service Account) en el repositorio
**Archivo:** `credentials.json` en la raíz del proyecto

El archivo contiene una **clave privada completa** de una Service Account de Firebase (`firestore-importer@planeaapp-4bea4.iam.gserviceaccount.com`). Aunque `.gitignore` lo excluye, el archivo **existe en disco** y puede haber sido commiteado previamente.

**Riesgo:** Quien tenga este archivo puede:
- Leer/escribir cualquier documento de Firestore (bypass total de rules)
- Acceder a Firebase Storage
- Crear/eliminar usuarios de Firebase Auth
- Generar tokens personalizados

**Fix INMEDIATO:**
1. Revocar esta Service Account en la consola GCP
2. Crear una nueva con permisos mínimos
3. Verificar que nunca fue commiteada: `git log --all --full-history -- credentials.json`
4. Si fue commiteada, rotar TODAS las credenciales

---

## PARTE 4 — FIREBASE STORAGE

#### 🟡 V-ST01: No se encontró archivo `storage.rules`
**Estado:** No existe `storage.rules` en el proyecto.

**Riesgo:** Si no se han desplegado reglas de Storage personalizadas, se aplican las reglas por defecto de Firebase, que en modo producción son:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

Esto es seguro (deniega todo), pero si alguna vez se cambió a `allow read, write: if request.auth != null`, entonces **cualquier usuario autenticado puede leer nóminas, DNIs, contratos de TODAS las empresas**.

**Fix:** Crear y desplegar `storage.rules` explícitas:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Catálogo público
    match /empresas/{empresaId}/catalogo/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    // Documentos de empleados — solo admin de la empresa
    match /empresas/{empresaId}/empleados/{allPaths=**} {
      allow read, write: if request.auth != null;
      // Idealmente verificar empresa en custom claims
    }
    // Certificados — nunca accesibles desde el cliente
    match /empresas/{empresaId}/certificados/{allPaths=**} {
      allow read, write: if false;
    }
    // Todo lo demás: denegado
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

#### 🟡 V-ST02: Certificado PKCS#12 almacenado en Firestore (no solo en Storage)
**Archivos:** `firmarXMLVerifactu.ts:57-75`, `remitirVerifactu.ts:52-69`

```typescript
let certDoc = await db.collection("empresas").doc(empresaId)
  .collection("configuracion").doc("certificado_verifactu").get();
p12Buffer = Buffer.from(certData!.p12Base64, "base64");
p12Password = certData!.password;
```

**Riesgo:** El certificado digital PKCS#12 (con clave privada) Y su contraseña se almacenan en un documento de Firestore en Base64. Las reglas de Firestore permiten que el propietario lea `configuracion/certificado_verifactu`. Esto significa que si un atacante compromete la cuenta del propietario, obtiene el certificado digital fiscal completo.

**Fix:** Mover certificados a Google Secret Manager (como ya se hace con los tokens GMB). Las funciones que firman XML ya tienen Admin SDK y pueden acceder a Secret Manager directamente.

---

## PARTE 5 — AUTENTICACIÓN Y SESIONES

### 5.1 Flujo de 2FA

**Estado:** ❌ NO INTEGRADO

No se encontró implementación de 2FA (Two-Factor Authentication). No hay uso de `firebase_auth.multiFactor`, ni verificación SMS/TOTP.

**Recomendación:** Para una app que maneja nóminas, datos fiscales y certificados digitales, 2FA debería ser **obligatorio** para roles `propietario` y `admin`.

### 5.2 Protección de Fuerza Bruta

#### 🔴 V-AU01: Servicio anti-fuerza-bruta roto en producción
**Archivo:** `lib/services/auth/fuerza_bruta_service.dart`

El servicio escribe a `login_intentos/{email}` en Firestore. Pero esta colección **no tiene reglas** en `firestore.rules`, y la regla por defecto es `allow read, write: if false`.

**Resultado:** El `catch` en la línea 121 silencia el error de permisos denegados:
```dart
} catch (_) {
  // No bloquear el flujo de login si falla el registro
}
```

El servicio **nunca registra los intentos** y el usuario **nunca se bloquea**. Un atacante tiene intentos ilimitados.

**Fix:** Migrar la lógica anti-brute-force a una Cloud Function que se llame en cada intento de login, o añadir reglas permisivas para `login_intentos` (pero cuidado con permitir que un atacante borre su propio contador).

### 5.3 Invitaciones

**Estado:** ✅ CORRECTO
- Los tokens de invitación tienen expiración de 72 horas (`expiresHours = 72`)
- Se valida `inv.valida` que comprueba expiración y si ya fue usada
- La invitación se marca como usada después del registro
- La colección `invitaciones` no tiene reglas de cliente (solo Admin SDK escribe desde la Cloud Function) — correcto

### 5.4 Biometría

#### 🟡 V-AU02: Biometría no se invalida al cambiar contraseña
**Archivo:** `lib/services/auth/biometria_service.dart`

El servicio guarda `biometria_uid` y `biometria_email` en secure storage. Si el usuario cambia su contraseña, la biometría sigue activa con el UID anterior.

**Riesgo:** Si un administrador cambia la contraseña de un empleado (por ejemplo, tras un despido), la biometría del dispositivo anterior sigue concediendo acceso al UID del empleado.

**Fix:** Añadir listener de `onAuthStateChanged` que verifique si el token de sesión sigue siendo válido, y desactivar biometría si la sesión ha sido revocada.

### 5.5 Datos de la biometría

La biometría solo almacena: `uid`, `email`, y un flag `true/false`. **No almacena contraseñas ni tokens de sesión propios**. La autenticación real se delega a Firebase Auth via `signInWithEmailAndPassword` usando el email guardado. ✅ Correcto.

---

## PARTE 6 — DATOS EN TRÁNSITO Y EN REPOSO

### 6.1 Llamadas HTTP inseguras

**Estado:** ✅ No se encontraron llamadas `http://` a APIs externas. Todas las llamadas de red usan Firebase (HTTPS), Stripe (HTTPS), Google APIs (HTTPS) y AEAT (HTTPS con mTLS). Los únicos `http://` encontrados son en namespaces XML estándar (W3C) que no son URLs de red.

### 6.2 Datos Sensibles en Logs

#### 🟡 V-LG01: `console.log` con tokens de invitación
**Archivo:** `functions/src/invitaciones.ts:179`

```typescript
console.log(`✅ Invitación enviada a ${email} (token: ${token})`);
```

**Riesgo:** El token de invitación se escribe en los logs de Cloud Functions (Cloud Logging). Alguien con acceso a los logs puede usar el token para registrarse en la empresa.

### 6.3 PDFs de Nóminas/Facturas

#### 🟡 V-LG02: URLs de PDFs pueden no estar firmadas con expiración
**Archivo:** `functions/src/index.ts:1852-1859`

```typescript
const url = finiq[info.field] as string | undefined;
const buffer = await descargarArchivo(url);
```

Las URLs de finiquitos se almacenan en Firestore. Si son URLs públicas de Firebase Storage (sin token de expiración), cualquier persona con la URL puede acceder al PDF permanentemente.

**Fix:** Usar `getSignedUrl()` con expiración corta al generar los PDFs, y regenerar la URL firmada solo cuando se necesite enviar el email.

---

## PARTE 7 — DEPENDENCIAS Y PAQUETES

### 7.1 Paquetes con acceso a datos sensibles

| Paquete | Versión | Acceso a | Notas |
|---------|---------|----------|-------|
| `firebase_auth` | ^5.3.1 | Autenticación | Crítico |
| `cloud_firestore` | ^5.4.4 | Todos los datos | Crítico |
| `firebase_storage` | ^12.3.4 | Archivos (nóminas, DNI) | Crítico |
| `flutter_secure_storage` | ^9.2.2 | Certificados, biometría | Crítico |
| `google_sign_in` | ^6.2.1 | Token OAuth Google | Alto |
| `local_auth` | ^2.3.0 | Biometría dispositivo | Alto |
| `geolocator` | ^13.0.1 | GPS (control horario) | Medio |
| `dio` | ^5.7.0 | Red (Google Reviews API) | Medio |
| `image_picker` | ^1.1.2 | Cámara/galería | Bajo |
| `device_info_plus` | ^10.1.2 | Info hardware | Bajo |

### 7.2 Verificación de CVEs

<details>
<summary>Verificación de vulnerabilidades conocidas</summary>

Se recomienda ejecutar `flutter pub outdated` y verificar los paquetes críticos contra la base de datos OSV (Open Source Vulnerabilities). Las versiones actuales son relativamente recientes pero deben mantenerse actualizadas.

Paquetes a monitorizar especialmente:
- `dio` (historial de vulnerabilidades en redirect following)
- `pointycastle` (criptografía — cualquier CVE es crítico)
- `firebase_*` (mantener al día siempre)
</details>

---

## PUNTUACIÓN DE SEGURIDAD GLOBAL

# 3.5 / 10

**Justificación:**
- ✅ Buena arquitectura base (roles, helpers de Firestore, Secret Manager para GMB)
- ✅ flutter_secure_storage bien usado para certificados y biometría
- ✅ SharedPreferences solo para datos no sensibles
- ✅ Invitaciones con expiración y uso único
- ✅ HTTPS en todas las comunicaciones
- ❌ Contraseña del admin hardcodeada y expuesta en producción
- ❌ Service Account key en el repositorio
- ❌ 8+ Cloud Functions sin autenticación
- ❌ Reglas Firestore con `allow read: if true` en datos sensibles
- ❌ Nóminas legibles por cualquier empleado
- ❌ Anti-brute-force roto silenciosamente
- ❌ Webhook Stripe con bypass de firma
- ❌ Sin 2FA
- ❌ Sin Storage rules

---

## TOP 5 VULNERABILIDADES MÁS GRAVES — CORREGIR INMEDIATAMENTE

| # | ID | Problema | Impacto | Esfuerzo |
|---|-----|---------|---------|----------|
| **1** | V-FS01 + V-FS02 | Contraseña admin `D3?papanata` hardcodeada y visible en pantalla de login en producción | Acceso total a la plataforma | 🟢 30 min |
| **2** | V-FS04 | `credentials.json` con Service Account key en el repositorio | Bypass total de TODAS las reglas de seguridad | 🟢 1 hora |
| **3** | V-CF01 | 8 Cloud Functions callable sin verificación de auth | Cualquiera puede enviar emails, sobreescribir tokens OAuth, crear empresas | 🟡 2-3 horas |
| **4** | V-FR04 | Nóminas legibles por cualquier empleado Staff | Violación RGPD — todos los empleados ven salarios de todos | 🟢 15 min |
| **5** | V-FR01/02/03 | Datos de empresa, suscripción y estadísticas con lectura pública | Enumeración de clientes y datos comerciales | 🟢 15 min |

---

## QUICK FIXES (< 30 min cada uno)

### QF-1: Proteger credenciales admin en login (5 min)
**Archivo:** `lib/features/autenticacion/pantallas/pantalla_login.dart`
```dart
// Envolver líneas 98-166 en:
if (kDebugMode) ...[
  Container( /* ... cuadro credenciales demo ... */ ),
],
```

### QF-2: Eliminar contraseña hardcodeada (10 min)
**Archivo:** `lib/core/utils/admin_initializer.dart`
```dart
// Cambiar líneas 10-11 a:
static const String adminEmail    = '';  // Solo en debug
static const String adminPassword = '';  // Solo en debug
// O mejor: eliminar la clase y mover la lógica al .env local
```
**Después:** Cambiar la contraseña en Firebase Auth Console.

### QF-3: Arreglar reglas de nóminas (5 min)
**Archivo:** `firestore.rules:169-172`
```
match /nominas/{nominaId} {
  allow read: if esAdminOPropietario(empresaId)
    || (esStaffOSuperior(empresaId) && resource.data.empleado_id == uid());
  allow write: if esAdminOPropietario(empresaId);
}
```

### QF-4: Eliminar `allow read: if true` de empresa, suscripción y estadísticas (5 min)
**Archivo:** `firestore.rules:92, 202, 208`
```
// Línea 92: eliminar → allow read: if true;
// Línea 202: eliminar → allow read: if true;
// Línea 208: cambiar → allow read: if perteneceAEmpresa(empresaId);
```

### QF-5: Forzar verificación de firma Stripe (5 min)
**Archivo:** `functions/src/index.ts:962-967`
```typescript
if (!webhookSec || !sig) {
  res.status(400).json({ error: "Webhook no configurado o firma ausente" });
  return;
}
event = stripe.webhooks.constructEvent(rawBody, sig, webhookSec);
```

### QF-6: Revocar y regenerar Service Account (15 min)
1. Ir a GCP Console → IAM → Service Accounts
2. Desactivar `firestore-importer@planeaapp-4bea4.iam.gserviceaccount.com`
3. Crear nueva con permisos mínimos
4. Eliminar `credentials.json` del disco
5. Verificar historial git: `git log --all -- credentials.json`

### QF-7: Eliminar `access_token` del return de `storeGmbToken` (2 min)
**Archivo:** `functions/src/gmbTokens.ts:193`
```typescript
return { success: true }; // No devolver access_token
```

---

## RECOMENDACIONES PARA ANTES DEL LANZAMIENTO

### Prioridad Máxima (bloquean lanzamiento)
1. ✅ Aplicar todos los Quick Fixes (QF-1 a QF-7)
2. ✅ Añadir `if (!request.auth)` a TODAS las Cloud Functions callable
3. ✅ Crear y desplegar `storage.rules`
4. ✅ Eliminar función `crearEmpresaHTTP` (duplicado inseguro de `inicializarEmpresa`)
5. ✅ Migrar anti-brute-force a Cloud Function
6. ✅ Añadir reglas para `login_intentos` en Firestore (o eliminar la colección y usar Functions)

### Prioridad Alta (antes de 2 semanas post-lanzamiento)
7. Implementar 2FA para roles propietario/admin
8. Mover certificados PKCS#12 de Firestore a Secret Manager
9. Auditar que los PDFs de nóminas usen URLs firmadas con expiración
10. Añadir App Check enforcement en todas las Cloud Functions callable
11. Implementar rate-limiting para `valoraciones` y `pedidos` públicos
12. Eliminar clase `AdminInitializer` por completo

### Prioridad Media (primer mes)
13. Añadir `Semantics` widgets para accesibilidad
14. Eliminar todos los `print()` en servicios de producción
15. Añadir Custom Claims de Firebase Auth para roles (en lugar de verificar Firestore en cada operación)
16. Añadir pruebas de seguridad automatizadas para Firestore rules
17. Restringir API Keys de Firebase en la consola GCP (por app, por API)

---

## RESUMEN EJECUTIVO

Fluix CRM tiene una **arquitectura de seguridad bien pensada** en su diseño (Secret Manager para OAuth, flutter_secure_storage para certificados, roles granulares en Firestore), pero la **implementación tiene brechas graves**: credenciales hardcodeadas expuestas en producción, múltiples Cloud Functions sin autenticación, y reglas de Firestore con lecturas públicas en datos sensibles.

Los 7 quick fixes propuestos se pueden implementar en **menos de 2 horas** y transforman la postura de seguridad de "extremadamente vulnerable" a "aceptable para un MVP". Los problemas de prioridad alta deben abordarse antes de manejar datos reales de empresas.

**La vulnerabilidad más crítica** es la combinación V-FS01 + V-FS04: la contraseña del admin está en el código fuente Y existe una Service Account key en disco que permite bypass total de reglas de seguridad. Estos dos problemas deben resolverse **antes de cualquier otro cambio**.


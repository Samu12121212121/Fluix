# Fluix CRM — Análisis Técnico de Publicación
## Fluix Tech, S.L. · Octubre 2026

---

## Índice

1. [Resumen ejecutivo](#resumen-ejecutivo)
   - 1.1 Estado por plataforma (semáforo)
   - 1.2 Top 10 riesgos
   - 1.3 Hoja de ruta por fases
   - 1.4 Esfuerzo total estimado
2. [Análisis técnico — Multiplataforma y publicación](#cap1)
3. [Análisis técnico — Módulo Web + Editorial Nazarí](#cap2)
4. [Análisis técnico — Fichajes (RDL 8/2019)](#cap3)
5. [Análisis técnico — Empleados, nóminas y RGPD](#cap4)
6. [Análisis técnico — Clientes, multi-tenant y RGPD](#cap5)
7. [Análisis técnico — Facturación y Verifactu](#cap6)
8. [Análisis técnico — Modelos fiscales AEAT](#cap7)
9. [Anexo — Rutas de fichero citadas](#anexo)

---

# 1. Resumen ejecutivo {#resumen-ejecutivo}

## 1.1 Estado por plataforma

| Plataforma | Estado | Descripción |
|---|---|---|
| **iOS** | 🟡 AMARILLO | En producción. Configuración correcta (firma, App Check, FCM, PrivacyInfo). Bloqueos menores: deployment target 17.0 excluye ~10% usuarios; inconsistencia bundle ID en GoogleService-Info.plist. Publicable con correcciones S. |
| **Android** | 🟡 AMARILLO | En producción. Build funcional con R8, keystore configurado, FCM/Crashlytics activos. Bloqueantes: key.properties con contraseña en texto plano (verificar git), namespace ≠ applicationId, Data Safety declaration pendiente. Publicable con correcciones S-M. |
| **Windows** | 🔴 ROJO | Compila pero NO distribuible. Sin MSIX, sin firma de código, sin CI/CD, sin estrategia de actualización. 3 crashes garantizados en runtime (mobile_scanner, cache_service FFI, blue_thermal_printer). App Check y Crashlytics desactivados. Requiere trabajo M-L antes de entregar. |

**Estado global de los módulos clave:**

| Módulo | iOS/Android | Windows |
|---|---|---|
| Web + Nazarí | 🟡 Funcional, P0 de seguridad | 🟡 Funcional (no usa plugins incompatibles) |
| Fichajes | 🟡 Funcional, PIN en texto plano | 🔴 Sin biometría, exportación rota |
| Empleados | 🔴 Brecha RGPD crítica | 🔴 Brecha RGPD crítica |
| Clientes | 🔴 Brecha RGPD crítica | 🔴 Brecha RGPD crítica |
| Facturación | 🟡 Funcional, Verifactu no conforme | 🟡 Envío email roto, PDF OK |
| Verifactu | 🔴 3 bloqueantes técnicos legales | 🔴 3 bloqueantes técnicos legales |
| Modelos AEAT | 🔴 303 y 390 con bugs críticos | 🔴 Exportación rota en Windows |

---

## 1.2 Top 10 riesgos

Ordenados por impacto combinado (probabilidad × consecuencia legal/técnica).

| # | Nivel | Riesgo | Módulo | Fichero |
|---|---|---|---|---|
| R1 | ⛔ CRÍTICO | **Regla Firestore expone todos los empleados**: `allow list: if isAuth() && !esAnonimo()` en `/usuarios` permite a cualquier usuario autenticado listar empleados de cualquier empresa del sistema. Brecha de confidencialidad masiva. | Empleados | `firestore.rules` (regla usuarios list) |
| R2 | ⛔ CRÍTICO | **Verifactu: hash SHA-256 incorrecto**. Campo `descripcion` incluido en la concatenación SHA-256 del Bloque 6, contra lo especificado en la Orden HAC/1177/2024. La AEAT rechazará todos los registros enviados. | Facturación | `modelos_verifactu.dart:213` |
| R3 | ⛔ CRÍTICO | **Verifactu: C14N falsa**. La canonicalización XML en cliente Flutter y Cloud Function no es C14N conforme (RFC 3076), invalidando la firma XAdES-BES. | Facturación | `firma_xades_pkcs12_service.dart:785–795`, `firmarXMLVerifactu.ts:194` |
| R4 | ⛔ CRÍTICO | **Modelos AEAT 303: tipos IVA invertidos**. `_construirCasillas` asigna tipo reducido (10%) a casilla [01] y general (21%) a [04]; el modelo oficial AEAT usa 01=4%, 04=10%, 07=21%. Cualquier declaración exportada es fiscalmente incorrecta. | AEAT | `lib/features/fiscal/pantallas/modelo303_screen.dart` |
| R5 | ⛔ CRÍTICO | **Storage sin aislamiento de empresa**: reglas de Firebase Storage para documentos de empleados (contratos, nóminas, DNI) solo requieren `request.auth != null`, sin verificar pertenencia a la empresa. Cualquier usuario autenticado puede acceder. | Empleados | `storage.rules` |
| R6 | 🔴 ALTO | **Borrado incompleto viola RGPD**: `_eliminarCliente()` y `_eliminarEmpleado()` borran el documento raíz pero dejan subcolecciones, Storage files y referencias en facturas/reservas intactas. Incumple art. 17 RGPD (derecho de supresión). | Clientes / Empleados | `modulo_clientes_screen.dart`, `formulario_empleado_form.dart` |
| R7 | 🔴 ALTO | **CF cross-tenant**: `recalcularStatsCliente` (callable) verifica autenticación pero no que el caller pertenezca a la misma empresa que el cliente solicitado. Posible acceso cross-empresa. | Clientes | `functions/src/automaciones_clientes.ts` |
| R8 | 🔴 ALTO | **PIN en texto plano**: el PIN de fichaje se almacena sin hash en Firestore (`empleados_fichaje/{uid}.pin`), visible desde la consola Firebase. | Fichajes | `lib/features/fichajes/servicios/fichaje_service.dart` |
| R9 | 🔴 ALTO | **key.properties con contraseña del keystore Android en texto plano**: si este fichero está en git, la clave de firma de producción queda expuesta. | Multiplataforma | `android/key.properties:1-4` |
| R10 | 🔴 ALTO | **Certificado Verifactu PKCS12 en Firestore en texto plano**: tanto el certificado base64 como su contraseña se almacenan en Firestore en lugar de en GCP Secret Manager. | Facturación | `firmarXMLVerifactu.ts:74`, `remitirVerifactu.ts:69` |

---

## 1.3 Hoja de ruta por fases

### Fase A — Correcciones de seguridad críticas (antes de cualquier publicación Windows)
*Tiempo estimado: 3–5 días*

1. **A1** — Corregir regla Firestore `/usuarios list` para verificar empresa (`perteneceAEmpresa`) (S)
2. **A2** — Corregir reglas Storage para documentos de empleados — añadir verificación de empresa (S)
3. **A3** — Verificar que `android/key.properties` está en `.gitignore` y no ha sido commiteado con contraseñas (S)
4. **A4** — Añadir guard de plataforma en `mobile_scanner` para Windows (S)
5. **A5** — Inicializar FFI en `cache_service.dart` para Windows (copiar patrón de `offline_queue_service.dart`) (S)
6. **A6** — Hashear el PIN de fichaje con bcrypt/SHA antes de almacenar en Firestore (S)
7. **A7** — Añadir regla Firestore para subcollección `audit_log` de fichajes (S)

### Fase B — Correcciones legales AEAT (antes de usar facturación y modelos en producción)
*Tiempo estimado: 5–8 días*

1. **B1** — Corregir campo `descripcion` en hash SHA-256 de Verifactu (`modelos_verifactu.dart:213`) (S)
2. **B2** — Implementar C14N conforme RFC 3076 en `firma_xades_pkcs12_service.dart` y `firmarXMLVerifactu.ts` (M)
3. **B3** — Envolver escritura de cadena Verifactu en transacción Firestore (S)
4. **B4** — Integrar flujo Verifactu en `crearFacturaRectificativa` (S)
5. **B5** — Corregir asignación de casillas en Mod.303 (`_construirCasillas` — tipos IVA) (S)
6. **B6** — Corregir colección objetivo en `Mod390PosicionalService` (`modelos_fiscales` en lugar de `modelos303`) (S)
7. **B7** — Corregir mismatch `Q1..Q4` vs `1T..4T` en historial de presentaciones (S)
8. **B8** — Generar exportador posicional DR190e25v13 para Mod.190 (M)

### Fase C — RGPD y cumplimiento de datos (antes de onboarding de nuevas empresas)
*Tiempo estimado: 8–12 días*

1. **C1** — Implementar borrado en cascada para cliente: subcolecciones + Storage + referencias (M)
2. **C2** — Implementar borrado en cascada para empleado: cuenta Auth + Storage + subcolecciones (M)
3. **C3** — Añadir campo `consentimiento_rgpd` al modelo Cliente; validación en alta y en importación CSV (M)
4. **C4** — Añadir checkbox de consentimiento RGPD en formularios web de contacto y reservas (S)
5. **C5** — Separar datos especialmente sensibles de empleado (DNI, NSS, IBAN) en subcolección protegida (M)
6. **C6** — Validar token de invitación en reglas Firestore (campo `expira`) (S)
7. **C7** — Corregir CF `recalcularStatsCliente`: verificar empresa antes de procesar (S)
8. **C8** — Completar Data Safety declaration en Play Console (GPS, biometría, cámara, device ID) (S)

### Fase D — Distribución Windows y calidad CI/CD
*Tiempo estimado: 5–8 días*

1. **D1** — Implementar MSIX con herramienta `msix` de pub.dev (M)
2. **D2** — Obtener certificado de firma de código OV/EV y configurar en CI (M)
3. **D3** — Crear workflow GitHub Actions / Codemagic para Windows (build → sign → MSIX) (M)
4. **D4** — Migrar certificado Verifactu PKCS12 a GCP Secret Manager (M)
5. **D5** — Alinear versión Flutter en codemagic.yaml, .github/workflows y entorno local (S)
6. **D6** — Sustituir `share_plus` por Resend Cloud Function para envío de facturas por email en Windows (S)

### Fase E — Mejoras de calidad y escala (post-publicación)
*Tiempo estimado: 10–15 días*

1. Agregar Mod.349 por NIF + clave de operación (formato AEAT correcto) (M)
2. Implementar Mod.200 base para el 202 (IS anual) (L)
3. Añadir exportador DR190e25v13 completo con todos los perceptores (M)
4. Full-text search en clientes (Algolia o Typesense) en lugar de full-scan (L)
5. Implementar Universal Links (iOS) y App Links (Android) para deep links seguros (M)
6. Añadir reintentos con backoff para envíos Verifactu SOAP (M)
7. DPIA para módulo de fichajes con geolocalización (L — requiere asesoría legal)
8. Implementar retención automática de fichajes (4 años, RDL 8/2019) con Cloud Scheduler (M)
9. Tests de integración Verifactu contra sandbox AEAT (M)

---

## 1.4 Esfuerzo total estimado

| Fase | Días | Descripción |
|---|---|---|
| A — Seguridad crítica | 3–5 | Imprescindible antes de Windows |
| B — AEAT / legal | 5–8 | Imprescindible antes de usar facturación |
| C — RGPD | 8–12 | Imprescindible antes de nuevas altas |
| D — Windows distribución | 5–8 | Necesario para publicar Windows |
| E — Calidad y escala | 10–15 | Post-publicación |
| **Total** | **31–48 días** | Estimado con un desarrollador |

---

# 2. Multiplataforma y publicación {#cap1}

## iOS — Estado

iOS es la plataforma más madura. La configuración de firma es correcta (perfil manual `Fluix12`, team `3AMXPPGLN8`, ExportOptions método `app-store`). App Check con `DeviceCheck`, Crashlytics activo en release, FCM con background modes configurados y `PrivacyInfo.xcprivacy` presente con las 4 API de privacidad requeridas desde 2024.

**Riesgos iOS:**
- Deployment target `17.0` en `ios/Podfile:2` excluye ~10% de usuarios con iOS 15/16. Valorar bajar a 16.0 sin coste de desarrollo significativo.
- `GoogleService-Info.plist` contiene `BUNDLE_ID = com.fluixtech.app` mientras el build real usa `com.fluixtech.crm` (`ios/Runner/GoogleService-Info.plist:12`).
- `PrivacyInfo.xcprivacy` tiene `NSPrivacyCollectedDataTypes` vacío — puede ser incorrecto dado el uso de Firebase Analytics, que recopila datos de uso del dispositivo.
- Deep links solo por esquema propio `fluixcrm://` (sin Universal Links verificados por dominio) — cualquier app puede registrar el mismo esquema.

## Android — Estado

Android está configurado para producción con keystore (`planeaguada-release.jks`), R8 activo, App Check (Play Integrity), Crashlytics vía Gradle plugin, y targetSdk=35. El CI/CD (Codemagic) produce AAB y publica en track `internal`.

**Riesgos Android:**
- `android/key.properties:1-4` contiene la contraseña del keystore en texto plano. Verificar urgentemente que está en `.gitignore`. Si fue commiteado, el keystore de producción debe considerarse comprometido.
- `android/app/build.gradle.kts:21,37` — `namespace="com.fluixcrm.crm"` vs `applicationId="com.fluixcrm.app"`. Viola la convención Gradle; puede romper en futuras versiones de AGP.
- Data Safety declaration no existe en el repositorio. Obligatoria para GPS, biometría, cámara y device ID.
- `android/app/google-services.json:12` — entrada con package `com.fluixcrm.ap` (error tipográfico).

## Windows — Estado

Windows compila pero **no es distribuible**. No existe MSIX, no hay firma de código (Authenticode), ni pipeline CI/CD. Tres crashes de runtime garantizados:

1. `mobile_scanner` sin guard de plataforma en el modal del escáner del TPV (`lib/features/tpv/pantallas/tpv_tienda_screen.dart`).
2. `cache_service.dart:38` usa sqflite sin inicializar FFI — crash al abrir el dashboard en Windows.
3. `blue_thermal_printer` puede crashear en startup si el plugin falla al inicializar sin guard.

App Check y Crashlytics están desactivados explícitamente en Windows (`lib/main.dart:85-94`), dejando la plataforma sin telemetría de errores.

## CI/CD

Versiones de Flutter desalineadas: proyecto `^3.11.1`, Codemagic `3.41.3`, GitHub Actions `3.24.0`. Los builds no son reproducibles entre entornos.

---

# 3. Módulo Web + Editorial Nazarí {#cap2}

## Arquitectura

El módulo web es un CMS headless: el contenido se gestiona en Firestore desde la app Flutter y se publica vía un SDK JavaScript generado que las webs Hostinger cargan. Para Editorial Nazarí, el módulo actúa además como tienda online completa (Stripe, Bizum, transferencia bancaria, entrega de ebooks vía token + email Resend).

La caché estática en Firebase Storage (`functions/src/nazariCache.ts`) regenera 6 ficheros JSON al detectar cambios en Firestore, con TTL de 24 horas. El CDN purge vía Cloudflare API existe (`functions/src/cdnPurge.ts`) pero no cubre las colecciones de autores ni selección Nazarí.

## SEO y analytics

El SEO gestiona title, meta description, Open Graph, robots.txt, GA4 snippet y schema.org, pero presenta dos brechas:
- Falta canonical URL, imprescindible para evitar contenido duplicado.
- Los meta tags se inyectan via JavaScript, invisibles para crawlers sin rendering JS (Googlebot los procesa, otros no).

El sistema de analytics es propio (Firestore), sin integración real con GA4. El selector de período no filtra los KPIs principales — deuda técnica importante que limita la utilidad del panel.

## Riesgos P0 de seguridad

- **API key Firebase hardcodeada en el SDK público**: la clave de acceso a Firebase está visible en el JavaScript que se sirve públicamente. Mitigado parcialmente por las reglas Firestore, pero no resuelto. Implementar App Check para el SDK web de Nazarí.
- **Endpoint `simularCompraEbook` sin autenticación**: permite simular compras y generar tokens de descarga sin pago real. Debe requerir verificación de pago antes de ejecutarse.
- **Escritura en `contenido_web` accesible a staff sin flujo editorial**: cualquier usuario con rol `staff` puede modificar contenido publicado sin aprobación.
- **Bug `if (false)` desactiva caché**: `lib/features/dashboard/pantallas/pantalla_contenido_web.dart` tiene una condición siempre falsa que desactiva la detección de módulos en caché, generando una petición HTTP en cada apertura.

## RGPD web

Los formularios de contacto y reservas generados por el SDK de Hostinger no incluyen checkbox de consentimiento informado — incumplimiento LSSI/RGPD. El banner de cookies no ha sido auditado en este análisis.

## Nazarí — cobertura funcional

| Funcionalidad | Estado |
|---|---|
| Catálogo de libros (`tab_seleccion_nazari.dart`) | Funcional |
| Autores (`pantalla_contenido_web_autores.dart`) | Funcional |
| Agenda/eventos (`tab_eventos_web.dart`) | Funcional |
| Blog/revista (`tab_blog_web.dart`, `pantalla_editor_blog.dart`) | Funcional |
| Ebooks con token de descarga (`nazariEbooks.ts`) | Funcional |
| Tienda + pasarela de pago | Funcional (Stripe, Bizum) |
| SEO por sección | Parcial (falta canonical, sitemap) |
| CDN purge autores/selección | Pendiente |

---

# 4. Fichajes (RDL 8/2019) {#cap3}

## Estado

El núcleo del módulo cumple los requisitos básicos del RDL 8/2019: arquitectura un-documento-por-jornada, `serverTimestamp` en entrada y salida (no manipulable por el cliente), correcciones trazadas en subcollección `audit_log`, y exportación CSV con cabecera de Inspección de Trabajo. Existe resumen mensual por empleado.

## Riesgos críticos

**PIN en texto plano**: el PIN numérico de verificación del fichaje se almacena directamente en `empleados_fichaje/{uid}.pin` en Firestore, sin hashing. Cualquier administrador de Firebase con acceso a la consola puede verlo. Debe aplicarse al menos SHA-256 con salt antes de almacenar.

**Subcollección `audit_log` desprotegida**: la subcollección que registra las correcciones de jornada (`corregirFichaje()`) no tiene ninguna regla Firestore. Cualquier usuario autenticado puede leer o escribir entradas de auditoría, destruyendo la integridad del registro.

**Hash SHA-256 no fiable**: el hash de integridad se calcula con `DateTime.now()` del cliente *antes* de que Firestore asigne el `serverTimestamp`. Si el reloj del dispositivo está mal sincronizado, hash y timestamp no coincidirán. No existe verificación en servidor (Cloud Function) que valide la cadena.

## Retención 4 años

El RDL 8/2019 exige conservar los registros durante 4 años y ponerlos a disposición de la Inspección de Trabajo. La UI menciona esta obligación, pero no existe ningún mecanismo técnico que la garantice: ni TTL de Firestore, ni backup programado, ni Cloud Scheduler para alertar de registros próximos a expiración.

## Biometría y firma

`local_auth` y `signature` están declarados en `pubspec.yaml` pero **no se utilizan en el flujo de fichaje**. La biometría solo cubre el login de la app. En Windows, `local_auth` devuelve `false` (no hay FaceID ni huella disponibles sin configurar Windows Hello), pero al no usarse en fichajes, este punto no es bloqueante actual.

## Geolocalización

La columna "UBICACIÓN" aparece en la UI del historial, pero el campo GPS no se captura ni se almacena en ningún campo del modelo `Fichaje`. Para activarla se necesita: solicitar permiso `geolocator`, capturar coordenadas al fichar, añadir campos `latitud`/`longitud` al modelo, y añadir guard de plataforma para Windows.

## Carpeta legacy

`lib/features/fichaje/` contiene código vivo (`PantallaFichaje`, `MisHorasMesSection`) importado por el módulo nuevo `lib/features/fichajes/`. Esta dependencia crea acoplamiento frágil y dificulta el mantenimiento.

---

# 5. Empleados, nóminas y RGPD {#cap4}

## Estado

El módulo de nóminas es funcionalmente muy completo: IRPF por CCAA, MEI, cotización de solidaridad, IT (bajas laborales), horas extra, regularización de diciembre, finiquito con artículos del ET. La baja de empleados funciona como soft-delete correcto, preservando el historial de fichajes y nóminas.

Sin embargo, el módulo tiene **tres brechas de seguridad críticas** que deben corregirse antes de cualquier publicación.

## Brecha 1 — Regla Firestore expone todos los empleados

La colección `/usuarios` tiene la regla `allow list: if isAuth() && !esAnonimo()`, que permite a **cualquier usuario autenticado del sistema** listar los documentos de usuario de todas las empresas. Esto viola el aislamiento multi-tenant y expone nombre, email, rol y empresa_id de todos los empleados de todos los tenants.

**Corrección**: cambiar la regla `list` a `allow list: if esAdminOPropietario(resource.data.empresa_id)` o similar.

## Brecha 2 — Storage sin verificación de empresa

Las reglas de Firebase Storage para documentos de empleados (contratos, nóminas en PDF, copias de DNI) solo requieren `request.auth != null`, sin verificar que el usuario pertenece a la misma empresa que el empleado. Cualquier usuario autenticado puede descargar contratos o nóminas de empleados de otras empresas.

## Brecha 3 — Creación de cuentas Auth desde cliente

El flujo de alta crea cuentas Firebase Auth directamente desde el cliente Flutter, en lugar de usar la Cloud Function `crearEmpleadoConCredenciales` diseñada para ello. Esto expone el Admin SDK indirectamente y viola el principio de mínimo privilegio.

## RGPD

- `_eliminarEmpleado()` borra el documento Firestore pero deja la cuenta Auth activa, los archivos en Storage sin referencia, y no cumple el art. 17 RGPD (derecho de supresión completo).
- DNI, NSS, IBAN, porcentaje de discapacidad, estado civil e hijos se almacenan en el documento principal del usuario, sin segregación por nivel de sensibilidad.
- No existe mecanismo de portabilidad ni política de retención para empleados dados de baja.
- Los tokens de invitación tienen campo `expira` pero las reglas Firestore no lo validan — tokens expirados permanecen usables si la app no valida.

## Bug: reversión de baja

Al reactivar un empleado dado de baja, el saldo de vacaciones no se descongela correctamente. Bug localizado en `baja_empleado_service.dart`.

---

# 6. Clientes, multi-tenant y RGPD {#cap5}

## Estado

El CRM de clientes tiene funcionalidades avanzadas: detección de clientes silenciosos, fusión de duplicados, importación CSV, exportación, fidelización y automaciones. El aislamiento multi-tenant es correcto estructuralmente (colección `empresas/{id}/clientes/{id}`).

## Brechas críticas

**Datos de salud sin base legal**: el campo `preferencias/alergias` puede contener datos de salud, que son datos de categoría especial bajo el art. 9 RGPD. No existe campo de consentimiento explícito ni base legal documentada en el modelo `Cliente`.

**CF cross-tenant**: `recalcularStatsCliente` (callable Cloud Function en `functions/src/automaciones_clientes.ts`) verifica autenticación pero no que el caller pertenezca a la misma empresa del cliente. Un usuario de empresa A podría invocar la función con un clienteId de empresa B.

**Borrado incompleto**: `_eliminarCliente()` borra solo el documento raíz. Las subcolecciones (`interacciones`, `actividad`, `_fusion_snapshot`) y las referencias en facturas y reservas permanecen intactas, incumpliendo el derecho de supresión del RGPD.

**Importación CSV sin consentimiento**: `importar_csv_screen.dart` permite crear miles de contactos sin ningún paso de validación de consentimiento previo, exponiendo a la empresa al riesgo de sanciones AEPD.

## Bugs del modelo de datos

- `toFirestore()` escribe el campo `estado_cliente`, pero `fromFirestore()` lee `estado`. Los clientes actualizados con `toFirestore` aparecen sin estado en consultas.
- `upsertClienteDesdeReserva()` incrementa `num_reservas`, pero el campo real del modelo es `numero_reservas`.
- Estos bugs producen datos silenciosamente incorrectos sin error en runtime.

## Rendimiento

`buscarOCrearCliente` en Cloud Functions hace un `col.get()` completo (full-scan) para búsquedas por teléfono y nombre. Con empresas de más de 500 clientes, el coste y la latencia aumentan linealmente. Se necesita índice en `telefono` y `correo` + query `.where()`.

---

# 7. Facturación y Verifactu {#cap6}

## Estado del ciclo de facturación

El módulo de facturación está completo para el ciclo ordinario: alta, edición, rectificativa (R1–R5 según art. 15 RD 1619/2012), albaranes recibidos, facturas recurrentes y contabilidad. El modelo `Factura` contiene todos los campos obligatorios del RD 1619/2012.

## Verifactu — arquitectura

La arquitectura es correcta: hash SHA-256 encadenado, modelos canónicos (`modelos_verifactu.dart`), Cloud Function para firma XAdES-BES (`firmarXMLVerifactu.ts`) y otra para remisión SOAP a AEAT (`remitirVerifactu.ts`) con mTLS. El certificado PKCS12 se almacena en `flutter_secure_storage`.

**Sin embargo, 3 bloqueantes técnicos impiden operar Verifactu en producción:**

### Bloqueante 1 — Hash SHA-256 incorrecto
`modelos_verifactu.dart:213` incluye el campo `descripcion` en la concatenación de la huella digital. La Orden HAC/1177/2024, Bloque 6, no incluye este campo. Cualquier registro enviado con este hash será rechazado por la AEAT. **Corrección S**: eliminar esa línea y regenerar los registros de prueba.

### Bloqueante 2 — C14N falsa
`firma_xades_pkcs12_service.dart:785–795` implementa una canonicalización XML simplificada que solo elimina la declaración XML y hace unescaping. No es C14N real (RFC 3076). La misma brecha existe en `firmarXMLVerifactu.ts:194`. Una firma con C14N incorrecta es inválida para cualquier validador XMLDSig. **Corrección M**: implementar C14N conforme usando el package `xml` con recorrido ordenado de atributos.

### Bloqueante 3 — Rectificativas no encadenadas
`formulario_rectificativa_screen.dart` no llama al flujo Verifactu al guardar. Los registros de anulación/rectificativa no se añaden a la cadena, rompiendo la secuencia requerida por el art. 6 RD 1007/2023. **Corrección S**: añadir llamada a `HashChainService.construirRegistroAlta` en `FacturacionService.crearFacturaRectificativa`.

## Otros riesgos altos

- Escritura de cadena Firestore sin transacción (`hash_chain_service.dart:27–50`) — colisión de hash posible en concurrencia.
- Certificado PKCS12 + contraseña en Firestore en texto plano en lugar de GCP Secret Manager (`firmarXMLVerifactu.ts:74`).
- Stripe `redirectUri` hardcodeado como `https://tudominio.com/stripe/callback` (`stripe_service.dart:9`) — OAuth Connect no funciona.

## Cumplimiento Verifactu: 10/16 ítems
Los plazos normativos están correctamente implementados en `PoliticaVerifactu2027`: IS desde 01/01/2027, resto de contribuyentes desde 01/07/2027. Hay margen para corregir los 3 bloqueantes antes de las fechas límite, pero no deben quedar pendientes.

---

# 8. Modelos fiscales AEAT {#cap7}

## Estado general

Están implementados 10 modelos: 111, 115, 130, 180, 190, 202, 303, 347, 349 y 390. La arquitectura es sólida: pantallas, calculadoras en `lib/services/fiscal/`, exportadores posicionales en `lib/services/exportadores_aeat/`, y lógica equivalente en `functions/src/fiscal/`. Los exportadores 111 (DR111e16v18) y 115 (DR115e15v13) son correctos. El builder del 390 es correcto.

Sin embargo, hay **dos bugs críticos** que producen declaraciones fiscalmente incorrectas:

## Bug crítico 1 — Mod.303: tipos de IVA invertidos

La función `_construirCasillas` asigna:
- Casilla `[01]` ← `base_reducida` (10%) — **incorrecto**: la casilla 01 corresponde al tipo superreducido del 4%
- Casilla `[04]` ← `base_general` (21%) — **incorrecto**: la casilla 04 corresponde al tipo reducido del 10%

El modelo oficial AEAT asigna: 01=4%, 04=10%, 07=21%. Cualquier fichero exportado con este bug declara tipos de IVA incorrectos, lo que constituye una declaración tributaria inexacta. **Corrección S**: mapear correctamente los tipos a sus casillas.

## Bug crítico 2 — Mod.390: colección incorrecta

`Mod390PosicionalService` verifica la existencia de los 4 modelos 303 del año consultando la colección `modelos303`, que no existe. Los Mod.303 se guardan en `modelos_fiscales`. Como resultado, el cruce anual es imposible, la alerta "sin 303" aparece siempre, y el resumen anual de IVA no puede generarse correctamente. **Corrección S**: cambiar el nombre de colección.

## Otros déficits

| Modelo | Problema |
|---|---|
| **190** | Sin exportador posicional DR190e25v13 — presentación telemática inviable con >10 empleados |
| **349** | Lista facturas individuales en lugar de registros resumen por NIF+clave — incumple formato AEAT |
| **202** | Siempre base 0 (depende de Mod.200 no implementado) |
| **Historial** | No encuentra Mod.303 por mismatch `Q1..Q4` vs `1T..4T` en los IDs de documento |

## Exportación en Windows

`Share.shareXFiles` vuelca el fichero en `%TEMP%` sin botón "Guardar en disco". En iOS/Android funciona correctamente. En Windows se debe usar un selector de ruta con `path_provider` + `file_picker`.

---

# Capítulo transversal — Publicación multiplataforma

## Semáforo de readiness por plataforma y módulo

| | iOS | Android | Windows |
|---|---|---|---|
| **Publicable hoy** | 🟡 Con correcciones S | 🟡 Con correcciones S | ❌ No |
| **Seguridad aislamiento** | 🔴 Reglas Storage | 🔴 Reglas Storage | 🔴 Reglas Storage |
| **RGPD** | 🔴 Borrado incompleto | 🔴 Borrado incompleto | 🔴 Borrado incompleto |
| **Verifactu** | 🔴 3 bloqueantes | 🔴 3 bloqueantes | 🔴 3 bloqueantes |
| **Modelos AEAT** | 🔴 303, 390 bugs | 🔴 303, 390 bugs | 🔴 303, 390 + exportación |
| **TPV / escáner** | 🟢 OK | 🟢 OK | 🔴 Crash garantizado |
| **Facturación ciclo** | 🟢 OK | 🟢 OK | 🟡 Email roto |
| **Web + Nazarí** | 🟢 Funcional | 🟢 Funcional | 🟢 Funcional |

## Plugins críticos por plataforma

| Plugin | iOS | Android | Windows |
|---|---|---|---|
| `mobile_scanner` | ✅ | ✅ | ❌ Sin guard — crash |
| `blue_thermal_printer` | ✅ | ✅ | ❌ Sin guard — posible crash startup |
| `local_auth` | ✅ FaceID/Touch | ✅ Huella | ⚠️ Windows Hello (requiere config) |
| `geolocator` | ✅ | ✅ | ✅ vía geolocator_windows |
| `flutter_pdfview` | ✅ | ✅ | ❌ Guard `isMobile` presente — OK |
| `sqflite` (cache) | ✅ | ✅ | ❌ FFI no inicializado en cache_service |
| `share_plus` | ✅ | ✅ | ⚠️ No abre cliente email fiablemente |
| `audioplayers` | ✅ | ✅ | ✅ |

---

# Anexo — Rutas de fichero citadas {#anexo}

| Fichero | Línea(s) | Módulo | Descripción del problema |
|---|---|---|---|
| `android/app/build.gradle.kts` | 21, 37 | Multiplataforma | namespace ≠ applicationId |
| `android/key.properties` | 1–4 | Multiplataforma | Contraseña keystore texto plano |
| `android/app/google-services.json` | 12 | Multiplataforma | Package incompleto `com.fluixcrm.ap` |
| `android/app/src/main/AndroidManifest.xml` | 46–51 | Multiplataforma | Deep links solo esquema propio |
| `ios/Podfile` | 2, 45 | Multiplataforma | Deployment target 17.0 |
| `ios/Runner/GoogleService-Info.plist` | 12 | Multiplataforma | BUNDLE_ID incorrecto |
| `lib/main.dart` | 59–80, 85–94 | Multiplataforma | Crashlytics/App Check desactivados Windows |
| `lib/services/cache_service.dart` | 38 | Multiplataforma | sqflite sin FFI en Windows |
| `lib/features/tpv/pantallas/tpv_tienda_screen.dart` | — | Multiplataforma | mobile_scanner sin guard Windows |
| `firestore.rules` | (regla usuarios list) | Empleados | Expone empleados de todas las empresas |
| `storage.rules` | (docs empleados) | Empleados | Sin verificación de empresa |
| `lib/features/empleados/pantallas/formulario_empleado_form.dart` | — | Empleados | Crea Auth desde cliente |
| `lib/services/baja_empleado_service.dart` | — | Empleados | Bug reversión vacaciones |
| `modelos_verifactu.dart` | 213 | Facturación | Campo `descripcion` en hash SHA-256 |
| `firma_xades_pkcs12_service.dart` | 785–795 | Facturación | C14N simplificada — firma inválida |
| `firmarXMLVerifactu.ts` | 74, 194 | Facturación | C14N + contraseña en texto plano |
| `remitirVerifactu.ts` | 69 | Facturación | Contraseña certificado en texto plano |
| `hash_chain_service.dart` | 27–50, 109–128 | Facturación | Sin transacción Firestore |
| `aeat_remision_service.dart` | 1–57 | Facturación | Placeholder sin envío real |
| `stripe_service.dart` | 9 | Facturación | redirectUri hardcodeado |
| `lib/features/fiscal/pantallas/modelo303_screen.dart` | — | AEAT | Tipos IVA invertidos en casillas |
| `lib/services/fiscal/mod390_posicional_service.dart` | — | AEAT | Colección `modelos303` incorrecta |
| `lib/features/fichajes/servicios/fichaje_service.dart` | — | Fichajes | PIN texto plano |
| `firestore.rules` | (audit_log sin regla) | Fichajes | audit_log sin protección |
| `functions/src/automaciones_clientes.ts` | — | Clientes | CF cross-tenant sin verificación empresa |
| `lib/features/clientes/pantallas/modulo_clientes_screen.dart` | — | Clientes | Borrado incompleto RGPD |
| `lib/domain/modelos/cliente.dart` | — | Clientes | toFirestore/fromFirestore desincronizados |
| `lib/features/dashboard/pantallas/pantalla_contenido_web.dart` | — | Web | `if (false)` desactiva caché |

---

*Análisis generado en modo solo lectura. Fluix CRM v1.0.18 · Rama main · 2026-10-26*
*Fluix Tech, S.L.*

# 06 — Facturación y Verifactu

_Análisis en modo solo lectura — octubre 2026_

---

## Estado actual

El módulo de facturación está estructuralmente completo para el ciclo ordinario (alta, edición, rectificativa, albaranes recibidos). El sub-sistema Verifactu tiene una arquitectura bien diseñada con encadenamiento SHA-256, firma XAdES-BES vía Cloud Function y remisión SOAP a AEAT, pero presenta brechas críticas que impiden considerarlo conforme en producción.

### Qué funciona

- Modelo `Factura` con todos los campos obligatorios del RD 1619/2012 (número, serie, fecha, NIF emisor/receptor mediante `DatosFiscales`, base imponible, tipo IVA, cuota, total, IRPF, recargo equivalencia).
- Facturas rectificativas con `facturaOriginalId`, `facturaOriginalNumero`, `facturaOriginalFecha`, `MotivoRectificacion`, `MetodoRectificacion`, mapeados a códigos AEAT R1–R5 (art. 15 RD 1619/2012).
- Encadenamiento SHA-256 (`modelos_verifactu.dart`) con primer registro marcado, campos concatenados según Bloque 6 RD 1007/2023 y `CadenaFacturacion.validarEncadenamiento()` en memoria.
- Firma XAdES-BES implementada en dos capas: cliente (`FirmaXadesPkcs12Service`, puro Dart con `pointycastle`/`asn1lib`) y Cloud Function (`firmarXMLVerifactu.ts`, `node-forge`), con soporte FNMT 3DES y RC2.
- Cloud Function `remitirVerifactu.ts` con endpoints AEAT producción/pruebas correctos, mTLS con certificado PKCS12, parseo CSV de la respuesta y persistencia del estado en Firestore.
- Certificado PKCS12 almacenado vía `flutter_secure_storage` (Keychain iOS / KeyStore Android).
- QR generado con `qr_flutter`, nivel M, URL `https://cotejoadministrativo.aeat.es/verifactu` con 4 parámetros (nif, numero, fecha, importe).
- `AeatRemisionService` encola XMLs en Firestore como respaldo (cola_verifactu).
- Stripe Connect integrado para tienda online; PayPal y Bizum presentes como valores de enum `MetodoPagoFactura`.
- `TabAlbaranesRecibidos` implementado y funcional como widget independiente.

---

## Riesgos

| Nivel | Descripción | Fichero:Línea |
|-------|-------------|---------------|
| **CRÍTICO** | El hash de `RegistroFacturacionAlta` incluye el campo `descripcion` en la cadena SHA-256, pero la Orden HAC/1177/2024 Bloque 6 NO incluye ese campo en los campos de huella. Huellas incorrectas causan rechazo AEAT. | `modelos_verifactu.dart:213` |
| **CRÍTICO** | La canonicalización C14N en el cliente Flutter es una reimplementación simplificada que solo elimina XML declaration y hace unescaping de entidades. No es C14N real (RFC 3076). Cualquier atributo fuera de orden o namespace implícito invalida la firma. | `firma_xades_pkcs12_service.dart:785–795` |
| **CRÍTICO** | La Cloud Function `firmarXMLVerifactu.ts` firma el `SignedInfo` sin canonicalizarlo (`md.update(Buffer.from(signedInfo, "utf8")...)`). Según XMLDSig (RFC 3275) el SignedInfo debe ser canonicalizado antes de firmar. | `firmarXMLVerifactu.ts:194` |
| **CRÍTICO** | `AeatRemisionService` es un placeholder: no hace envío real SOAP. El flujo efectivo pasa por `VerifactuFlowService` → Cloud Functions, pero no hay reintento automático ni control del parámetro `t` (máx. 1000 registros/envío, art. 9 RD 1007/2023). | `aeat_remision_service.dart:1–57` |
| **ALTO** | La cadena se verifica en memoria (`CadenaFacturacion.validarEncadenamiento()`) pero no existe verificación persistente de la cadena Firestore completa antes de añadir un nuevo registro. Si dos procesos concurrentes consultan `obtenerUltimoHash` simultáneamente, pueden encadenar sobre el mismo hash anterior, rompiendo la cadena. Firestore necesita una transacción. | `hash_chain_service.dart:27–50, 109–128` |
| **ALTO** | El QR usa URL `https://cotejoadministrativo.aeat.es/verifactu`. Esta URL es provisional y no estaba publicada de manera definitiva por la AEAT en octubre 2026. Verificar cuando la AEAT publique el endpoint real. | `generador_qr_verifactu.dart:14` |
| **ALTO** | La Cloud Function almacena la contraseña del PKCS12 en texto plano en Firestore (`certData.password`). Debe usar Secret Manager (Firebase Extensions o GCP Secret Manager). | `firmarXMLVerifactu.ts:74`, `remitirVerifactu.ts:69` |
| **ALTO** | La rectificativa crea una nueva entrada en la cadena Verifactu con tipo R1–R5, pero en `formulario_rectificativa_screen.dart` no se llama a ningún flujo Verifactu al guardar. El registro Verifactu de la rectificativa depende de que `FacturacionService.crearFacturaRectificativa` lo haga, pero el README advierte que aún es pendiente. | `README_VERIFACTU_FASE2.md:186–216` |
| **MEDIO** | Validador `ValidadorVerifactu.validarRegistroAlta` incluye control de precisión temporal (diferencia ≤ 60 s), pero ese valor es más restrictivo que el texto del art. 29.2.j LGT. Un reloj de servidor desincronizado o carga alta podría rechazar registros legítimos. | `validador_verifactu.dart:52–60` |
| **MEDIO** | El `StripeService` tiene `redirectUri = 'https://tudominio.com/stripe/callback'` hardcodeado. El callback OAuth de Stripe Connect nunca llegará. | `stripe_service.dart:9` |
| **MEDIO** | El estado de pago Stripe no escribe de vuelta sobre el campo `estado` / `fechaPago` de la `Factura`. La sincronización depende de una Cloud Function `onProductoWrite` referenciada pero no visible en el árbol Verifactu. | `stripe_service.dart:101–108` |
| **BAJO** | Primer registro de cadena usa hash `'0' * 64`. La especificación técnica AEAT podría exigir campo `PrimerRegistro='S'` sin incluir bloque `EncadenamientoFacturaAnterior`. El XML builder omite correctamente el bloque, pero la validación `esPrimerRegistro` comprueba el hash relleno de ceros, lo cual es una convención interna no normativa. | `xml_payload_verifactu_builder.dart:36–47` |
| **BAJO** | `TabAlbaranesRecibidos` necesita `ContabilidadService` inyectado por el padre. Si se instancia desde un punto del sidebar que no pase el servicio, fallará en runtime. Verificar registro en el sidebar. | `tab_albaranes_recibidos.dart:7–17` |

---

## Diferencias por plataforma

### iOS / Android
- `flutter_secure_storage` funciona correctamente (Keychain/KeyStore).
- La firma XAdES en cliente (`FirmaXadesPkcs12Service`) usa solo Dart puro, por lo que es compatible.
- `qr_flutter` soporta iOS y Android sin restricciones.
- El envío Stripe por email no aplica (la tienda online usa la web Stripe directamente).

### Windows
- `flutter_secure_storage` usa `EncryptedSharedPreferences` solo en Android. En Windows, el backend es Windows Credential Manager. La contraseña del PKCS12 se guarda igualmente cifrada, pero hay que verificar que `flutter_secure_storage` ^9.x incluya el plugin de Windows. Si falta, el certificado no se carga.
- El envío por email desde Windows depende de `share_plus` (para adjuntar el PDF) o de servicios de email en Cloud Functions. `share_plus` no abre el cliente de correo de manera fiable en Windows desktop: se recomienda usar la Cloud Function de Resend ya existente (`resend_service.dart`) en lugar de `share_plus`.
- La generación de PDF con el package `pdf` no requiere impresora y funciona en Windows sin restricciones.
- La firma XAdES vía Cloud Function (`VerifactuFlowService`) es indiferente a la plataforma cliente porque la operación ocurre en el servidor.

---

## Cumplimiento legal

| Norma | Artículo | Estado | Observación |
|-------|----------|--------|-------------|
| RD 1619/2012 | Art. 6 — campos obligatorios | Cumple | Modelo `Factura` contiene todos los campos |
| RD 1619/2012 | Art. 15 — rectificativas | Cumple parcialmente | El formulario es correcto; la integración Verifactu de la rectificativa está pendiente |
| RD 1007/2023 | Art. 6 — registros de alta | Implementado con bug | Bug en campo `descripcion` incluido en hash |
| RD 1007/2023 | Art. 6 — registros de anulación | Implementado | `RegistroFacturacionAnulacion` completo |
| RD 1007/2023 | Art. 9 — remisión a AEAT | Parcialmente | Cloud Function existe; sin reintentos ni control del parámetro `t` |
| RD 1007/2023 | Art. 12 — firma NO VERI*FACTU | Implementado con bug | C14N simplificada invalida la firma en casos extremos |
| RD 1007/2023 | Art. 16.3 — exoneración firma VERI*FACTU | Correcto | `aplicarFirmaSegunModo` devuelve XML sin firmar cuando `esVerifactu=true` |
| Orden HAC/1177/2024 | Esquema XML | Implementado | Namespace correcto; estructura `SuministroLRFacturasEmitidas` correcta |
| Orden HAC/1177/2024 | QR con 4 parámetros | Implementado | URL, nif, numero, fecha, importe |
| Art. 201 bis LGT | Sanciones hasta 150.000 EUR productor | Documentado | `Lgt201BisRiesgos` cataloga riesgos |
| RDL 15/2025 | Plazos 2027 | Correcto | `PoliticaVerifactu2027` refleja IS=2027-01-01, resto=2027-07-01 |

---

## Deuda técnica

1. **Hash incorrecto**: el campo `descripcion` en la concatenación SHA-256 no corresponde al Bloque 6 del RD 1007/2023. Eliminar esa línea y regenerar todos los registros de prueba.
2. **C14N real**: sustituir la canonicalización simplificada por una librería C14N conforme a RFC 3076. En Dart, considerar `xml` package con recorrido en orden de atributos.
3. **Transacción Firestore en escritura de cadena**: envolver `obtenerReferenciaAnterior` + `guardarRegistroAlta` en una transacción Firestore para evitar condiciones de carrera en multi-empresa concurrente.
4. **Certificado en Secret Manager**: mover `p12Base64` y `password` de Firestore a GCP Secret Manager y acceder desde las Cloud Functions con `firebase-admin` Secret Manager API.
5. **Reintentos SOAP con backoff**: añadir cola de reintentos (Cloud Tasks o Firestore TTL trigger) para registros con estado `pendiente` o `error_red`.
6. **Integración rectificativa → Verifactu**: la llamada a `HashChainService.construirRegistroAlta` y `guardarRegistroAlta` debe añadirse a `FacturacionService.crearFacturaRectificativa`.
7. **Stripe redirect URI**: sustituir `tudominio.com` por el dominio real de producción.
8. **Sincronización estado pago**: crear o verificar la Cloud Function que escucha webhooks Stripe y actualiza `estado`/`fechaPago` en la colección `facturas`.
9. **Tab albaranes recibidos**: confirmar registro de `TabAlbaranesRecibidos` en la ruta del sidebar con el `ContabilidadService` inyectado.
10. **Tests de integración Verifactu**: los tests unitarios existen en `test/verifactu_hash_chain_test.dart` pero no hay tests de integración contra el sandbox AEAT.

---

## Lista priorizada de acciones

| Prioridad | Acción | Esfuerzo |
|-----------|--------|----------|
| 1 — Bloquea producción | Corregir campos concatenados en `calcularHash()`: eliminar `descripcion` del hash SHA-256 | S |
| 2 — Bloquea producción | Implementar C14N real en `firma_xades_pkcs12_service.dart` y en `firmarXMLVerifactu.ts` | M |
| 3 — Bloquea producción | Envolver escritura de cadena en transacción Firestore en `HashChainService` | S |
| 4 — Seguridad crítica | Migrar `p12Base64`/`password` de Firestore a GCP Secret Manager | M |
| 5 — Cumplimiento legal | Llamar al flujo Verifactu desde `FacturacionService.crearFacturaRectificativa` | S |
| 6 — Fiabilidad | Añadir reintentos con backoff exponencial para envíos SOAP fallidos | M |
| 7 — Integración | Verificar/crear Cloud Function que sincroniza webhooks Stripe → estado factura | M |
| 8 — UX/Plataforma | Sustituir `share_plus` por Resend Cloud Function para envío de PDF en Windows | S |
| 9 — Configuración | Actualizar `redirectUri` de Stripe Connect con dominio real | S |
| 10 — Test | Ejecutar suite de pruebas en sandbox AEAT (entorno `pruebas`) con certificado de prueba | L |
| 11 — Verificación | Confirmar URL QR oficial AEAT cuando la publiquen y actualizar constante | S |
| 12 — UI | Registrar `TabAlbaranesRecibidos` con `ContabilidadService` en el sidebar | S |

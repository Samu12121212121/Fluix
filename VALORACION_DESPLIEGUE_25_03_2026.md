# 🚀 VALORACIÓN GLOBAL PARA DESPLIEGUE — Fluix CRM
**Fecha:** 25 de marzo de 2026
**Basado en:** revisión completa del código fuente real
**Proyecto:** `planeag_flutter` — Firebase ID: `planeaapp-4bea4`

---

## 📊 RESUMEN EJECUTIVO

| Módulo | Nota | Estado | Bloquea despliegue |
|--------|------|--------|--------------------|
| 🔐 Autenticación | **78/100** | 🟢 Funcional | No |
| 📝 Registro / Onboarding | **55/100** | 🟠 Básico | No |
| 📊 Dashboard | **80/100** | 🟢 Completo | No |
| 📅 Reservas | **85/100** | 🟢 Muy completo | No |
| 📅 Citas | **40/100** | 🔴 Solo wrapper | No (avisado) |
| 👥 Clientes | **62/100** | 🟡 Funcional | No |
| ⭐ Valoraciones | **68/100** | 🟡 Parcial | No |
| 📈 Estadísticas | **70/100** | 🟡 Con caché | No |
| 🛒 Pedidos / Catálogo | **74/100** | 🟢 Completo | No |
| 💬 WhatsApp Bot | **45/100** | 🔴 Sin API real | **Sí** |
| ✅ Tareas | **72/100** | 🟡 Kanban funcional | No |
| 👨‍💼 Empleados | **80/100** | 🟢 Muy completo | No |
| 💰 Facturación | **78/100** | 🟢 Completo | No |
| 📒 Contabilidad | **68/100** | 🟡 Parcial | No |
| 🧾 Fiscal (Modelos AEAT) | **72/100** | 🟢 Completo en UI | No |
| ☁️ VeriFactu | **55/100** | 🟠 Hash chain OK, envío AEAT no | No (plazo 2027) |
| 💵 Nóminas | **88/100** | 🟢 Muy completo | No |
| 📋 Finiquitos | **82/100** | 🟢 Completo | No |
| 🏖️ Vacaciones | **75/100** | 🟢 Funcional | No |
| 💳 Suscripción | **30/100** | 🔴 Sin cobro real | **Sí** |
| 🔔 Notificaciones (FCM) | **72/100** | 🟢 Implementado | No |
| ☁️ Cloud Functions | **65/100** | 🟡 Errores sin desplegar | **Sí** |
| 🔒 Firestore Rules | **70/100** | 🟡 1 vulnerabilidad activa | **Sí** |
| 🧪 Testing | **25/100** | 🔴 Solo unitarios | No |
| 🔑 Keystore Android | **90/100** | 🟢 Generado | No |

**NOTA MEDIA GLOBAL: 67/100**
**ESTADO:** 🟠 Lanzable con ajustes críticos — estimado 3-5 días de trabajo

---

## 🔴 BLOQUEANTES — Deben resolverse ANTES del despliegue

### 1. Cloud Functions — Errores TypeScript sin resolver

**Problema:** Las functions tienen errores de compilación que impiden el deploy.
- `src/index.ts` → `EmailService` importado pero nunca usado
- `src/index.ts` → Stripe API version `'2025-02-24.acacia'` inválida (cambiar a `'2024-06-20'`)
- `src/notificacionesTareas.ts` → imports `Change`, `FirestoreEvent`, `DocumentSnapshot` no usados
- `src/recordatoriosCitas.ts` → usa `admin.firestore()` antes de `initializeApp()`
- `onNuevaReserva` fue desplegada como **Gen 1** — hay que eliminarla en Firebase Console antes de re-desplegar en Gen 2

**Impacto:** Sin functions desplegadas: sin notificaciones push, sin recordatorios de citas, sin procesamiento de pagos.

**Solución:**
```bash
# 1. Corregir TS, luego:
firebase functions:delete onNuevaReserva --region europe-west1 --force
firebase deploy --only functions
```

---

### 2. Suscripción — No hay cobro automático

**Problema real verificado en código:**
- `PantallaSuscripcionVencida._contactarRenovacion()` abre un **AlertDialog** con email y teléfono — **no hay Stripe**.
- No hay `flutter_stripe` en `pubspec.yaml`.
- No hay `createPaymentIntent`, `createSubscription` ni webhook Stripe en `functions/src/index.ts`.
- El documento `/empresas/{id}/suscripcion` está con `allow write: if false` — correcto, pero no hay ningún proceso que lo actualice automáticamente.

**Impacto crítico para el negocio:** El app no cobra a los clientes. Toda la monetización depende de gestión manual.

**Para despliegue mínimo viable:** Activar suscripciones manualmente desde Firestore Console y avisar a los clientes que el pago es por transferencia/bizum. Documentar esto.

---

### 3. Firestore Rules — Vulnerabilidad de escritura pública

**Problema real verificado en `firestore.rules` línea ~185:**
```
match /estadisticas/{docId}/{subcol}/{subId} {
  allow read: if true;
  allow write: if true;  // ← CUALQUIERA puede escribir estadísticas
}
```
**Impacto:** Un atacante puede corromper o inflar estadísticas de cualquier empresa.

**Fix inmediato (1 línea):**
```
allow write: if perteneceAEmpresa(empresaId);
```

---

### 4. WhatsApp Bot — Solo Firestore, sin API Business real

**Problema real verificado en código:**
- `ChatbotService` solo lee/escribe en Firestore (`empresas/{id}/chats`, `bot_respuestas`, `configuracion/bot`).
- **No hay webhook HTTP** en `functions/src/index.ts` que reciba mensajes de WhatsApp Business API.
- La UI de chat (`pantalla_chats_bot.dart`) muestra conversaciones almacenadas en Firestore, pero ningún mensaje llega desde WhatsApp real.

**Para despliegue:** O se desactiva el módulo WhatsApp del plan, o se avisa claramente que es un chatbot interno (no conectado a WhatsApp).

---

## 🟠 IMPORTANTES — Afectan UX y legalidad

### 5. Citas — Solo un wrapper de Reservas (27 líneas)

**Problema real verificado:**
```dart
// modulo_citas.dart — COMPLETO
class ModuloCitas extends StatelessWidget {
  Widget build(BuildContext context) {
    return ModuloReservas(
      collectionId: 'citas',  // Solo cambia la colección
      moduloSingular: 'Cita',
    );
  }
}
```
**Lo que falta para ser un módulo propio:**
- Gestión de profesionales/disponibilidad
- Recordatorio push 24h antes (Cloud Function existe en `recordatoriosCitas.ts` pero no desplegada)
- Vista dedicada con duración de servicio, notas internas

**Para despliegue:** Funciona para uso básico (CRUD de citas). Marcar como "Beta" en el plan.

---

### 6. Tareas — Vista calendario es código muerto (visible al usuario)

**Problema real verificado:**
```dart
int _vistaActual = 0; // 0=kanban, 1=lista, 2=calendario

// El toggle solo alterna entre 0 y 1:
onPressed: () => setState(() => _vistaActual = _vistaActual == 0 ? 1 : 0),
```
El valor `2=calendario` nunca se alcanza. `table_calendar` sí está en `pubspec.yaml` pero no se usa en Tareas (sí se usa en Reservas/Citas correctamente).

**Fix rápido:** Eliminar el comentario `// 2=calendario` y el valor del enum, o implementarlo.

---

### 7. Facturación — No envía emails + sin protección anti-huecos

**Problemas verificados:**
- **Email:** No hay ninguna llamada a `EmailService` ni a Cloud Function de email desde `ModuloFacturacionScreen` o `DetalleFacturaScreen`. Las facturas se generan en PDF pero no se pueden enviar desde la app.
- **Anti-huecos:** No existe ningún mecanismo de numeración correlativa protegida. El usuario puede crear facturas con cualquier número. En España esto puede ser sancionado (art. 6 RD 1619/2012).

**Para despliegue:** Añadir botón "Enviar por email" que llame a Cloud Function. Para numeración: implementar contador atómico en Firestore.

---

### 8. Empleados — God Widget de 3.021 líneas (riesgo de bugs)

**Problema real verificado:**
- `modulo_empleados_screen.dart` tiene **3.021 líneas** — todo en un solo archivo.
- Incluye: CRUD empleados, nóminas, finiquitos, embargos, vacaciones, foto de perfil, convenio.
- Riesgo alto: modificar cualquier sección puede romper otra.

**Para despliegue:** Funciona, pero cualquier corrección de bug tarda más. No es bloqueante pero es deuda técnica alta.

---

### 9. VeriFactu — XML generado, envío AEAT es placeholder

**Problema real verificado en `aeat_remision_service.dart`:**
```dart
/// ⏳ PLACEHOLDER — Envío SOAP real previsto para Q3 2026 (W7 del roadmap).
/// Por ahora almacena el XML en Firestore para procesarlo en background.
```
- El hash encadenado SHA-256 ✅ funciona
- El QR Verifactu ✅ funciona
- El XML payload ✅ se genera
- **Firma XAdES**: `firma_xades_pkcs12_service.dart` tiene errores de compilación no resueltos (API de `asn1lib` incompatible)
- **Envío SOAP a AEAT**: Solo encola en Firestore. No hay Cloud Function que lo envíe.

**Para despliegue:** No es obligatorio hasta **1-Jul-2027** (RDL 15/2025). Puede desplegarse en modo "No VeriFactu" indicando al cliente que se activará en 2027.

---

### 10. Exportadores AEAT — Encoding no explícito (riesgo ISO-8859-1)

**Problema real verificado:**
- `mod_349_exporter.dart` importa `dart:typed_data` pero genera strings sin conversión explícita a ISO-8859-1.
- `mod_347_exporter.dart` no tiene ningún import de encoding.
- La AEAT exige ISO-8859-1 en formatos posicionales (MOD 347, 349).
- Dart usa UTF-8 por defecto → caracteres como `ñ`, `á`, `ü` se corrompen en el fichero exportado.

**Fix:**
```dart
import 'dart:convert';
// Al generar el fichero:
final bytes = latin1.encode(contenido);  // en vez de utf8.encode()
```

---

## 🟡 MEJORAS RECOMENDADAS (no bloquean despliegue)

### 11. Login — Falta recuperar contraseña

La pantalla de login importa `sign_in_with_apple` y `google_sign_in` pero **no hay botón visible de "Olvidé mi contraseña"** (no encontrado en revisión de 805 líneas). Firebase Auth tiene `sendPasswordResetEmail()` — añadirlo tarda 20 minutos.

### 12. Onboarding — Sin selección de plan al registrarse

`pantalla_onboarding.dart` configura empresa pero no ofrece selección de plan (Básico 300€/año, Pro, etc.). El plan se asigna manualmente en Firestore.

### 13. Clientes — Sin historial de facturas integrado

`modulo_clientes_screen.dart` tiene CRUD de clientes pero no muestra el historial de facturas por cliente desde la ficha. Los servicios están implementados pero no conectados en UI.

### 14. Google Reviews — Sin reply real

`google_reviews_service.dart` existe pero la API de respuesta a reseñas de Google requiere **Google Business API OAuth2** — no configurada. La UI muestra reseñas pero el botón "Responder" probablemente no funciona.

### 15. Testing — Solo tests unitarios fiscales

17 tests unitarios (fiscal/verifactu) pasan correctamente. Sin embargo:
- No hay tests de widgets de ninguna pantalla principal
- No hay tests de integración con Firebase Emulator
- Sin tests de flujo de login/registro

---

## ✅ LO QUE SÍ FUNCIONA BIEN (listo para producción)

| Componente | Detalle |
|-----------|---------|
| **Login** | Email/password + Google Sign-In + Apple Sign-In (pubspec + servicio) |
| **Reservas** | CRUD completo, calendar view con `table_calendar`, notificaciones push |
| **Nóminas** | SS 2026 correcto (MEI 0.90%, base máx 5.101,20€), IRPF CLM 5 tramos, 5 convenios |
| **Finiquitos** | Cálculo ET arts. 49-53, PDF BOE, tests pasando |
| **Vacaciones** | Solicitudes, aprobación, descuento en nómina |
| **Facturación** | CRUD completo, PDF profesional, rectificativas, facturas recibidas |
| **Modelos AEAT UI** | MOD 111, 115, 130, 303, 347, 349, 390 — pantallas funcionales |
| **MOD 303** | DR303e26v101 exporter nuevo formato 2026 |
| **MOD 349** | Exportador posicional 500 chars, CRLF |
| **VeriFactu hash** | SHA-256 + cadena criptográfica funcional |
| **FCM Push** | Notificaciones nueva reserva, cancelación, valoración, tarea asignada |
| **Empleados** | CRUD completo, foto de perfil, embargos LEC, horas extra, antigüedad |
| **Pedidos** | Catálogo, CRUD pedidos, múltiples pantallas |
| **Dashboard** | KPIs en tiempo real, módulos activables/desactivables |
| **Roles** | Propietario / Admin / Staff con reglas Firestore |
| **Android** | Keystore generado, build.gradle configurado para release |
| **Convenios** | Hostelería GU, Comercio GU, Peluquería, Cárnicas, Veterinarios |

---

## 📋 PLAN DE ACCIÓN PARA DESPLIEGUE (orden de prioridad)

### DÍA 1 (crítico — ~4 horas)
- [ ] **Fix Firestore Rules** → cambiar `allow write: if true` por `allow write: if perteneceAEmpresa(empresaId)`
- [ ] **Fix TypeScript errors** → eliminar import `EmailService`, corregir Stripe API version, eliminar imports no usados en `notificacionesTareas.ts`
- [ ] **Fix `initializeApp`** en `recordatoriosCitas.ts`
- [ ] **Borrar `onNuevaReserva` Gen 1** en Firebase Console → Functions → Borrar
- [ ] **`firebase deploy --only functions`** — verificar que se despliegan sin errores

### DÍA 2 (~3 horas)
- [ ] **ISO-8859-1 en exportadores** → añadir `latin1.encode()` en mod_347 y mod_349 exporters
- [ ] **Fix vista calendario en Tareas** → eliminar `// 2=calendario` o implementar
- [ ] **Recuperar contraseña** → añadir botón en pantalla_login.dart con `sendPasswordResetEmail`
- [ ] **Suscripción** → documentar que cobro es manual (vía Bizum/transferencia) hasta integrar Stripe

### DÍA 3 (~3 horas)
- [ ] **WhatsApp** → desactivar módulo del plan público o añadir disclaimer "próximamente"
- [ ] **Citas** → añadir disclaimer "Beta" o implementar disponibilidad de profesional
- [ ] **Facturación email** → conectar Cloud Function de email al botón en DetalleFacturaScreen
- [ ] **Verificar build release Android** → `flutter build apk --release` y probar APK

### DÍA 4 (~2 horas)
- [ ] **Subir a Google Play** → Internal Testing → APK firmado
- [ ] **Crear cuenta App Store Connect** → subir IPA con Apple Sign-In habilitado
- [ ] **Configurar `functions/.env`** → SMTP_HOST, SMTP_USER, SMTP_PASS
- [ ] **Test de humo** → probar flujo completo con empresa real

---

## ⚠️ DEUDA TÉCNICA A RESOLVER POST-LANZAMIENTO

| Prioridad | Tarea | Estimación |
|-----------|-------|-----------|
| Alta | Refactorizar `modulo_empleados_screen.dart` (3.021 líneas → varios archivos) | 2 días |
| Alta | Integrar Stripe para cobro automático de suscripciones | 3 días |
| Alta | Firma XAdES Verifactu (deadline 1-Jul-2027) | 5 días |
| Alta | Numeración anti-huecos en facturas (contador atómico Firestore) | 1 día |
| Media | WhatsApp Business API webhook real | 3 días |
| Media | Tests de widget para pantallas principales | 2 días |
| Media | Vista calendario en Tareas (`table_calendar`) | 1 día |
| Media | Módulo Citas con disponibilidad de profesional | 3 días |
| Baja | Historial de facturas en ficha de cliente | 1 día |
| Baja | Google Reviews reply (OAuth2 Business API) | 2 días |
| Baja | Onboarding con selección de plan | 1 día |

---

## 📦 ARCHIVOS DE BLOQUEO ACTUALES

```
functions/src/index.ts          — errores TS (Stripe API version, import no usado)
functions/src/notificacionesTareas.ts  — imports no usados
functions/src/recordatoriosCitas.ts   — initializeApp() orden
lib/services/verifactu/firma_xades_pkcs12_service.dart — errores asn1lib API
lib/features/facturacion/pantallas/detalle_factura_screen.dart — verificar compilación
firestore.rules línea ~185      — allow write: if true (VULNERABILIDAD)
```

---

## 🏁 CONCLUSIÓN

**La app ES desplegable** para un MVP con estas condiciones:

1. ✅ Corregir los 3 errores de Firestore Rules + TypeScript (1 día)
2. ✅ Aceptar que Suscripción es manual (cobro por Bizum/transferencia temporalmente)
3. ✅ Desactivar o etiquetar como "Beta/Próximamente" WhatsApp Bot y Citas completas
4. ✅ El módulo fiscal (MOD 303/347/349/111/115/130/390) es funcional para autónomos y PYMEs
5. ✅ El módulo de nóminas cubre el 90% de las necesidades de los negocios objetivo (hostelería, peluquería, carnicería, veterinaria)
6. ✅ VeriFactu no es obligatorio hasta julio 2027 — se puede desplegar en modo "pendiente"

**Objetivo realista:** App en Google Play Internal Testing en **4-5 días laborables**.

---

*Documento generado automáticamente por análisis de código fuente.*
*Revisión del código: 25/03/2026 | Proyecto: planeag_flutter | Firebase: planeaapp-4bea4*


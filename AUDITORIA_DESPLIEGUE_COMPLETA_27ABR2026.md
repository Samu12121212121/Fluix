# 🔍 AUDITORÍA COMPLETA DE DESPLIEGUE — Fluix CRM
> **Fecha:** 27 Abril 2026 · **Auditor:** Sistema IA  
> **Criterio:** 1 = no arranca / 10 = listo para producción

---

## 📊 RESUMEN EJECUTIVO

| Módulo | Nota | Estado |
|--------|------|--------|
| 🔐 Autenticación & Onboarding | **8/10** | ✅ Casi listo |
| 🏠 Dashboard | **7/10** | ⚠️ Widgets bloqueados |
| 📅 Reservas | **6/10** | ⚠️ Falta provider |
| 📆 Citas | **5/10** | ⚠️ Pantalla básica |
| ⭐ Valoraciones | **7/10** | ✅ Funcional |
| 📊 Estadísticas | **6/10** | ⚠️ Cacheo incompleto |
| 👥 Clientes | **7/10** | ✅ CRM operativo |
| 👨‍💼 Empleados | **7/10** | ✅ Gestión OK |
| 🛠️ Servicios | **5/10** | ⚠️ Solo pantalla básica |
| 🌐 Contenido Web | **7/10** | ✅ Funcional |
| 🧾 Fiscal AI | **8/10** | ✅ Motor IA listo |
| 📄 Facturación | **7/10** | ✅ Core operativo |
| 🏖️ Vacaciones | **7/10** | ✅ Funcional |
| 🗂️ TPV | **6/10** | ⚠️ Impresora sin pruebas |
| 🛒 Pedidos / Tienda | **6/10** | ⚠️ Bot sin desplegar |
| 💬 WhatsApp | **5/10** | ⚠️ Integración externa |
| 💰 Nóminas | **7/10** | ✅ Cálculo listo |
| ✅ Tareas | **6/10** | ⚠️ Sin notificaciones |
| ⏱️ Fichaje | **5/10** | ⚠️ UI básica |
| 📃 Finiquitos | **7/10** | ✅ PDF generado |
| 💳 Suscripción / Pagos | **6/10** | ⚠️ Sin Stripe live |
| 🔧 Verifactu | **7/10** | ✅ Fase 1 lista |
| 📱 Push Notifications | **6/10** | ⚠️ iOS sin verificar |
| 🏗️ Infraestructura / CI | **6/10** | ⚠️ Build manual |

---

## 🔐 MÓDULO: Autenticación & Onboarding
**Nota: 8/10**

### ✅ Implementado
- Login email/contraseña, Google Sign-In, Apple Sign-In
- Login biométrico (`pantalla_login_biometrico.dart`)
- 2FA verificación (`pantalla_verificacion_2fa.dart`)
- Registro empresa con invitación (`pantalla_registro_invitacion.dart`)
- Onboarding (`pantalla_onboarding.dart`)

### ❌ Falta antes del despliegue
- [ ] `pantalla_login_fixed.dart` y `pantalla_login_temp.dart` sugieren regresiones — **eliminar duplicados y verificar cuál es el login real**
- [ ] Flujo de recuperación de contraseña **no confirmado en el router**
- [ ] Deep links de invitación probados en iOS y Android real
- [ ] Verificar que `pantalla_login_biometrico.dart` no crashea en dispositivos sin biometría

---

## 🏠 MÓDULO: Dashboard
**Nota: 7/10**

### ✅ Implementado
- `pantalla_dashboard.dart` con StreamBuilder de widgets
- Widgets implementados: `briefing_matutino`, `proximos_dias`, `reservas_hoy`, `alertas_fiscales`, `citas_resumen`, `valoraciones_recientes`, `kpis_rapidos`, `resumen_facturacion`, `resumen_pedidos`
- `WidgetManagerService` con Firestore
- `configuracion_widgets_screen.dart` — toggle + drag & reorder
- `briefing_service.dart` operativo
- `widget_factory.dart` para renderizado dinámico

### ❌ Falta antes del despliegue
- [ ] **BUG CRÍTICO:** En `configuracion_widgets_screen.dart`, todos los widgets **no implementados** (ingresos_mes, clientes_nuevos, alertas_negocio) muestran "🚧 Próximamente" y el Switch está **deshabilitado** — esto es correcto, pero los ya implementados (`kpis_rapidos`, `citas_resumen`, etc.) **deben verificarse que `WidgetConfig.implementados` los incluye todos**
- [ ] `widget_config.dart` → `implementados` Set **no incluye** `briefing_matutino` si Firestore no tiene el doc inicializado — verificar flujo de primer uso
- [ ] `provider_dashboard.dart` — revisar si hay memoria leak en subscripciones
- [ ] Widget `resumen_facturacion` bloqueado si no tiene pack gestión — **verificar que `_packsActivos` carga correctamente en frío**
- [ ] Skeleton loaders implementados pero falta probar en conexión lenta

---

## 📅 MÓDULO: Reservas
**Nota: 6/10**

### ✅ Implementado
- `modulo_reservas_screen.dart` — pantalla principal
- `modulo_reservas.dart` widget del dashboard
- `reserva_card_mejorada.dart`

### ❌ Falta antes del despliegue
- [ ] **CRÍTICO: `lib/features/reservas/providers/` está vacío** — no existe `reservas_provider.dart`
- [ ] **CRÍTICO: `lib/domain/modelos/reserva.dart` está corrupto** — contiene fragmentos duplicados/mezclados, el modelo no es compilable
- [ ] Falta CRUD completo: crear, editar, cancelar reserva desde la UI
- [ ] Integración calendario semana/mes
- [ ] No hay filtro por empleado/servicio
- [ ] Notificación push al cliente al confirmar reserva

---

## 📆 MÓDULO: Citas
**Nota: 5/10**

### ✅ Implementado
- `widget_citas_resumen.dart` — resumen en dashboard
- `modulo_citas.dart`

### ❌ Falta antes del despliegue
- [ ] **No existe pantalla principal de citas** (no hay `modulo_citas_screen.dart` en features)
- [ ] Sin formulario de alta/edición de cita
- [ ] Sin integración con agenda ni Google Calendar
- [ ] Sin recordatorio automático al cliente

---

## ⭐ MÓDULO: Valoraciones
**Nota: 7/10**

### ✅ Implementado
- `modulo_valoraciones.dart` y `modulo_valoraciones_fixed.dart`
- `google_reviews_service.dart`, `respuesta_gmb_service.dart`
- Conectar Google Business (`conectar_google_business_screen.dart`)
- Rating historial y gráfico evolución (`grafico_evolucion_rating_widget.dart`)

### ❌ Falta antes del despliegue
- [ ] `modulo_valoraciones_fixed.dart` sugiere que hubo bug — verificar cuál es el activo y eliminar el otro
- [ ] OAuth Google Business `gmb_auth_service.dart` — verificar token refresh en producción
- [ ] Respuesta a reseñas Google: comprobar permisos Google My Business API en producción
- [ ] Sin paginación en listado largo de reseñas

---

## 📊 MÓDULO: Estadísticas
**Nota: 6/10**

### ✅ Implementado
- `modulo_estadisticas.dart`
- `estadisticas_service.dart`, `estadisticas_cache_service.dart`, `estadisticas_trigger_service.dart`
- `boton_recalcular_estadisticas.dart`

### ❌ Falta antes del despliegue
- [ ] `estadisticas_cache_service.dart` — verificar TTL y expiración correcta de caché
- [ ] Sin exportación a PDF/CSV de estadísticas
- [ ] KPIs de facturación en estadísticas dependen del pack activo — verificar guardia de plan
- [ ] `datos_prueba_service.dart` y `datos_prueba_contabilidad_service.dart` — **asegurar que NO son accesibles en producción**

---

## 👥 MÓDULO: Clientes
**Nota: 7/10**

### ✅ Implementado
- `modulo_clientes_screen.dart` — lista y búsqueda
- `importar_csv_screen.dart`
- `duplicados_cliente_screen.dart`, `clientes_silenciosos_screen.dart`
- `clientes_service.dart`, `fusion_clientes_service.dart`, `importacion_clientes_service.dart`
- `actividad_cliente_service.dart`, `exportacion_clientes_service.dart`

### ❌ Falta antes del despliegue
- [ ] Sin historial de reservas/pedidos en ficha de cliente
- [ ] Exportación CSV — probar en iOS (permisos de Files)
- [ ] `clientes_silenciosos_screen.dart` — verificar lógica de "no ha vuelto en X días"
- [ ] Sin foto de perfil de cliente desde cámara/galería

---

## 👨‍💼 MÓDULO: Empleados
**Nota: 7/10**

### ✅ Implementado
- `modulo_empleados_screen.dart`, `employees_baja_screen.dart`
- `formulario_empleado_form.dart`, `formulario_datos_nomina_form.dart`
- `configurar_modulos_empleado_screen.dart`
- `documentos_empleado_service.dart`, `convenio_firestore_service.dart`

### ❌ Falta antes del despliegue
- [ ] Subida de documentos del empleado — probar permisos storage iOS/Android
- [ ] Sin vista de contrato vigente en ficha del empleado
- [ ] `configurar_modulos_empleado_screen.dart` — ¿qué módulos puede ver un empleado? Verificar ACL
- [ ] `baja_empleado_service.dart` — probar flujo completo fin de contrato → genera finiquito automático

---

## 🛠️ MÓDULO: Servicios
**Nota: 5/10**

### ✅ Implementado
- `modulo_servicios_screen.dart`
- `servicio.dart` modelo

### ❌ Falta antes del despliegue
- [ ] **Solo existe una pantalla principal** — sin formulario de alta/edición de servicio
- [ ] Sin gestión de precios por empleado/categoría
- [ ] Sin duración del servicio (necesaria para reservas)
- [ ] Sin imágenes de servicio
- [ ] Sin vinculación con catálogo de reserva online

---

## 🌐 MÓDULO: Contenido Web
**Nota: 7/10**

### ✅ Implementado
- `pantalla_contenido_web.dart` con tabs: blog, SEO, analytics, config
- `contenido_web_service.dart`, `wordpress_service.dart`, `analytics_web_service.dart`
- `admin_contenido_web_service.dart`
- `pantalla_integracion_script.dart`

### ❌ Falta antes del despliegue
- [ ] WordPress integration — verificar autenticación Application Password en producción
- [ ] `pantalla_integracion_script.dart` — el script de integración funciona con HTTPS, probar en dominio real
- [ ] Sin preview de cómo queda el contenido publicado
- [ ] SEO: metatags generados sin validar con Google Search Console

---

## 🧾 MÓDULO: Fiscal AI (Pack Fiscal)
**Nota: 8/10**

### ✅ Implementado
- `upload_invoice_screen.dart` — captura/subida
- `fiscal_upload_service.dart` — upload + dedup + Cloud Function `processInvoice`
- `invoice_result_screen.dart`, `review_transaction_screen.dart`
- `fiscal_capture_service.dart`
- Modelos AE: 111, 115, 130, 180, 190, 202, 303, 347, 349, 390
- `calendario_fiscal_screen.dart`, `historial_presentaciones_screen.dart`
- `export_models_screen.dart`
- `subir_certificado_verifactu_screen.dart`
- `validador_fiscal_integral.dart`

### ❌ Falta antes del despliegue
- [ ] Cloud Function `processInvoice` — ¿está desplegada en `europe-west1`? **Verificar**
- [ ] `fiscal_upload_service.dart` → duplicado con `processingStatus == null` → entra en `throw DuplicateDocumentException` aunque sea primer uso — revisar lógica
- [ ] Modelos 347 y 349 — verificar si los exportadores AEAT generan fichero `.txt` posicional correcto
- [ ] `mod390_posicional_service.dart` — sin tests de regresión
- [ ] Presentación directa AEAT — todavía requiere certificado digital del cliente (advertir en UI)
- [ ] HEIC upload — probar en iOS 17/18 que el mime type se detecta bien

---

## 📄 MÓDULO: Facturación
**Nota: 7/10**

### ✅ Implementado
- `modulo_facturacion_screen.dart` con tabs completos
- `formulario_factura_screen.dart`, `formulario_factura_recibida_screen.dart`
- `formulario_rectificativa_screen.dart`, `detalle_factura_screen.dart`
- `resumen_fiscal_screen.dart`
- `facturacion_service.dart`, `contabilidad_service.dart`
- `pantalla_contabilidad.dart` con libro de ingresos

### ❌ Falta antes del despliegue
- [ ] `pantalla_configuracion_fiscal_empresa.dart` — verificar que los datos fiscales (NIF, régimen IVA) se guardan correctamente antes de emitir facturas
- [ ] Numeración de facturas: verificar que no hay huecos en la serie al anular
- [ ] `formulario_rectificativa_screen.dart` — probar round-trip con `crearFacturaRectificativa` del servicio
- [ ] Sin envío de factura por email al cliente desde la app
- [ ] Sin firma digital en PDF de factura (requerido Verifactu 2027 — advertir)

---

## 🏖️ MÓDULO: Vacaciones
**Nota: 7/10**

### ✅ Implementado
- `vacaciones_screen.dart`, `configuracion_vacaciones_screen.dart`
- `festivos_locales_screen.dart`, `nueva_solicitud_form.dart`
- `vacaciones_service.dart`, `festivos_service.dart`, `ausencias_nomina_service.dart`

### ❌ Falta antes del despliegue
- [ ] Aprobación de vacaciones por manager — verificar flujo notificación push → aprobación → reflejo en nómina
- [ ] Conflictos de solapamiento entre empleados — ¿se valida?
- [ ] `festivos_locales_screen.dart` — ¿se integra con el calendario de reservas para bloquear días?
- [ ] Sin exportación de calendario de ausencias

---

## 🗂️ MÓDULO: TPV
**Nota: 6/10**

### ✅ Implementado
- `modulo_tpv_screen.dart`, `caja_rapida_screen.dart`
- `importar_ventas_csv_screen.dart`, `historial_importaciones_screen.dart`
- `facturar_pedidos_screen.dart`, `pantalla_cierre_caja.dart`
- `configuracion_facturacion_tpv_screen.dart`
- `cierre_caja_service.dart`, `csv_ventas_parser.dart`
- `tpv_facturacion_service.dart`

### ❌ Falta antes del despliegue
- [ ] `impresora_bluetooth_service.dart` — **sin pruebas en dispositivo real con impresora ESC/POS**
- [ ] `pantalla_cierre_caja.dart` — verificar que el cuadre de caja calcula correctamente diferencia teórico/real
- [ ] Importación CSV — validar encoding UTF-8 vs ISO-8859 en archivos españoles
- [ ] Sin opción de cobro con Stripe/datáfono integrado
- [ ] `configuracion_facturacion_tpv.dart` modelo — verificar serialización completa

---

## 🛒 MÓDULO: Pedidos / Tienda Online
**Nota: 6/10**

### ✅ Implementado
- `modulo_pedidos_nuevo_screen.dart` + `modulo_pedidos_screen.dart`
- `catalogo_productos_screen.dart`, `detalle_producto_screen.dart`
- `formulario_producto_screen.dart`, `formulario_nuevo_pedido_screen.dart`
- `detalle_pedido_screen.dart`, `detalle_pedido_nuevo_screen.dart`
- `pedidos_service.dart`, `importacion_catalogo_service.dart`, `producto_imagen_service.dart`

### ❌ Falta antes del despliegue
- [ ] Dos versiones de pantalla de pedidos (`modulo_pedidos_screen` vs `modulo_pedidos_nuevo_screen`) — **unificar**
- [ ] Dos versiones de detalle de pedido — **unificar**
- [ ] Sin integración carrito web → app (webhook pendiente)
- [ ] `producto_imagen_service.dart` — subida a Storage, verificar reglas Firestore/Storage
- [ ] Sin gestión de stock real (solo conteo manual)
- [ ] Sin notificación al cliente cuando el pedido cambia de estado

---

## 💬 MÓDULO: WhatsApp
**Nota: 5/10**

### ✅ Implementado
- `modulo_whatsapp_screen.dart`
- `pantalla_chats_bot.dart`
- `configurar_bot_whatsapp_screen.dart`
- `pedidos_whatsapp_service.dart`, `whatsapp_message_service.dart`, `chatbot_service.dart`

### ❌ Falta antes del despliegue
- [ ] **Dependencia de webhook externo** (Meta API) — ¿está desplegado y aprobado en Meta Business?
- [ ] Token de WhatsApp Business API — ¿caduca? ¿hay refresh automático?
- [ ] `configurar_bot_whatsapp_screen.dart` — guía in-app para activar número de teléfono
- [ ] Sin fallback cuando el bot no entiende el mensaje
- [ ] Sin test de integración con cuenta real de WhatsApp Business

---

## 💰 MÓDULO: Nóminas
**Nota: 7/10**

### ✅ Implementado
- `modulo_nominas_screen.dart`
- `detalle_nomina_screen.dart`, `revision_nomina_empleado_screen.dart`
- `nueva_remesa_form.dart`, `remesa_sepa_screen.dart`
- `nominas_service.dart`, `nomina_pdf_service.dart`
- `remesa_sepa_service.dart`, `sepa_xml_generator.dart`
- `regularizacion_irpf_service.dart`, `costes_nominas_service.dart`
- `complementos_service.dart`, `embargo_calculator.dart`

### ❌ Falta antes del despliegue
- [ ] `revision_nomina_empleado_screen.dart` — ¿el empleado puede firmar digitalmente la nómina?
- [ ] `sepa_xml_generator.dart` — validar esquema XML pain.001.001.03 contra banco real
- [ ] `embargo_calculator.dart` — caso extremo: salario mínimo SMI 2026
- [ ] Sin integración con Seguridad Social (Sistema RED) — advertir en UI
- [ ] PDF de nómina: probar en iOS que se abre correctamente con Quick Look

---

## ✅ MÓDULO: Tareas
**Nota: 6/10**

### ✅ Implementado
- `modulo_tareas_screen.dart`, `formulario_tarea_screen.dart`
- `detalle_tarea_screen.dart`, `reporte_tiempo_screen.dart`
- `equipos_screen.dart`
- `tareas_service.dart`, `tiempo_tarea_service.dart`, `adjuntos_tarea_service.dart`

### ❌ Falta antes del despliegue
- [ ] Sin push notification cuando se asigna una tarea
- [ ] `adjuntos_tarea_service.dart` — gestión de archivos adjuntos, verificar límite de tamaño
- [ ] `reporte_tiempo_screen.dart` — exportar a CSV/PDF
- [ ] Sin vista Kanban (solo lista)
- [ ] `equipos_screen.dart` — permisos por equipo no verificados

---

## ⏱️ MÓDULO: Fichaje
**Nota: 5/10**

### ✅ Implementado
- `pantalla_fichaje.dart`
- `fichaje_service.dart`

### ❌ Falta antes del despliegue
- [ ] **Solo una pantalla** — sin informes de horas trabajadas por empleado
- [ ] Sin geolocalización opcional para verificar fichaje presencial
- [ ] Sin integración con nómina (horas extra, festivos trabajados)
- [ ] Sin exportación de registro horario (obligatorio por ley desde 2019)
- [ ] Sin corrección de fichaje erróneos por parte del manager

---

## 📃 MÓDULO: Finiquitos
**Nota: 7/10**

### ✅ Implementado
- `finiquitos_screen.dart`, `nuevo_finiquito_form.dart`
- `finiquito_detalle.dart`, `revision_finiquito_empleado_screen.dart`
- `finiquito_calculator.dart`, `finiquito_pdf_service.dart`
- `carta_cese_service.dart`, `firma_finiquito_service.dart`
- `finiquito_autorellena_service.dart`

### ❌ Falta antes del despliegue
- [ ] Firma digital del finiquito — probar en iOS `firma_finiquito_service.dart`
- [ ] `finiquito_autorellena_service.dart` — ¿lee correctamente el convenio colectivo para calcular conceptos?
- [ ] Sin integración con `regularizacion_irpf_service.dart` en el cálculo del IRPF del finiquito
- [ ] PDF firmado — verificar que no se puede modificar después de firmar

---

## 💳 MÓDULO: Suscripción / Pagos
**Nota: 6/10**

### ✅ Implementado
- `pantalla_suscripcion_vencida.dart`, `pantalla_upgrade_modulo.dart`
- `suscripcion_service.dart`, `configuracion_pagos_service.dart`
- `pantalla_configuracion_pagos.dart`

### ❌ Falta antes del despliegue
- [ ] **Stripe en modo TEST** — verificar que las claves de producción están configuradas en Firebase Remote Config o Functions env
- [ ] Webhook de Stripe para actualizar plan en Firestore automáticamente
- [ ] `pantalla_upgrade_modulo.dart` — probar flujo completo upgrade → pago → activación módulo
- [ ] Sin gestión de plan vencido: ¿qué pasa con los datos si no renueva?
- [ ] Sin emails automáticos de renovación/expiración próxima (7 días antes)

---

## 🔧 MÓDULO: Verifactu
**Nota: 7/10**

### ✅ Implementado
- `verifactu_flow_service.dart`, `xml_builder_service.dart`, `xml_payload_verifactu_builder.dart`
- `firma_xades_pkcs12_service.dart`, `firma_xades_service.dart`
- `hash_chain_service.dart`, `aeat_remision_service.dart`
- `validador_verifactu.dart`, `generador_qr_verifactu.dart`
- `modelos_verifactu.dart`, `representacion_verifactu.dart`
- `certificado_repository.dart`

### ❌ Falta antes del despliegue
- [ ] **Obligatorio julio 2025 / enero 2027** — comunicar claramente al cliente que es Fase 1 (preparación)
- [ ] `aeat_remision_service.dart` — endpoint AEAT de producción vs preproducción — verificar URL activa
- [ ] Cadena de hash (chaining) — probar escenario de anulación → no rompe la cadena
- [ ] `firma_xades_minima_validator.dart` — ejecutar contra certificado de prueba real
- [ ] Certificado digital almacenado en device — verificar que se cifra con AES antes de guardar en Firestore

---

## 📱 MÓDULO: Push Notifications
**Nota: 6/10**

### ✅ Implementado
- `notificaciones_service.dart`, `bandeja_notificaciones_service.dart`
- `bandeja_notificaciones_screen.dart`, `badge_service.dart`
- `push_notifications_tester.dart`, `sonido_notificacion_service.dart`
- `debug_fcm_widget.dart`

### ❌ Falta antes del despliegue
- [ ] iOS — verificar APNs entitlement + certificado push en producción (no sandbox)
- [ ] `check_ios_push.sh` — ejecutar en dispositivo iOS real pre-lanzamiento
- [ ] Sin deep link desde notificación a la pantalla correcta
- [ ] Permisos en Android 13+ (`POST_NOTIFICATIONS`) — confirmar que se solicitan
- [ ] `sonido_notificacion_service.dart` — los sonidos personalizados pueden no funcionar en iOS en segundo plano

---

## 🏗️ INFRAESTRUCTURA & CI/CD
**Nota: 6/10**

### ✅ Implementado
- `codemagic.yaml` configurado
- `firebase.json`, `firestore.rules`, `firestore.indexes.json`
- `build_release.bat`, `build_testflight_with_push.bat`
- Funciones Cloud desplegables con `desplegar_functions.bat`

### ❌ Falta antes del despliegue
- [ ] **`firestore.rules`** — auditar reglas de seguridad módulo por módulo (empresas aisladas, roles verificados)
- [ ] **Indexes Firestore** — verificar que `firestore.indexes.json` incluye todos los índices compuestos necesarios para consultas de producción
- [ ] Cloud Functions — revisar timeouts y memoria (especialmente `processInvoice`)
- [ ] `codemagic.yaml` — ¿las variables de entorno de producción (STRIPE_KEY, AEAT_CERT) están en Codemagic secrets?
- [ ] Sin monitoreo de errores (Crashlytics/Sentry) integrado
- [ ] Sin backup automático de Firestore programado
- [ ] **Eliminar archivos de datos de prueba** (`datos_prueba_service.dart`, `datos_prueba_fluixtech_service.dart`) del build de producción

---

## 🚨 TOP 10 CRÍTICOS ANTES DEL DESPLIEGUE

> Ordenados por severidad. Sin resolver estos, **NO desplegar**.

| # | Problema | Módulo | Severidad |
|---|----------|--------|-----------|
| 1 | `reserva.dart` **CORRUPTO** — archivo con fragmentos mezclados, no compila | Reservas | 🔴 BLOQUEANTE |
| 2 | `reservas_provider.dart` **NO EXISTE** — todo el módulo de reservas sin estado | Reservas | 🔴 BLOQUEANTE |
| 3 | Stripe en **modo TEST** — pagos no van a cobrar en producción | Suscripción | 🔴 BLOQUEANTE |
| 4 | Reglas Firestore — sin auditoría de seguridad por empresa/rol | Infraestructura | 🔴 BLOQUEANTE |
| 5 | Cloud Function `processInvoice` — no confirmado despliegue en `europe-west1` | Fiscal AI | 🔴 BLOQUEANTE |
| 6 | Archivos de datos de prueba accesibles en producción | Infraestructura | 🟠 CRÍTICO |
| 7 | Login duplicado (login, login_fixed, login_temp) — riesgo de bug en auth | Autenticación | 🟠 CRÍTICO |
| 8 | iOS APNs — certificado push no verificado en producción | Push | 🟠 CRÍTICO |
| 9 | WhatsApp token — sin refresh automático puede perderse conexión | WhatsApp | 🟡 ALTO |
| 10 | Fichaje sin exportación de registro horario — **obligación legal** | Fichaje | 🟡 ALTO |

---

## ✅ CHECKLIST FINAL PRE-LANZAMIENTO

```
CÓDIGO
[ ] Resolver reserva.dart corrupto y crear reservas_provider.dart
[ ] Eliminar pantallas duplicadas (_fixed, _temp, _nuevo vs normal)
[ ] Confirmar que WidgetConfig.implementados tiene todos los widgets activos
[ ] Eliminar datos_prueba_service del build release

FIREBASE
[ ] Auditar firestore.rules completo
[ ] Verificar todos los indexes compuestos desplegados
[ ] Desplegar Cloud Functions en PRODUCCIÓN (europe-west1)
[ ] Activar Crashlytics

PAGOS
[ ] Stripe keys → producción
[ ] Webhook Stripe → URL producción apuntando a Cloud Function

CERTIFICADOS
[ ] APNs certificado producción iOS
[ ] Certificado Verifactu de prueba operativo

LEGAL
[ ] Exportación registro horario fichaje (obligatorio)
[ ] Advertencia en UI sobre Verifactu obligatoriedad 2027
[ ] RGPD: política de privacidad actualizada en onboarding
```

---

*Generado automáticamente — actualizar tras cada sprint. Próxima revisión recomendada: **Mayo 2026**.*


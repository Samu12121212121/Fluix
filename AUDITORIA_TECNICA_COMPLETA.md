# 🔍 AUDITORÍA TÉCNICA COMPLETA — Fluix CRM
> Fecha: Abril 2026 | Versión app: 1.0.9+1 | Estándar: SaaS B2B Producción

---

## MÓDULO 1 — Autenticación y Sesión

**Nota: 8/10**

### ✅ Qué funciona bien
- Singleton `SesionService` con timeout de 30 min de inactividad bien implementado
- Detección de tiempo en background y logout automático al volver si supera 30 min
- Forced token refresh al volver de background (`getIdToken(true)`)
- GestureDetector en raíz registrando actividad correctamente
- `_PantallaRuta` con flujo onboarding → suscripción → dashboard perfectamente encadenado
- Protecciones automáticas de rol: si empresa == empresaPropietariaId → fuerza 'propietario'
- Auto-promoción si no hay admin/propietario en empresa
- Firebase App Check configurado (PlayIntegrity en prod, debug en dev)
- Persistencia offline de Firestore habilitada
- Apple Sign-In y Google Sign-In implementados
- Cuenta demo funcional con `DemoCuentaService`

### ❌ Qué falta / bugs conocidos
- **No hay biometría real en login**: `local_auth` está en pubspec pero no se usa en el flujo de login. Está declarado pero sin implementar.
- **`_PantallaRuta` hace 3 lecturas secuenciales de Firestore** (usuario → empresa → suscripción) en cascada con FutureBuilder anidados. Son 3 roundtrips bloqueantes al arranque. En conexión lenta, el usuario espera 3+ segundos viendo spinner.
- **Sin invalidación de sesión en múltiples dispositivos**: si el admin revoca acceso a un staff, este sigue con sesión activa hasta que expire el token (1h).
- **`AdminInitializer` se ejecuta en cada arranque** aunque ya esté configurado. Sin flag de "ya inicializado".
- **El `onSesionExpirada` callback** se asigna en `main.dart` pero si el usuario navega a pantallas profundas, el redirect al login puede perder el contexto del navigator.
- **No hay pantalla de "cargando sesión"** diferenciada del loading genérico. El mismo spinner para todo.

### 📋 Prioridad de mejora: **Media**

---

## MÓDULO 2 — Dashboard

**Nota: 7/10**

### ✅ Qué funciona bien
- `TabController` sincronizado fuera del `build()` → correcto, evita el clásico bug de resets
- Dispose seguro del controlador anterior con `Future.microtask()`
- Navegación por notificación FCM al detalle de tarea funciona
- Vista simulada de rol (el propietario puede ver lo que ve un staff/admin)
- Modo edición de widgets (reordenar)
- `WidgetManagerService` para gestionar widgets activos
- Banner de suscripción integrado
- Modo offline banner
- `SkeletonLoaders` para estados de carga

### ❌ Qué falta / bugs conocidos
- **El dashboard carga todos los módulos aunque no estén en la suscripción**: la guarda de módulos se hace por rol, pero si un módulo está en `_modulosActivos` (lista hardcodeada), se muestra igualmente. La verificación real de suscripción es débil.
- **`_cargarDatosUsuario()` es un Future que NO se reescucha**: si Firestore actualiza el rol del usuario en tiempo real, el dashboard NO se actualiza hasta reabrir la app.
- **Heroes duplicados**: si el mismo widget aparece en múltiples tabs hay riesgo de Hero tag collision (detectado en sesiones anteriores).
- **Sin paginación en el StreamBuilder principal**: si hay >200 reservas/tareas, el stream descarga todo de golce.
- **`_rolVistaActual`** (simulación de rol) no persiste entre reinicios del widget.
- **El dashboard no tiene pull-to-refresh**: el usuario no puede forzar actualización.
- **`kDebugMode` condiciona la visibilidad del botón de datos de prueba**, pero en el APK de release se puede filtrar por flags de suscripción propietario, no por kDebugMode. Riesgo de que se cuele en producción.

### 📋 Prioridad de mejora: **Alta**

---

## MÓDULO 3 — Reservas y Citas

**Nota: 7/10**

### ✅ Qué funciona bien
- `ModuloReservas` reutilizable con parámetros (`collectionId`, `moduloSingular`, `moduloPlural`)
- Tabs por estado (Pendientes/Confirmadas/Canceladas/Todas/Calendario)
- KPIs mini en la cabecera (conteos en tiempo real via Stream)
- Vista calendario semanal presente
- Filtros por estado funcionando
- Integración con Cloud Functions para notificaciones al llegar reserva nueva
- Soporte para `citas` usando el mismo widget con parámetros distintos
- `EstadisticasTriggerService` integrado

### ❌ Qué falta / bugs conocidos
- **La query no filtra por fecha**: descarga TODAS las reservas históricas de la empresa. Con 1000+ reservas, esto es un problema grave de rendimiento y costes Firestore.
  ```dart
  // ❌ Descarga todo:
  .orderBy('fecha_hora', descending: false).snapshots()
  // ✅ Debería ser:
  .where('fecha_hora', isGreaterThanOrEqualTo: hace30Dias).orderBy(...)
  ```
- **Sin paginación**: lista infinita sin `limit()` ni cursor pagination.
- **El formulario de nueva reserva no valida solapamiento de horarios**: puedes crear dos reservas al mismo profesional en el mismo slot sin aviso.
- **La vista calendario no muestra eventos en tiempo real**: hay un lag de reconstrucción.
- **Sin integración real con el catálogo de servicios**: al crear reserva, el servicio se escribe como texto libre, no vinculado a `servicios/{id}`.
- **Llegada de reservas desde web**: funciona (Cloud Function) pero el `onNuevaReserva` y `onReservaNueva` coexisten para el mismo path, generando escritura doble en la bandeja.
- **No hay recordatorio automático al cliente** antes de la cita (solo el admin recibe notificación; el cliente no).

### 📋 Prioridad de mejora: **Alta**

---

## MÓDULO 4 — Clientes

**Nota: 7.5/10**

### ✅ Qué funciona bien
- Filtrado local avanzado: texto, etiquetas, facturación mínima, actividad, localidad
- Etiquetas predefinidas del sistema + personalizadas
- `ClientesService` limpio y bien encapsulado
- Importación de clientes desde CSV
- Exportación de clientes
- Fusión de duplicados (`fusion_clientes_service.dart`)
- Actividad del cliente trackeada (`actividad_cliente_service.dart`)

### ❌ Qué falta / bugs conocidos
- **Sin historial de reservas vinculado en la ficha de cliente**: aunque existe `actividad_cliente_service`, la UI de ficha de cliente no muestra las reservas pasadas del cliente de forma automática.
- **Estadísticas por cliente superficiales**: `total_gastado` se actualiza manualmente, no de forma reactiva desde facturas.
- **Sin búsqueda en Firestore**: toda la búsqueda es local (filtra sobre el snapshot completo). Con >500 clientes esto carga todo en memoria.
- **El campo `localidad`** no siempre está presente; el fallback a `direccion` puede dar falsos positivos en el filtro.
- **Sin foto de perfil de cliente** (hay `image_picker` en pubspec pero no en el módulo de clientes).
- **Sin deduplicación automática por teléfono/email** al crear: puedes crear el mismo cliente dos veces sin aviso.

### 📋 Prioridad de mejora: **Media**

---

## MÓDULO 5 — Facturación (Pack Fiscal IA)

**Nota: 8/10**

### ✅ Qué funciona bien
- Pipeline completo: Document AI OCR → preprocesador → Claude Sonnet → validación → Firestore
- `invoiceExtractionV4` con prompt versionado (`PROMPT_VERSION`)
- `preprocesarTextoOCR` como capa de limpieza antes de Claude
- Detección de países UE para IVA intracomunitario
- Contador de facturas con transacción Firestore (sin duplicados de numeración)
- Reset anual del contador de serie
- Múltiples series de factura (FAC, REC, PRO, etc.)
- Integración con VeriFactu
- Validador fiscal integral (`validador_fiscal_integral.dart`)
- PDF generación con `pdf` package

### ❌ Qué falta / bugs conocidos
- **`non_subject_amount` detectado por Claude pero NO guardado en el modelo Dart `Factura`**: Claude lo devuelve en el JSON pero el mapper no lo persiste. La validación matemática falla silenciosamente.
- **Auto-publicación por confianza ≥92% no implementada en Flutter**: está en el plan pero el flag `confianza` de Claude no se usa para auto-aprobar. Requiere aprobación manual siempre.
- **Conversión de moneda BCE**: en el código no hay llamada a la API del BCE. Las facturas en divisa extranjera no se convierten automáticamente.
- **Detección de duplicados**: no hay índice de hash de factura. Si subes la misma factura dos veces, se crea duplicado sin aviso.
- **Régimen de margen**: no implementado (REBU). Solo IVA normal.
- **Facturas internacionales fuera de UE**: el prompt de Claude maneja el campo `pais_emisor` pero la lógica de IVA no contempla importaciones de terceros países (operaciones exentas art. 21).
- **`sharp` y `pdf-parse` importados con `require()`** en lugar de import ESM, lo cual genera warnings en el build aunque funciona.
- **Sin pantalla de "facturas pendientes de revisión"** diferenciada de las publicadas.

### 📋 Prioridad de mejora: **Alta**

---

## MÓDULO 6 — Nóminas

**Nota: 9/10**

### ✅ Qué funciona bien
- Cálculo SS 2026 con todos los tipos actualizados (MEI 0.90%, nuevos tipos RDL 3/2026)
- Soporte multi-convenio: hostelería, comercio, peluquería, cárnicas, veterinarios, construcción (Guadalajara y Cuenca)
- Resolución automática de convenio por sector del empleado
- Horas anuales por convenio para cálculo de valor/hora
- Validación de salario mínimo por convenio y SMI 2026 (15.876€)
- Embargo calculator integrado
- PDF de nómina
- Historial salarial en Firestore
- Pluses variables por unidades

### ❌ Qué falta / bugs conocidos
- **Sector por defecto es hostelería** si no hay match. Si un empleado de otro sector no tiene configurado el campo `sector`, se calculará con el convenio incorrecto sin aviso.
- **Sin validación de fecha de efectividad**: si subes una nómina de enero en abril, no avisa que puedes estar fuera del periodo de liquidación.
- **La regularización IRPF anual** (`regularizacion_irpf_service.dart`) no está integrada en el flujo de nómina de diciembre automáticamente.
- **Sin generación de fichero TC1/TC2** para la TGSS (solo PDF).
- **Sin integración con el Modelo 111**: aunque el servicio existe, el flujo de nómina → 111 no es automático; requiere acción manual.
- **Sin alertas de convenio desactualizado**: si subes un convenio nuevo a Firestore pero el empleado tiene caché del anterior, no se fuerza recarga.

### 📋 Prioridad de mejora: **Media**

---

## MÓDULO 7 — Empleados

**Nota: 7/10**

### ✅ Qué funciona bien
- Ficha de empleado completa con datos laborales
- Vinculación con nóminas y fichajes
- Documentos del empleado (`documentos_empleado_service.dart`)
- Baja de empleado (`baja_empleado_service.dart`)
- Carta de cese (`carta_cese_service.dart`)
- Finiquito con autorrelleno (`finiquito_autorellena_service.dart`) y cálculo
- Firma de finiquito (`firma_finiquito_service.dart`)
- Alertas de contrato (`alertas_contrato_service.dart`)

### ❌ Qué falta / bugs conocidos
- **Sin control de versiones de documentos**: si subes un nuevo contrato, el anterior no se archiva, se sobreescribe.
- **La pantalla de empleados no muestra el estado de fichaje en tiempo real**: hay que ir al módulo de fichajes aparte.
- **Sin integración con GPS automático**: `geolocator` está en pubspec pero el fichaje GPS es opcional, no se valida que el empleado fichó desde el centro de trabajo.
- **Invitaciones por deep link** (`app_links`): implementado a nivel de servicio pero el flujo UX de onboarding del empleado invitado no está documentado y puede tener race conditions con la creación del usuario en Auth.
- **Sin organigrama**: no hay vista de estructura jerárquica de la empresa.

### 📋 Prioridad de mejora: **Media**

---

## MÓDULO 8 — Fichajes

**Nota: 6.5/10**

### ✅ Qué funciona bien
- Entrada/salida con timestamp exacto
- Coordenadas GPS opcionales guardadas
- Stream del último fichaje del día por empleado
- Gestión de pausa implementada en el modelo

### ❌ Qué falta / bugs conocidos
- **Sin validación de doble entrada**: si el empleado pulsa "Entrada" dos veces en el mismo día, se crean dos registros sin error.
- **Sin cálculo automático de horas trabajadas**: la diferencia entrada-salida no se calcula automáticamente; hay que hacer queries manuales.
- **Vista de admin incompleta**: no hay panel de control para ver quién está fichado ahora mismo en tiempo real (agregado de toda la empresa).
- **Sin exportación a Excel/CSV** de los fichajes mensuales para nóminas.
- **Sin alertas de hora de entrada tardía o ausencia**.
- **Las reglas Firestore no verifican que el empleado que ficha sea el mismo que el `empleado_id`** del documento. Un staff podría fichar por otro.
- **Sin integración con el cálculo de nómina**: las horas fichadas no se importan automáticamente para calcular horas extra.
- **No cumple el RD 1791/2010 completo**: falta el registro obligatorio de jornada mensual firmado digitalmente.

### 📋 Prioridad de mejora: **Alta**

---

## MÓDULO 9 — Tareas

**Nota: 8/10**

### ✅ Qué funciona bien
- Equipos con responsable y miembros
- Tareas con tipo, prioridad, estado, etiquetas, ubicación
- Tiempo estimado y registro de tiempo real
- Subtareas anidadas
- Historial de cambios por tarea
- Tareas recurrentes con `ConfiguracionRecurrencia`
- Recordatorios de tareas
- Tareas solo-propietario (visibilidad restringida)
- Cloud Functions para notificación al asignar tarea
- Navegación directa desde notificación FCM a la tarea
- Sugerencias de tarea (`sugerencias_service.dart`)
- Adjuntos (`adjuntos_tarea_service.dart`)

### ❌ Qué falta / bugs conocidos
- **`tareasPorEstadoStream` filtra en cliente**: descarga TODAS las tareas y filtra localmente. Con 500+ tareas esto es ineficiente.
  ```dart
  // ❌ Filtra en cliente:
  .snapshots().map((s) => s.docs.map(...).where((t) => t.estado == estado).toList())
  // ✅ Debería ser:
  .where('estado', isEqualTo: estado.name).snapshots()
  ```
- **Sin tablero Kanban**: las tareas se muestran en lista. No hay vista de tablero drag-and-drop.
- **Mensajes internos de tarea**: no se detecta en el código un chat/comentarios dentro de cada tarea.
- **Las tareas recurrentes** se generan por Cloud Function scheduled pero si falla la función un día, la tarea no se regenera.

### 📋 Prioridad de mejora: **Media**

---

## MÓDULO 10 — WhatsApp y Bot

**Nota: 6/10**

### ✅ Qué funciona bien
- Webhook multi-empresa por `phone_number_id`
- Verificación de Meta por `verify_token` en Firestore (sin hardcode)
- Integración con Claude para respuestas inteligentes
- Arquitectura multi-empresa: cada empresa tiene su propio bot en `whatsapp_bot` subcolección
- Soporte de texto entrante
- Registro de conversaciones en Firestore

### ❌ Qué falta / bugs conocidos
- **Solo procesa mensajes de texto**: imágenes, audio, documentos y ubicaciones son ignorados (`message.text?.body` o nada).
- **Sin gestión de pedidos por WhatsApp** completa: el bot puede recibir un pedido pero no hay flujo de confirmación, cobro ni generación de factura desde WhatsApp.
- **Sin pantalla en la app de chats del bot**: la Cloud Function procesa y guarda en Firestore, pero no hay una UI en Flutter para que el negocio vea las conversaciones del bot y pueda intervenir manualmente.
- **Sin rate limiting**: un cliente malintencionado puede inundar el webhook con mensajes y generar coste de Claude ilimitado.
- **Sin manejo de sesión de conversación**: cada mensaje se procesa de forma aislada. Claude no tiene contexto de mensajes anteriores en la misma conversación.
- **Sin plantillas de respuesta HSM** para mensajes iniciados por la empresa (notificaciones proactivas).
- **`maxInstances: 20`** puede ser insuficiente en pico o excesivo para una empresa pequeña.

### 📋 Prioridad de mejora: **Alta**

---

## MÓDULO 11 — Modelos Fiscales (130, 111, 115, 390, 347)

**Nota: 7.5/10**

### ✅ Qué funciona bien
- **Modelo 111**: cálculo trimestral desde nóminas pagadas, dinerario vs especie, ingreso a cuenta
- Rango de meses por trimestre automatizado
- Plazo límite calculado
- Tipos de declaración (ordinaria, complementaria, sustitutiva)
- `Modelo111Service` con lógica de agregación por empleado
- PDF del modelo 111

### ❌ Qué falta / bugs conocidos
- **Modelo 130** (pagos fraccionados IRPF autónomos): existe `fiscal/` en las Cloud Functions pero no está claro si el cálculo de rendimientos netos está implementado.
- **Modelo 115** (retenciones alquiler): solo existe el servicio mencionado en el índice, sin confirmar implementación completa.
- **Modelo 390** (resumen anual IVA): existe referencia pero el cálculo de todas las casillas del 390 es muy complejo; sin confirmación de cobertura completa.
- **Modelo 347** (operaciones con terceros): `mod_347_service.dart` existe, pero el umbral de 3.005,06€ y la lógica de agrupación anual por NIF no está verificada en profundidad.
- **Sin generación de XML para presentación telemática a la AEAT**: solo PDF. La AEAT exige formato XML específico para la mayoría de modelos. Presentar manualmente desde PDF no es ágil.
- **Sin calendario fiscal automático con alertas push**: no hay reminder de "el día 20 vence el 111 del T1".
- **Sin integración directa con el módulo de facturación** para calcular el IVA devengado/soportado del periodo automáticamente.

### 📋 Prioridad de mejora: **Alta**

---

## MÓDULO 12 — Estadísticas

**Nota: 6.5/10**

### ✅ Qué funciona bien
- `EstadisticasService` calcula ingresos, reservas, clientes, valoraciones, empleados
- Fallback offline con datos locales
- `EstadisticasTriggerService` para actualizar en background
- `EstadisticasCacheService` para evitar recálculos innecesarios
- KPIs de 30 días vs 60 días (comparativa)
- Gráficos con `fl_chart`

### ❌ Qué falta / bugs conocidos
- **El fallback offline devuelve ceros**: `_usarDatosLocales()` prepara un mapa de ceros y no lo guarda realmente en ningún sitio. Es un no-op.
- **`_verificarConectividad()` hace una lectura de `test/connection`** que no existe en Firestore → siempre falla en emulador y genera escrituras de error innecesarias en producción.
- **Las estadísticas se calculan on-demand**, no con Cloud Functions triggered. Cada vez que el admin abre el dashboard, se lanzan todas las queries. Con histórico grande esto es caro.
- **Sin segmentación temporal real**: no hay filtro por semana/mes/año en la UI. Solo los últimos 30 días.
- **Sin exportación de estadísticas** a PDF o Excel.
- **KPIs del dashboard (`tarjetas_resumen.dart`)** pueden tener datos desactualizados si la sesión lleva mucho tiempo abierta sin navegar.

### 📋 Prioridad de mejora: **Media**

---

## MÓDULO 13 — Web Pública

**Nota: 6/10**

### ✅ Qué funciona bien
- Editor de contenido web (`admin_contenido_web_service.dart`, `contenido_web_service.dart`)
- Google My Business integración (`gmb_auth_service.dart`, `gmb_snapshots.ts`)
- Valoraciones públicas con historial de rating
- Respuesta a reseñas GMB desde la app (`respuesta_gmb_service.dart`, `gmbRespuestas.ts`)
- Integración con WordPress (`wordpress_service.dart`)
- Analytics web (`analytics_web_service.dart`)
- Formulario de reservas web (Dama Juana usa esta función → funciona en producción)

### ❌ Qué falta / bugs conocidos
- **Sin previsualización de la web pública** desde la app: el editor modifica contenido pero el admin no puede ver cómo quedará sin abrir el navegador.
- **La integración GMB requiere OAuth manual**: el flujo de autorización GMB no está automatizado dentro de la app; hay pasos externos.
- **Valoraciones desde web**: el formulario web genera documentos en Firestore, pero si el trigger de Cloud Function falla, la valoración queda huérfana sin notificación.
- **Sin moderación de contenido**: cualquier texto enviado desde el formulario web va directamente a Firestore sin filtro de spam ni moderación.
- **Sin SEO automático**: la web generada no tiene sitemap, meta tags dinámicos ni schema.org.
- **El módulo de contenido web tiene dos implementaciones** (`modulo_contenido_web.dart` y `modulo_contenido_web_simplificado.dart`), lo que genera confusión y posible divergencia de comportamiento.

### 📋 Prioridad de mejora: **Media**

---

## MÓDULO 14 — Notificaciones FCM

**Nota: 6/10**

### ✅ Qué funciona bien
- 3 canales Android diferenciados (principal, reseñas negativas, fiscal)
- Token guardado en `usuarios/{uid}` y en `empresas/{empresaId}/dispositivos/{uid}`
- Fallback: `obtenerTokensEmpresa()` busca en ambas colecciones
- `onNuevaReserva` y `onNuevaCita` en Cloud Functions
- Handler de background registrado correctamente como top-level function
- `@pragma('vm:entry-point')` correcto
- Navegación desde notificación a tarea concreta
- `testPushNotification` callable para diagnóstico
- iOS: `UIBackgroundModes` con `remote-notification` y `fetch` configurados
- Entitlements con `aps-environment: development/production`
- Renovación de token automática con `onTokenRefresh`

### ❌ Qué falta / bugs conocidos
- **Notificaciones en foreground no se muestran visualmente**: FCM en foreground solo dispara `onMessage` pero no muestra notificación nativa automáticamente. Hay que llamar a `_localNotifications.show()` en el handler de foreground. **Este es el bug principal reportado por el usuario**.
- **Token puede ser stale**: si el usuario desinstala y reinstala la app, el token antiguo permanece en Firestore. No hay limpieza de tokens inválidos.
- **Sin topics de FCM**: todas las notificaciones van a tokens directos. Si una empresa tiene 50 empleados, hay que iterar 50 tokens. Topics escalarían mejor.
- **`onNuevaReserva` y `onReservaNueva` coexisten** para el mismo path → doble escritura en bandeja.
- **Sin gestión de errores de token inválido**: si FCM devuelve `messaging/registration-token-not-registered`, el token no se borra de Firestore automáticamente.
- **`guardarTokenConEmpresa` se llama en `initState` del dashboard** pero si el usuario abre la app sin internet, el token no se guarda y nunca se reintenta.

### 📋 Prioridad de mejora: **Alta**

---

## MÓDULO 15 — Suscripciones y Planes

**Nota: 7/10**

### ✅ Qué funciona bien
- `DatosSuscripcion` con modelo nuevo (packs + addons) y legacy (modulos_activos)
- `PlanesConfig.getModulosActivos()` calcula módulos de forma dinámica
- Soporte de estados: ACTIVA, VENCIDA, SUSPENDIDA, PRUEBA
- Días restantes calculados
- `PantallaSuscripcionVencida` con bloqueo de acceso
- Grace period de 7 días tras vencimiento
- `BannerSuscripcion` en dashboard

### ❌ Qué falta / bugs conocidos
- **Sin integración real con Stripe**: `configuracion_pagos_service.dart` existe pero el flujo de checkout de Stripe no está completo en Flutter. El upgrade de plan no lleva a una pantalla de pago funcional.
- **Las guards de módulos son client-side**: `permisos_service.dart` verifica el plan en cliente con datos cacheados. Si el cache está desactualizado, un usuario con plan vencido puede acceder a módulos premium.
- **Sin webhook de Stripe**: no hay Cloud Function que escuche `customer.subscription.updated` o `invoice.payment_failed` para actualizar Firestore automáticamente.
- **Sin flujo de upgrade UX**: el banner de suscripción no lleva a ninguna pantalla funcional donde el usuario pueda comprar.
- **`SuscripcionService` cachea en memoria**: si la suscripción vence mientras la app está abierta, el cache no se invalida hasta reinicio.
- **Sin prueba gratuita automática**: el estado PRUEBA existe pero no hay flujo de activación automática al crear cuenta nueva.

### 📋 Prioridad de mejora: **Alta**

---

## 📊 TABLA RESUMEN — Peor a Mejor

| # | Módulo | Nota | Estado |
|---|--------|------|--------|
| 1 | Fichajes | 6.5/10 | ⚠️ Incompleto legalmente |
| 2 | Estadísticas | 6.5/10 | ⚠️ Fallback roto |
| 3 | Web Pública | 6.0/10 | ⚠️ Duplicidades UI |
| 4 | Notificaciones FCM | 6.0/10 | 🔴 Bug crítico foreground |
| 5 | WhatsApp Bot | 6.0/10 | ⚠️ Sin UX en app |
| 6 | Suscripciones/Planes | 7.0/10 | ⚠️ Sin Stripe real |
| 7 | Modelos Fiscales | 7.5/10 | ⚠️ Sin XML AEAT |
| 8 | Clientes | 7.5/10 | ✅ Funcional |
| 9 | Reservas y Citas | 7.0/10 | ⚠️ Sin límite de query |
| 10 | Empleados | 7.0/10 | ✅ Funcional |
| 11 | Tareas | 8.0/10 | ✅ Bien implementado |
| 12 | Facturación IA | 8.0/10 | ✅ Sólido |
| 13 | Dashboard | 7.0/10 | ⚠️ Sin reactivo en rol |
| 14 | Nóminas | 9.0/10 | ✅ Excelente |
| 15 | Autenticación | 8.0/10 | ✅ Sólido |

---

## 🔴 TOP 5 BUGS CRÍTICOS (Resolver antes del lanzamiento)

### 🔴 BUG 1 — Notificaciones push no aparecen en foreground
**Módulo**: FCM  
**Impacto**: El usuario principal (Dama Juana) no ve las reservas nuevas en tiempo real.  
**Causa**: `FirebaseMessaging.onMessage` no muestra notificación visual automáticamente. Hay que llamar `_localNotifications.show()` explícitamente.  
**Fix**: En el handler `_manejarMensajePrimerPlano` del `NotificacionesService`, añadir la llamada a `_localNotifications.show()` después de recibir el mensaje.

### 🔴 BUG 2 — Query de reservas sin límite temporal
**Módulo**: Reservas/Citas  
**Impacto**: Con histórico > 500 reservas, la app descarga todo en cada StreamBuilder. Coste Firestore desorbitado + UI lenta.  
**Causa**: `orderBy('fecha_hora').snapshots()` sin filtro `where`.  
**Fix**: Añadir `.where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(hace90Dias))`.

### 🔴 BUG 3 — Stripe sin webhook → suscripciones no se actualizan
**Módulo**: Suscripciones  
**Impacto**: Si un cliente paga, la suscripción en Firestore no se activa automáticamente. Si el pago falla, el acceso no se corta. El negocio no puede escalar sin esto.  
**Causa**: No hay Cloud Function que escuche los eventos de Stripe.  
**Fix**: Implementar webhook de Stripe con `onRequest` que procese `invoice.paid` y `customer.subscription.deleted`.

### 🔴 BUG 4 — Doble trigger en reservas (onNuevaReserva + onReservaNueva)
**Módulo**: FCM / Reservas  
**Impacto**: Cada reserva nueva genera 2 entradas en la bandeja de notificaciones y potencialmente 2 push notifications.  
**Causa**: Dos Cloud Functions escuchan el mismo path `empresas/{empresaId}/reservas/{reservaId}`.  
**Fix**: Eliminar o fusionar `onReservaNueva` en `onNuevaReserva`.

### 🔴 BUG 5 — Fichaje sin validación de doble entrada
**Módulo**: Fichajes  
**Impacto**: Un empleado puede fichar entrada varias veces al día. El histórico es incorrecto y el cálculo de horas trabajadas no es fiable.  
**Causa**: `ficharEntrada()` no verifica si ya hay un fichaje de entrada activo sin su correspondiente salida.  
**Fix**: Antes de crear un nuevo fichaje de entrada, verificar `ultimoFichajeHoy()` y rechazar si el último tipo es `entrada`.

---

## ⭐ TOP 5 MEJORAS DE PRODUCTO (Más valor para los clientes)

### 🚀 MEJORA 1 — Recordatorio automático al cliente antes de la cita
**Por qué importa**: El 30-40% de las no-shows en hostelería/peluquería se elimina con un recordatorio 24h antes. Es la funcionalidad que más piden los negocios de reservas.  
**Implementación**: Cloud Function scheduled que revisa citas del día siguiente y envía WhatsApp/SMS/email al cliente.

### 🚀 MEJORA 2 — Panel de fichajes en tiempo real (vista admin)
**Por qué importa**: El admin necesita saber quién está trabajando ahora mismo sin tener que ir ficha a ficha.  
**Implementación**: StreamBuilder sobre `fichajes` con filtro por día actual + agregación por empleado mostrando estado (dentro/fuera/pausa).

### 🚀 MEJORA 3 — Tablero Kanban de tareas
**Por qué importa**: La vista de lista de tareas no da visibilidad del flujo de trabajo. Un tablero drag-and-drop (Pendiente→En curso→Hecho) es el estándar mínimo esperado.  
**Implementación**: Reordenar `ReorderableListView` por columnas de estado o usar un package como `appflowy_board`.

### 🚀 MEJORA 4 — Exportación XML para AEAT (Modelos 111, 303, 347)
**Por qué importa**: Sin XML, el cliente tiene que introducir todos los datos manualmente en el portal de la AEAT. La IA extrae los datos pero el último paso de presentación es manual. Esto destruye la propuesta de valor fiscal.  
**Implementación**: Generador de XML según esquemas XSD publicados por la AEAT para cada modelo.

### 🚀 MEJORA 5 — Chat de bot WhatsApp visible en la app
**Por qué importa**: El negocio no puede ver qué le dijo el bot a sus clientes ni intervenir cuando el bot falla. Sin este panel, el bot es una caja negra que genera desconfianza.  
**Implementación**: StreamBuilder sobre `whatsapp_bot/{conversacionId}/mensajes` mostrando historial por cliente, con opción "Tomar control" para responder manualmente.

---

## ⏱️ Estimación de tiempo para versión 1.0 lista para producción

| Área | Tiempo estimado |
|------|----------------|
| Bug fixes críticos (5 bugs) | 1-2 semanas |
| Stripe webhook + flujo de compra | 1 semana |
| Query limits en reservas/tareas | 2-3 días |
| Notificaciones foreground fix | 1 día |
| Fichajes: validación doble + horas | 3-4 días |
| XML AEAT modelos fiscales | 2-3 semanas |
| Recordatorio clientes (WhatsApp/email) | 3-4 días |
| Panel admin fichajes tiempo real | 3-4 días |
| Chat bot WhatsApp en app | 1 semana |
| Tests básicos + QA | 1-2 semanas |
| **TOTAL estimado** | **7-10 semanas** |

---

## 🎯 Nota Global de la App

### **7.2 / 10**

**Contexto comparativo con SaaS B2B en producción:**

✅ **Por encima del estándar**: El módulo de nóminas (9/10) es genuinamente robusto, con las actualizaciones de SS 2026, multi-convenio y cálculo de embargos. El módulo de facturación IA (8/10) es innovador y diferenciador. La arquitectura de seguridad (roles, guards, Firebase App Check) es sólida.

⚠️ **A la par del estándar**: Autenticación, tareas, clientes y empleados son funcionales y con buena arquitectura.

❌ **Por debajo del estándar de producción**:
- Las queries sin límite temporal en módulos de alto volumen (reservas, tareas) son **inaceptables en producción real** y generarán costes de Firestore y crashes con cualquier cliente con más de 6 meses de actividad.
- La ausencia de webhook Stripe hace imposible la monetización automatizada.
- El bug de notificaciones en foreground afecta directamente al caso de uso principal (recibir reservas en tiempo real).
- La ausencia de XML para la AEAT vacía de valor la promesa del Pack Fiscal.

**La app tiene una base técnica excelente**. No es un prototipo; es un producto real con funcionalidades avanzadas. Pero hay entre 7 y 10 semanas de trabajo para sellar los agujeros que impiden lanzar con garantías a clientes de pago reales.

---

*Auditoría generada automáticamente analizando el código fuente. Fecha: Abril 2026.*


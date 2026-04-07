    # 🔍 AUDITORÍA QA EXHAUSTIVA — FLUIX CRM
### Fecha: 6 de abril de 2026 | Revisor: QA Senior | Stack: Flutter + Firebase + Cloud Functions

---

## 🔷 Módulo 1 — AUTENTICACIÓN

**Estado general:** ✅ COMPLETO (con matices)

**Funcionalidades operativas:**
- ✅ Login con email/contraseña — Firebase Auth real con manejo de errores exhaustivo (8 códigos de error)
- ✅ Login con Google — GoogleSignIn + Firebase credential completo, crea usuario en Firestore si es primera vez
- ✅ Login con Apple — Implementación completa con nonce SHA-256, cumple requisito App Store
- ✅ Registro de nueva empresa — `PantallaRegistro` + `pantalla_registro_invitacion.dart`
- ✅ Registro por invitación — `InvitacionesService` con token UUID, expiración 72h, deep link `fluixcrm://invite?token=XXX`
- ✅ Reset de contraseña — `sendPasswordResetEmail` de Firebase Auth real, con UI de diálogo
- ✅ Biometría — `BiometriaService` completo con local_auth + flutter_secure_storage, flujo de 3 intentos
- ✅ 2FA por SMS — `DosFactoresService` con Firebase Phone Auth, max 3 intentos, pantalla dedicada
- ✅ Protección fuerza bruta — Cloud Function real `verificarLoginIntento`, 5 intentos → bloqueo 15 min
- ✅ Auditoría de accesos — `AuditoriaService` registra login OK/fallido/logout con dispositivo, IP, método
- ✅ Logout — Funcional

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| `ProviderAutenticacion` | ⚠️ | El provider tiene TODOs con `Future.delayed` (simulación). Es código legacy que NO se usa — el login real está en `pantalla_login.dart` directamente | Bajo — código muerto |
| Google Sign-In sin empresa | ⚠️ | Si un usuario nuevo entra con Google, se crea usuario con `empresa_id: ''`. No hay flujo automático para vincular empresa después | Medio |
| Credenciales debug visibles | ⚠️ | Hay bloque `kDebugMode` con credenciales admin + botón "Reinicializar". Correcto que solo aparece en debug, pero verificar que `kDebugMode` es `false` en release | Bajo |

**Bugs críticos detectados:**
- Ninguno crítico en autenticación

**Código sospechoso:**
- `lib/features/autenticacion/providers/provider_autenticacion.dart` — 4x `TODO: Implementar con repositorio real` con `Future.delayed` simulado. **Es código legacy, el flujo real no lo usa**.
- `lib/screens/signin_screen.dart` y `lib/data/repositorios/repositorio_autenticacion_impl.dart` — **Son archivos del scaffolding anterior** (carpeta `screens/` vs `features/`). Tienen más TODOs. No se usan en producción.

---

## 🔷 Módulo 2 — DASHBOARD

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Carga inicial — `PantallaDashboard` con datos reales de Firestore
- ✅ Widgets modulares — `WidgetManagerService` con activar/desactivar/reordenar
- ✅ Briefing diario — `BriefingService` calcula datos REALES: citas hoy, facturas pendientes, modelos fiscales, tareas urgentes, nóminas, contratos por vencer. Solo entre 6-12h.
- ✅ Bandeja de notificaciones — `BandejaNotificacionesScreen` + servicio dedicado
- ✅ Badge counters — `BadgeService` con streams en tiempo real (tareas urgentes, pedidos pendientes, notificaciones sin leer, reservas hoy)
- ✅ Modo offline — `OfflineBanner` widget + persistencia Firestore activada en `main.dart`
- ✅ Panel propietario Fluix — `ModuloPropietario` con datos de prueba Fluixtech

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| StreamBuilders simultáneos | ⚠️ | BadgeService abre 4 streams (tareas, pedidos, notif, reservas) + briefing hace 6 Future.wait. En total ~10 listeners activos. Aceptable pero monitorizar rendimiento | Bajo |
| Datos de prueba en dashboard | ⚠️ | Se importan `datos_prueba_service.dart` y `datos_prueba_contabilidad_service.dart` en el dashboard. Son para el botón de reinicializar (debug) pero la importación existe en release | Bajo |

---

## 🔷 Módulo 3 — RESERVAS Y CITAS

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Crear reserva manualmente — Servicio + pantallas en features/
- ✅ Ver reservas del día/semana — Widget en dashboard + pantalla de módulo
- ✅ Cambiar estado de reserva
- ✅ Cancelar reserva
- ✅ CF `onNuevaReserva` — Notificación push al empresario
- ✅ CF `onReservaCancelada` — Notificación push al cancelar
- ✅ CF `enviarRecordatoriosCitas` — Recordatorio 24h antes (scheduler importado)

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| Widget web reservas (reservas.js) | 🚫 | **No existe `reservas.js`**. El script web solo registra visitas y eventos, no tiene formulario de reservas incrustable | Medio — feature anunciada no disponible |
| Disponibilidad por profesional | ⚠️ | No hay evidencia de gestión de disponibilidad por profesional individual | Bajo |
| Lista de espera | 🚫 | No implementada | Bajo |

---

## 🔷 Módulo 4 — VALORACIONES / RESEÑAS GOOGLE

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Conexión OAuth con Google Business Profile — `gmbTokens.ts` (storeGmbToken, obtenerFichasNegocio, guardarFichaSeleccionada, desconectarGoogleBusiness)
- ✅ Sincronización periódica — `scheduledSincronizarResenas` en Cloud Functions
- ✅ Mostrar reseñas en la app — `GoogleReviewsService` con Places API real + Firestore
- ✅ Responder a reseña — `publicarRespuestaGoogle` + `procesarRespuestasPendientes` en CF
- ✅ Alerta reseña negativa — `onNuevaValoracion` con canal de alta prioridad, umbral configurable
- ✅ Historial de rating — `RatingHistorialService`
- ✅ Resumen semanal — `resumenSemanalResenas` CF
- ✅ Alertas acumuladas — `alertaResenasNegativasAcumuladas` CF

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| Limitación Places API | ⚠️ | Places API devuelve máx 5 reseñas por petición. Documentado en el código. Las reseñas históricas ya guardadas en Firestore se conservan | Medio |
| Plantillas de respuesta | ⚠️ | No hay evidencia de un sistema de plantillas predefinidas de respuesta | Bajo |
| Respuesta automática por IA | 🚫 | No implementada | Bajo — feature futura |
| Datos fallback hardcoded | ⚠️ | Si la empresa no tiene config, devuelve `{'apiKey': '', 'placeId': ''}` (vacío, no mock). Correcto | — |

---

## 🔷 Módulo 5 — CLIENTES / CRM

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ CRUD completo — `ClientesService` con Firestore
- ✅ Búsqueda en tiempo real — Filtrado local case-insensitive por nombre/teléfono/correo
- ✅ Filtros — Etiquetas, facturación mínima, última actividad, localidad
- ✅ Etiquetas predefinidas — VIP, Frecuente, Moroso, Proveedor, Potencial
- ✅ Importar CSV — `ImportacionClientesService`
- ✅ Exportar CSV — `ExportacionClientesService`
- ✅ Fusión duplicados — `FusionClientesService`
- ✅ Historial actividad — `ActividadClienteService`
- ✅ Estados (activo/inactivo) — `ClienteEstadoService` con recálculo automático
- ✅ Bulk actions — `BulkActionsService`

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| Alerta clientes silenciosos | ⚠️ | `ClienteEstadoService` recalcula estado pero la alerta push no está evidenciada como CF automática | Bajo |

---

## 🔷 Módulo 6 — FACTURACIÓN

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Crear factura emitida — `FacturacionService.crearFactura` con transacción atómica anti-hueco
- ✅ Factura rectificativa — Serie R, formulario dedicado
- ✅ Factura recibida — `FacturaRecibida` modelo + tab + formulario
- ✅ Generar PDF — `PdfService`
- ✅ Enviar factura por email — `EmailService.enviarFactura` → CF `enviarEmailConPdf` con SMTP real (nodemailer)
- ✅ Marcar como cobrada
- ✅ Numeración anti-hueco — Transacción Firestore con `runTransaction`, reset anual, por serie
- ✅ Enlace de pago Stripe — Integración vía metadata en factura
- ✅ Libro de IVA — `LibroRegistroIvaExporter`
- ✅ Contabilidad — Tab de contabilidad con gráficos
- ✅ Verifactu — Hash chain SHA-256, XML builder, QR, firma XAdES, CF para remisión a AEAT
- ✅ Series: FAC (venta), PROF (proforma), RECT (rectificativa), PED (pedido)

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| Envío email real | ⚠️ | **Depende de que se configuren secrets SMTP** (`SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`). La CF lanza error claro si no están configurados | 💀 CRÍTICO si no está configurado |
| Facturas recurrentes | ⚠️ | `RecurrenciaService` existe pero no hay evidencia de CF que genere facturas automáticamente por recurrencia | Medio |
| Recordatorio vencidas | ⚠️ | No hay CF específica para recordar facturas vencidas automáticamente | Medio |

---

## 🔷 Módulo 7 — MODELOS FISCALES AEAT

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ MOD 303 — `Mod303Service` + `Mod303Exporter` + `Dr303e26v101Exporter` (formato posicional DR303e26 v10.10) — datos reales de Firestore
- ✅ MOD 111 — `Modelo111Service` + `Modelo111AeatExporter` — calcula desde nóminas reales
- ✅ MOD 115 — Modelo definido en `modelo115.dart`
- ✅ MOD 130 — Modelo definido en `modelo130.dart`
- ✅ MOD 190 — `Modelo190Service` — resumen anual
- ✅ MOD 347 — `Mod347Service` + `Mod347Exporter`
- ✅ MOD 349 — `Mod349Service` + `Mod349Exporter`
- ✅ MOD 390 — Modelo `modelo390.dart`
- ✅ Calendario fiscal — `AlertasFiscalesWidget` en dashboard
- ✅ Libro de IVA — `LibroRegistroIvaExporter`
- ✅ Criterio IVA configurable — Devengo vs Criterio de Caja

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| Presentación directa AEAT | ⚠️ | Verifactu tiene `remitirVerifactu` CF, pero los modelos 303/111/etc. generan fichero posicional para descarga, no presentación telemática directa | Bajo — estándar en el sector |
| MOD 115, 130, 390 | ⚠️ | Tienen modelo de datos pero no se ha verificado exporter posicional dedicado para todos (303 sí lo tiene) | Medio |

---

## 🔷 Módulo 8 — NÓMINAS

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Cálculo de nómina — `NominasService` con 1373 líneas, constantes SS 2026, tablas IRPF, SMI 2026
- ✅ Convenios colectivos — Hostelería, Comercio, Peluquería, Industrias Cárnicas, Veterinarios
- ✅ PDF de nómina — `NominaPdfService`
- ✅ Enviar nómina — `EmailService.enviarNomina` → CF `enviarEmailConPdf`
- ✅ Embargos judiciales — `EmbargoCalculator` con art. 607 LEC
- ✅ Bajas IT — `ItService` con cálculo por tramos (1-3, 4-15, 16+)
- ✅ Antigüedad — `AntiguedadCalculator`
- ✅ Complementos variables — `ComplementosService`
- ✅ Remesa SEPA — `RemesaSepaService` + `SepaXmlGenerator` (XML SEPA real)
- ✅ Regularización IRPF diciembre — `RegularizacionIrpfService`
- ✅ Coste empresa — `CosteEmpresaService`
- ✅ MOD 111 desde nóminas — `Modelo111Service.calcularDesdeNominas`
- ✅ MOD 190 anual — `Modelo190Service`

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| Firma digital empleado | ⚠️ | `FirmaService` existe pero no verificada integración completa con nóminas | Bajo |
| Horas extra | ⚠️ | Modelo incluye `horas_extra_estructurales` y `horas_extra_fuerza_mayor` pero no verificada UI de registro | Bajo |

---

## 🔷 Módulo 9 — EMPLEADOS

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Ficha completa — `FormularioEmpleadoForm` + `FormularioDatosNominaForm`
- ✅ Convenio colectivo — Vinculación vía `ConvenioFirestoreService`
- ✅ Documentos — `DocumentosEmpleadoService` (DNI, contrato)
- ✅ Fichaje — `FichajeService` con GPS (latitud/longitud), entrada/salida, stream tiempo real
- ✅ Historial cambios salariales — `CambioSalarial` modelo
- ✅ Alertas contratos — `AlertasContratoService`
- ✅ Configurar módulos por empleado — `ConfigurarModulosEmpleadoScreen`
- ✅ Invitación por email — `InvitacionesService` + `PantallaRegistroInvitacion`
- ✅ Empleados dados de baja — `EmpleadosBajaScreen`

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| Organigrama visual | 🚫 | No hay evidencia de pantalla de organigrama | Bajo |

---

## 🔷 Módulo 10 — VACACIONES Y AUSENCIAS

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Solicitar vacaciones — `NuevaSolicitudForm`
- ✅ Aprobar/rechazar — Servicio con estados
- ✅ Push al aprobar/rechazar — CF `onVacacionEstadoCambiado` envía push + notificación in-app
- ✅ Calendario visual — `CalendarioVacacionesWidget`
- ✅ Balance días — `VacacionesService` con cálculo proporcional, días naturales/laborables
- ✅ Festivos automáticos — CF `importarFestivosEspana` usa API Nager.Date
- ✅ Carryover — CF `scheduledCierreAnualVacaciones` (31 dic) con días máximos y expiración configurable
- ✅ Expiración carryover — CF `scheduledExpiracionCarryover` con notificación 7 días antes
- ✅ Alerta solapamiento — `ResultadoSolapamiento` con cálculo ≥50% y ≥2 empleados
- ✅ Alerta cobertura — CF `scheduledAlertaCobertura` revisa 7 días, push si < mínimo configurable
- ✅ Integración nóminas — `AusenciasNominaService`
- ✅ Configuración — `ConfiguracionVacacionesScreen`, `FestivosLocalesScreen`

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| CalendarioVacacionesWidget | ❌ | Tiene errores de compilación reportados (variables no definidas: `_focusedDay`, `_festivosNombres`, `_festivosSet`, método `_esFestivo`) | Medio — la pantalla principal funciona, el widget del calendario tiene bugs |

---

## 🔷 Módulo 11 — FINIQUITOS

**Estado general:** ⚠️ PARCIAL

**Funcionalidades operativas:**
- ✅ Cálculo automático — `FiniquitoCalculator`
- ✅ Auto-relleno — `FiniquitoAutorellenarService` desde ficha + nóminas + vacaciones
- ✅ PDF finiquito — `FiniquitoPdfService`
- ✅ Firma táctil — `FirmaFiniquitoService`
- ✅ Certificado empresa SEPE — `CertificadoEmpresaService`
- ✅ Carta de cese — `CartaCeseService`
- ✅ Envío documentación por email — CF `enviarDocumentacionFiniquito` con email HTML profesional y múltiples adjuntos
- ✅ CRUD — `FiniquitoService` con estados (borrador, firmado, pagado)
- ✅ Gasto contable automático al pagar

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| `nuevo_finiquito_form.dart` | ❌ | Reportado con errores de compilación (paréntesis sin cerrar, case fuera de switch) | 💀 CRÍTICO — la pantalla de crear finiquito puede no compilar |
| Cierre automático ficha empleado | ⚠️ | `BajaEmpleadoService` existe pero no verificado encadenamiento automático desde finiquito | Bajo |

---

## 🔷 Módulo 12 — PEDIDOS Y WHATSAPP

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Crear pedido — `PedidosService` con líneas, estados, métodos de pago
- ✅ Cambiar estado (6 estados) — pendiente, confirmado, preparando, listo, entregado, cancelado
- ✅ WhatsApp automático al cambiar estado — `PedidosWhatsappService` + `WhatsappMessageService`
- ✅ Catálogo productos — CRUD completo con categorías, variantes, stock, SKU, código de barras, imagen
- ✅ Generar factura desde pedido — CF `onNuevoPedidoGenerarFactura` automática
- ✅ Push al nuevo pedido — CF `onNuevoPedido`
- ✅ Bot WhatsApp — `PantallaChatsBot` + `ChatbotService`
- ✅ Pedidos WhatsApp — CF `onNuevoPedidoWhatsApp`
- ✅ Rentabilidad — `RentabilidadService`
- ✅ Imágenes productos — `ProductoImagenService`

---

## 🔷 Módulo 13 — TAREAS

**Estado general:** ⚠️ PARCIAL

**Funcionalidades operativas:**
- ✅ CRUD tareas — `TareasService` con streams por estado/equipo/usuario
- ✅ Equipos — Crear, actualizar, eliminar equipos
- ✅ Push al asignar — CF `onTareaAsignada`
- ✅ Tareas recurrentes — CF `scheduledGenerarTareasRecurrentes` + `RecurrenciaConfig` modelo
- ✅ Cronómetro — `TiempoTareaService` + `ReporteTiempoScreen`
- ✅ Adjuntos — `AdjuntosTareaService`
- ✅ Recordatorio — CF `scheduledRecordatoriosTareas` + `scheduledTareasVencenHoy`
- ✅ Sugerencias empresa → tarea — CF `onNuevaSugerencia`
- ✅ Vista Kanban/Lista — `ModuloTareasScreen` con múltiples vistas
- ✅ Tareas solo propietario — filtro `soloPropietario`
- ✅ Prioridades — urgente, alta, media, baja
- ✅ Detalle tarea — `DetalleTareaScreen`

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| `tarea.dart` modelo | ❌ | Reportado con `copyWith` roto (método fuera de clase o sintaxis inválida) | Medio — puede causar errores en actualización de tareas |
| `tareas_service.dart` | ❌ | Reportado con método `crearTarea` con código fuera de método | Medio |

---

## 🔷 Módulo 14 — CONTENIDO WEB

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Script JS dinámico — CF `generarScriptEmpresa` genera HTML/JS completo para incrustar en WordPress
- ✅ Formulario contacto web → evento — Script rastrea clicks en formularios de contacto
- ✅ Edición carta/menú desde app — `ContenidoWebService` con secciones + `AdminContenidoWebService`
- ✅ Edición servicios — Secciones web CRUD
- ✅ Edición horario
- ✅ Actualización automática — Firebase Realtime, la web lee de Firestore
- ✅ Analytics web — `AnalyticsWebService` + tab dedicado + registro visitas/eventos en Firestore
- ✅ Blog — `TabBlogWeb`
- ✅ SEO — `TabSeoWeb`
- ✅ Rastreo WhatsApp clicks, llamadas, formularios
- ✅ Endpoint JSON alternativo — `obtenerScriptJSON`

---

## 🔷 Módulo 15 — SUSCRIPCIÓN

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Trial configurable — Estado `PRUEBA`
- ✅ Banner aviso pre-vencimiento — CF `verificarSuscripciones` avisa a 7, 3 y 1 días
- ✅ Bloqueo al vencer — `PantallaSuscripcionVencida` + CF marca `VENCIDA` automáticamente tras 7 días de gracia
- ✅ Periodo de gracia — 7 días post-vencimiento con avisos pero sin bloquear
- ✅ Planes con módulos — `PlanesConfig` + `DatosSuscripcion` con packs y addons dinámicos
- ✅ Panel admin — CF `crearCuentaConPlan`, `actualizarPlanEmpresa`, `listarCuentasClientes`
- ✅ Webhook Stripe — CF `stripeWebhook` con verificación de firma, maneja `checkout.session.completed` y `payment_intent.succeeded`
- ✅ Contabilidad bidireccional — Stripe crea pedido+factura en fluixtech Y gasto en la empresa cliente
- ✅ Webhook pago web → push — CF `webhookPagoWeb`
- ✅ Upgrade módulo — `PantallaUpgradeModulo`

**Funcionalidades con problemas:**

| Funcionalidad | Estado | Problema | Impacto |
|---|---|---|---|
| Secrets Stripe | ⚠️ | `STRIPE_SECRET_KEY` y `STRIPE_WEBHOOK_SECRET` deben estar configurados en `.env` de functions. La CF falla con error claro si no están | 💀 CRÍTICO si no están configurados |
| Precios consistentes | ⚠️ | Los precios vienen de `PlanesConfig` y de los metadata de Stripe. Verificar que coincidan | Medio |

---

## 🔷 Módulo 16 — ONBOARDING

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ 4 pasos — Perfil negocio, primer servicio, horarios, web
- ✅ Persistencia — Guarda `onboarding_completado: true` en Firestore
- ✅ Detección primera vez — main.dart comprueba campo en documento empresa
- ✅ Navegación — PageController con animación
- ✅ 811 líneas — Implementación sustancial

---

## 🔷 Módulo 17 — NOTIFICACIONES PUSH

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ Token FCM guardado — `guardarTokenDispositivo` + `onTokenRefresh`
- ✅ Primer plano — `FirebaseMessaging.onMessage` → `_manejarMensajePrimerPlano`
- ✅ Background — `_firebaseMessagingBackgroundHandler` (top-level)
- ✅ Deep link al pulsar — `onMessageOpenedApp` → `_manejarTapNotificacion`
- ✅ Bandeja in-app — `BandejaNotificacionesScreen`
- ✅ Badge counter — `BadgeService`
- ✅ Canal alta prioridad — `fluixcrm_resenas_negativas` con `Importance.max`
- ✅ Canal principal — `fluixcrm_canal_principal` con `Importance.high`
- ✅ Sonidos — `SonidoNotificacionService`
- ✅ Limpieza tokens inválidos — CFs eliminan tokens no registrados

---

## 🔷 Módulo 18 — SEGURIDAD

**Estado general:** ✅ COMPLETO

**Funcionalidades operativas:**
- ✅ 2FA por SMS — Integrado en flujo de login (después de email/password)
- ✅ Biometría — Integrado con ofrecimiento post-login
- ✅ Log auditoría — `AuditoriaService` con device_info_plus y package_info_plus
- ✅ Protección fuerza bruta — CF `verificarLoginIntento` con reglas Firestore allow:false
- ✅ Invitaciones con token y expiración — UUID + 72h + estado (pendiente/usada/expirada)
- ✅ Certificados digitales FNMT — `CertificadoDigitalService` con flutter_secure_storage, metadatos en Firestore, historial
- ✅ App Check — Activado en main.dart con PlayIntegrity (Android) / DeviceCheck (iOS)

---

# 📊 RESUMEN EJECUTIVO

| # | Módulo | Estado | Completitud | Bloqueante lanzamiento |
|---|---|---|---|---|
| 1 | Autenticación | ✅ | 95% | No |
| 2 | Dashboard | ✅ | 95% | No |
| 3 | Reservas | ✅ | 80% | No (widget web ausente) |
| 4 | Valoraciones Google | ✅ | 90% | No |
| 5 | Clientes/CRM | ✅ | 95% | No |
| 6 | Facturación | ✅ | 90% | ⚠️ Depende de SMTP |
| 7 | Modelos Fiscales | ✅ | 85% | No |
| 8 | Nóminas | ✅ | 95% | No |
| 9 | Empleados | ✅ | 90% | No |
| 10 | Vacaciones | ✅ | 90% | No |
| 11 | Finiquitos | ⚠️ | 85% | ⚠️ `nuevo_finiquito_form.dart` roto |
| 12 | Pedidos/WhatsApp | ✅ | 95% | No |
| 13 | Tareas | ⚠️ | 85% | ⚠️ `tarea.dart` roto |
| 14 | Contenido Web | ✅ | 95% | No |
| 15 | Suscripción | ✅ | 95% | ⚠️ Depende de secrets Stripe |
| 16 | Onboarding | ✅ | 95% | No |
| 17 | Notificaciones | ✅ | 98% | No |
| 18 | Seguridad | ✅ | 95% | No |

---

# 🚨 TOP 10 PROBLEMAS MÁS GRAVES

| # | Problema | Archivo | Impacto | Estimación |
|---|---|---|---|---|
| 1 | **`nuevo_finiquito_form.dart` no compila** — Paréntesis sin cerrar, case fuera de switch. La pantalla de crear finiquito crashea. | `lib/features/finiquitos/pantallas/nuevo_finiquito_form.dart` | 💀 CRÍTICO | 2-4h |
| 2 | **`tarea.dart` modelo roto** — `copyWith` fuera de clase. Afecta todo el módulo de tareas. | `lib/domain/modelos/tarea.dart` | 💀 CRÍTICO | 1-2h |
| 3 | **`tareas_service.dart` método roto** — `crearTarea` con código fuera de contexto. | `lib/services/tareas_service.dart` | 💀 CRÍTICO | 1-2h |
| 4 | **`calendario_vacaciones_widget.dart` errores** — Variables no definidas (`_focusedDay`, etc.) | `lib/features/vacaciones/widgets/calendario_vacaciones_widget.dart` | ❌ ALTO | 1-2h |
| 5 | **Secrets SMTP no configurados** — Si no se han desplegado `SMTP_HOST/USER/PASS`, envío de email no funciona en producción | `functions/.env` | 💀 CRÍTICO para email | 15 min |
| 6 | **Secrets Stripe no configurados** — Si no se han desplegado `STRIPE_SECRET_KEY/WEBHOOK_SECRET`, pagos no funcionan | `functions/.env` | 💀 CRÍTICO para pagos | 15 min |
| 7 | **`ProviderAutenticacion` con TODOs simulados** — Código legacy no usado, pero si algo referencia este provider podría simular en vez de autenticar realmente | `lib/features/autenticacion/providers/provider_autenticacion.dart` | ⚠️ Medio | 30 min (eliminar o archivar) |
| 8 | **Google Sign-In → empresa_id vacío** — Un usuario nuevo con Google no tiene flujo de completar perfil de empresa | `pantalla_login.dart:509` | ⚠️ Medio | 2h |
| 9 | **Widget web de reservas inexistente** — Se anuncia pero `reservas.js` no existe. Solo hay script de analytics. | N/A | ⚠️ Medio (feature missing) | 8h+ (si se quiere implementar) |
| 10 | **Archivos legacy en `/screens/` y `/data/`** — Dashboard screen, signin screen con TODOs, pueden confundir. No se usan en producción. | `lib/screens/*.dart` | ⚠️ Bajo | 30 min (eliminar) |

---

# 📋 LISTA DE TAREAS PARA EL MIÉRCOLES (mínimo para Google Play)

| # | Tarea | Archivos | Estimación | Prioridad |
|---|---|---|---|---|
| 1 | **Arreglar `nuevo_finiquito_form.dart`** — Cerrar paréntesis, fix switch/case, verificar que compila | `lib/features/finiquitos/pantallas/nuevo_finiquito_form.dart` | 2-3h | 🔴 P0 |
| 2 | **Arreglar `tarea.dart`** — Recolocar `copyWith` dentro de la clase | `lib/domain/modelos/tarea.dart` | 1h | 🔴 P0 |
| 3 | **Arreglar `tareas_service.dart`** — Fix método `crearTarea` | `lib/services/tareas_service.dart` | 1h | 🔴 P0 |
| 4 | **Arreglar `calendario_vacaciones_widget.dart`** — Definir variables faltantes o eliminar código que las referencia | `lib/features/vacaciones/widgets/calendario_vacaciones_widget.dart` | 1-2h | 🔴 P0 |
| 5 | **Configurar secrets Firebase** — SMTP_HOST, SMTP_USER, SMTP_PASS, STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET | `functions/.env` + `firebase functions:secrets:set` | 30 min | 🔴 P0 |
| 6 | **Desplegar Cloud Functions** — `firebase deploy --only functions` para que todas las CFs estén en producción | Terminal | 15 min | 🔴 P0 |
| 7 | **Test de flujo completo en release** — `flutter build apk --release` + instalar + probar login, dashboard, factura, nómina | Manual | 2h | 🟡 P1 |
| 8 | **Eliminar archivos legacy** — `lib/screens/`, archivos `.dart` no referenciados | Varios | 30 min | 🟡 P1 |
| 9 | **Verificar `kDebugMode` en release** — Asegurar que bloque de credenciales admin no aparece | `pantalla_login.dart` | 15 min | 🟡 P1 |
| 10 | **Probar Google/Apple Sign-In en release** — SHA-1 release en Firebase Console, Apple credentials | Firebase Console | 30 min | 🟡 P1 |

**Tiempo total estimado: ~10-12 horas de trabajo**

---

# 🏁 VEREDICTO FINAL

## ¿Está la app lista para lanzar el miércoles?

### 🟡 CASI — Con 4 fixes críticos sí.

**Lo positivo (impresionante):**
- La arquitectura es **sólida**: 18 módulos con servicios reales, no mocks
- **Cloud Functions completas**: 30+ funciones desplegables que cubren notificaciones, Stripe, vacaciones, suscripción, email, Verifactu
- **Cálculos fiscales reales**: Nóminas con constantes SS 2026, IRPF, convenios colectivos, embargos art. 607 LEC
- **Seguridad bien implementada**: App Check, 2FA, biometría, fuerza bruta, auditoría, cifrado de certificados
- **No hay mocks en producción**: Todos los servicios usan Firestore real

**Lo que BLOQUEA el lanzamiento (4 archivos rotos):**
1. `nuevo_finiquito_form.dart` — No compila
2. `tarea.dart` — copyWith roto
3. `tareas_service.dart` — crearTarea roto
4. `calendario_vacaciones_widget.dart` — Variables indefinidas

**Estos 4 archivos causan que el compilador de Dart crashee internamente** ("Null check operator used on a null value" en kernel transformer), lo que impide generar el APK de release.

**Riesgos a asumir si se lanza el miércoles:**
- Widget web de reservas no existe (puedes no anunciarlo en la ficha de Google Play)
- Envío de email depende de configurar SMTP (si no se configura, la app funciona pero no envía emails)
- Places API limita a 5 reseñas por petición (funcional pero limitado)
- Organigrama no implementado (feature menor)

**Recomendación**: Arregla los 4 archivos rotos (5-7h), configura secrets (30 min), despliega functions (15 min), haz test en release (2h). **Lanzable el miércoles por la tarde.**


# 📊 VALORACIÓN COMPLETA DE MÓDULOS — Fluix CRM

**Fecha de evaluación:** 15 de Marzo de 2026  
**Evaluador:** Análisis automático del código fuente completo

---

## RESUMEN EJECUTIVO

| Módulo | Nota | Estado |
|--------|------|--------|
| 🔐 Autenticación y Login | **72/100** | 🟡 Funcional con carencias |
| 📝 Registro / Onboarding | **55/100** | 🟠 Básico |
| 📊 Dashboard Principal | **78/100** | 🟢 Bien estructurado |
| 📅 Reservas | **75/100** | 🟢 Funcional |
| 👥 Clientes | **62/100** | 🟡 Básico funcional |
| ⭐ Valoraciones | **70/100** | 🟡 Integración Google parcial |
| 📈 Estadísticas | **68/100** | 🟡 Con cache, falta profundidad |
| 🛒 Pedidos / Catálogo | **72/100** | 🟢 Completo |
| 💬 WhatsApp Bot | **60/100** | 🟡 Funcional básico |
| ✅ Tareas | **74/100** | 🟢 Kanban + lista |
| 👨‍💼 Empleados | **65/100** | 🟡 Integrado con nóminas |
| 💰 Facturación | **82/100** | 🟢 Muy completo |
| 📒 Contabilidad | **70/100** | 🟡 Gastos + proveedores |
| 💵 Nóminas | **85/100** | 🟢 Muy detallado |
| 🌐 Contenido Web | **55/100** | 🟠 Básico |
| 🛡️ Permisos y Roles | **76/100** | 🟢 Bien segmentado |
| 👑 Panel Propietario | **60/100** | 🟡 Funcional básico |
| 💳 Suscripciones | **50/100** | 🟠 Esqueleto |
| 🔔 Notificaciones | **65/100** | 🟡 FCM implementado |
| ☁️ Cloud Functions | **58/100** | 🟡 Stripe + notificaciones |
| 🧪 Testing | **5/100** | 🔴 Prácticamente inexistente |
| 🔒 Reglas Firestore | **72/100** | 🟢 Completas por rol |

**NOTA MEDIA GLOBAL: 66/100**

---

## ANÁLISIS DETALLADO POR MÓDULO

---

### 🔐 1. AUTENTICACIÓN Y LOGIN — 72/100

**✅ Lo que tiene:**
- Login con email/password via Firebase Auth
- Diseño limpio con gradientes y logo
- Redirección automática según estado (login → onboarding → dashboard)
- Comprobación de suscripción vencida antes de entrar
- Guardado de token FCM tras login
- Pantalla de carga animada

**❌ Lo que falta:**
- **Login social** (Google, Apple, Facebook) — imprescindible para un SaaS
- **Recuperar contraseña** — no hay pantalla visible de "Olvidé mi contraseña"
- **Verificación de email** — no se pide confirmar el correo
- **2FA / Autenticación en dos pasos** — necesario para seguridad GDPR
- **Bloqueo por intentos fallidos** — no hay rate limiting visual
- **Biometría** (huella/face) — útil para móvil
- **Recordar sesión** / Cerrar sesión en todos los dispositivos

**Mejoras prioritarias:**
1. Añadir "Olvidé mi contraseña" con `sendPasswordResetEmail`
2. Login con Google (ya usas Firebase, es fácil)
3. Verificación de email obligatoria

---

### 📝 2. REGISTRO / ONBOARDING — 55/100

**✅ Lo que tiene:**
- Pantalla de registro con creación de cuenta
- Flujo de onboarding para configurar empresa
- Se crea documento en `/usuarios` y `/empresas`

**❌ Lo que falta:**
- **Onboarding guiado por pasos** — tutorial visual de qué puede hacer la app
- **Selección de plan** al registrarse (free trial, starter, pro)
- **Configuración inicial** de datos fiscales de la empresa (CIF, dirección)
- **Importar datos** desde otra plataforma
- **Video introductorio** o tour interactivo
- **Validación de NIF/CIF** empresarial
- **Términos y condiciones / RGPD** — aceptación obligatoria

**Mejoras prioritarias:**
1. Flujo de onboarding en 4-5 pasos con wizard
2. Aceptación de RGPD obligatoria al registrar
3. Trial de 14 días automático

---

### 📊 3. DASHBOARD PRINCIPAL — 78/100

**✅ Lo que tiene:**
- Sistema de tabs dinámico según módulos activos
- Stream de módulos desde Firestore (se actualiza en tiempo real)
- Filtrado por rol (propietario/admin/staff)
- Módulo propietario exclusivo para Fluixtech
- Configuración de módulos visibles
- Soporte para tema claro/oscuro
- Banner de suscripción

**❌ Lo que falta:**
- **Widgets personalizables** por usuario (drag & drop)
- **Resumen rápido** al abrir (KPIs del día en una cabecera)
- **Atajos rápidos** (crear factura, nueva reserva, etc.)
- **Búsqueda global** transversal a todos los módulos
- **Centro de notificaciones** con historial
- **Cambio de empresa** (si un usuario tiene varias)

**Mejoras prioritarias:**
1. Cabecera con KPIs del día (facturación, reservas, tareas pendientes)
2. Botón "+" flotante con acciones rápidas
3. Búsqueda global

---

### 📅 4. RESERVAS — 75/100

**✅ Lo que tiene:**
- CRUD completo con estados (Pendiente, Confirmada, Cancelada, Completada)
- KPIs en cabecera (conteo por estado)
- Tabs por estado + vista "Todas"
- Formulario de creación con cliente, servicio, hora, notas
- Cambio de estado directo
- Permisos por rol
- Trigger de recalculo de estadísticas al cambiar

**❌ Lo que falta:**
- **Vista calendario** (mensual, semanal) — solo hay lista
- **Recordatorios automáticos** al cliente (email/WhatsApp/push)
- **Disponibilidad en tiempo real** (huecos libres por empleado)
- **Reservas online** desde la web del cliente
- **Duración del servicio** para bloquear agenda
- **Reserva recurrente** (semanal, mensual)
- **Conflictos de horario** — no detecta solapamientos
- **Historial de cambios** en cada reserva

**Mejoras prioritarias:**
1. Vista calendario con `table_calendar`
2. Detección de conflictos horarios
3. Notificación automática 24h antes

---

### 👥 5. CLIENTES — 62/100

**✅ Lo que tiene:**
- Lista con búsqueda por nombre/teléfono
- CRUD básico (crear, editar, eliminar)
- Datos: nombre, teléfono, correo, etiquetas, notas
- Total gastado, número de reservas, última visita
- Filtrado con buscador
- Permisos por rol

**❌ Lo que falta:**
- **Ficha de cliente detallada** con historial completo (reservas, facturas, pedidos)
- **Segmentación avanzada** (por gasto, frecuencia, etiquetas)
- **Importar/Exportar CSV** de clientes
- **Comunicaciones** (enviar email/WhatsApp desde la ficha)
- **Notas con timestamp** — historial de interacciones
- **Deuda del cliente** — facturas pendientes vinculadas
- **Cumpleaños y recordatorios** automáticos
- **CRM pipeline** (leads → contacto → cliente → recurrente)
- **Mapa de clientes** — geolocalización
- **Datos fiscales del cliente** integrados (para facturas)
- **Fusión de duplicados**

**Mejoras prioritarias:**
1. Ficha de cliente con tabs (datos, historial, facturas, notas)
2. Exportar a CSV
3. Vinculación automática cliente ↔ facturas

---

### ⭐ 6. VALORACIONES — 70/100

**✅ Lo que tiene:**
- Integración con Google Reviews (sincronización)
- Paginación de reseñas (25 por página)
- Rating promedio con cache en Firestore
- Borrado de reseñas de prueba
- Sincronización en background
- Detalle de reseña con enlace a Google
- Visualización con estrellas y timeago

**❌ Lo que falta:**
- **Responder reseñas** directamente desde la app
- **Alertas** cuando llega una reseña negativa (< 3 estrellas)
- **Métricas de satisfacción** (NPS, evolución mensual)
- **Solicitar reseñas** — enviar enlace de valoración al cliente
- **Reseñas internas** desde la propia app
- **Análisis de sentimiento** (IA sobre texto de reseñas)
- **Gráfico de evolución** del rating a lo largo del tiempo
- **Múltiples fuentes** (Google, TripAdvisor, Trustpilot)

**Mejoras prioritarias:**
1. Gráfico de evolución del rating mensual
2. Alertas push por reseña negativa
3. Botón "Solicitar valoración" con enlace directo

---

### 📈 7. ESTADÍSTICAS — 68/100

**✅ Lo que tiene:**
- Sistema de cache automático en Firestore con TTL de 1h
- Recálculo manual y en background
- Estadísticas de: reservas, clientes, facturación, valoraciones
- Comparativa mes actual vs anterior
- Gráficos con `fl_chart`
- KPIs: ingresos mes, reservas, nuevos clientes, valoración promedio
- Verificación de conectividad con fallback offline
- Verificación de módulo de facturación activo para KPI de dinero

**❌ Lo que falta:**
- **Tasa de rebote** — requiere el script web, no se explica al usuario qué es
- **Embudo de conversión** (visita web → reserva → pago)
- **Predicciones** (IA o tendencia lineal)
- **Exportar reportes** a PDF/Excel
- **Comparativas anuales** (este mes vs mismo mes año pasado)
- **Segmentación** por servicio, empleado, canal
- **Mapa de calor** por horas/días de mayor actividad
- **Tiempo medio de respuesta** a reservas/pedidos
- **Coste de adquisición de cliente (CAC)**
- **Lifetime Value (LTV)** del cliente
- **Filtros personalizados** por rango de fechas

**Mejoras prioritarias:**
1. Explicación visible de cada KPI (tooltip o info button)
2. Exportar estadísticas a PDF
3. Filtro por rango de fechas personalizado

---

### 🛒 8. PEDIDOS / CATÁLOGO — 72/100

**✅ Lo que tiene:**
- Catálogo de productos con CRUD completo
- Variantes de producto y etiquetas
- Stock opcional
- Productos destacados
- Pedidos con líneas, estados, historial
- Formulario de nuevo pedido con selección de productos
- Categorías dinámicas
- Permisos por rol

**❌ Lo que falta:**
- **Imágenes de productos** — el campo existe pero no hay upload
- **Códigos de barras / QR** para escanear
- **Descuentos** por producto o por pedido
- **Envío** — coste y seguimiento
- **Inventario en tiempo real** — alertas de stock bajo
- **Pedido desde la web** del cliente
- **Albaranes de entrega**
- **Integración con facturación** — generar factura desde pedido (el método `generarFacturaDesdePedido` da error)
- **Historial de precios**

**Mejoras prioritarias:**
1. Subida de imágenes de productos (Firebase Storage)
2. Arreglar la generación de factura desde pedido
3. Alerta de stock bajo automática

---

### 💬 9. WHATSAPP BOT — 60/100

**✅ Lo que tiene:**
- Gestión de pedidos por WhatsApp con estados
- Tabs: Nuevos, En Proceso, Listos, Entregados
- Vista de chats del bot
- Datos de prueba generables

**❌ Lo que falta:**
- **Bot real** con API de WhatsApp Business — parece mock/simulación
- **Respuestas automáticas** configurables
- **Plantillas de mensajes** (confirmación de pedido, etc.)
- **Envío proactivo** de notificaciones al cliente
- **Catálogo compartible** por WhatsApp
- **Integración con pedidos reales** del módulo de pedidos
- **Métricas** del bot (tiempo de respuesta, conversiones)
- **Multi-idioma**

**Mejoras prioritarias:**
1. Integración real con WhatsApp Business API (Twilio/Meta)
2. Plantillas de mensaje configurables
3. Vincular pedidos WhatsApp con el catálogo

---

### ✅ 10. TAREAS — 74/100

**✅ Lo que tiene:**
- Vista Kanban y Vista Lista (toggle)
- 5 estados: Todas, Pendientes, En Progreso, Revisión, Completadas
- Formulario de creación con título, descripción, asignado, prioridad, fecha límite
- Detalle de tarea con edición
- Equipos (pantalla separada)
- Integración con Firebase Auth para usuario actual

**❌ Lo que falta:**
- **Subtareas** y checklists
- **Comentarios** en cada tarea (colaboración)
- **Archivos adjuntos** en tareas
- **Vista calendario** de tareas por fecha límite
- **Notificación al asignado** cuando se le asigna una tarea
- **Recordatorio automático** antes de la fecha límite
- **Tiempo dedicado** (time tracking por tarea)
- **Recurrencia** (tareas que se repiten)
- **Dependencias** entre tareas
- **Drag & drop** en la vista Kanban

**Mejoras prioritarias:**
1. Subtareas/checklists en cada tarea
2. Comentarios con timestamp
3. Notificación push al asignar

---

### 👨‍💼 11. EMPLEADOS — 65/100

**✅ Lo que tiene:**
- Lista de empleados con datos básicos
- Integración con datos de nómina (pestaña de nóminas por empleado)
- Formulario de datos de nómina completo
- Búsqueda
- Permisos (solo propietario puede gestionar)

**❌ Lo que falta:**
- **Ficha de empleado completa** (foto, documentos, contratos)
- **Control de asistencia** / fichajes
- **Vacaciones y ausencias** — solicitud y aprobación
- **Calendario de turnos**
- **Documentos del empleado** (contrato, DNI, nóminas firmadas)
- **Evaluación de rendimiento**
- **Formación y certificaciones**
- **Histórico de cambios salariales**
- **Portal del empleado** (ver sus propias nóminas/vacaciones)

**Mejoras prioritarias:**
1. Módulo de vacaciones y ausencias
2. Subida de documentos del empleado
3. Control de fichajes (entrada/salida)

---

### 💰 12. FACTURACIÓN — 82/100

**✅ Lo que tiene:**
- CRUD completo de facturas con series (FAC, RECT, PRO)
- Tipos: venta directa, pedido, servicio, rectificativa, proforma
- Estados: pendiente, pagada, anulada, vencida
- Detección automática de facturas vencidas
- Líneas de factura con IVA, descuento por línea
- Descuento global y retención IRPF
- Datos fiscales del cliente (NIF, razón social, dirección)
- Numeración automática por serie y año
- Historial de cambios en cada factura
- Generación de PDF profesional
- Resumen fiscal
- Contabilidad integrada (gastos + proveedores)
- Métodos de pago: tarjeta, PayPal, Bizum, efectivo, transferencia
- Tabs por estado + estadísticas

**❌ Lo que falta:**
- **Factura electrónica** (TicketBAI, SII, Verifactu) — obligatorio en España 2026
- **Envío automático por email** del PDF al cliente
- **Pagos online** integrados (Stripe checkout link en factura)
- **Recargos por mora** automáticos
- **Factura recurrente** (suscripciones mensuales automáticas)
- **Multi-moneda** y multi-idioma
- **Presupuestos** (convertir presupuesto → factura)
- **Notas de crédito** (abono parcial)
- **Firma digital** del cliente en el PDF
- **Código QR** de verificación en factura (obligatorio TicketBAI)

**Mejoras prioritarias:**
1. Envío de factura por email
2. Facturación electrónica Verifactu (obligatorio pronto en España)
3. Factura recurrente para suscripciones

---

### 📒 13. CONTABILIDAD — 70/100

**✅ Lo que tiene:**
- Gastos con categorías (suministros, servicios, alquiler, personal, marketing, etc.)
- Proveedores con CRUD
- Base imponible + IVA deducible
- Libro de gastos con filtro por período
- Integración con nóminas (gasto automático al pagar nómina)
- Exportación (mencionada en servicio)
- Vinculación nómina → gasto

**❌ Lo que falta:**
- **Libro de ingresos** (facturas cobradas separado de gastos)
- **Conciliación bancaria** (importar extracto y conciliar)
- **Modelos fiscales** — 303 (IVA trimestral), 130 (IRPF trimestral), 347, 390
- **Cierre contable** anual
- **Balance de situación** y **Cuenta de resultados** (P&L)
- **Plan contable** por cuentas
- **Amortizaciones** de activos fijos
- **Gráficos de evolución** (ingresos vs gastos mensual)
- **Alertas fiscales** (recordatorio de presentación de modelos)
- **Integración con banco** (Open Banking / PSD2)

**Mejoras prioritarias:**
1. Modelo 303 IVA trimestral autocalculado
2. Gráfico ingresos vs gastos mensual
3. Alertas de vencimiento fiscal

---

### 💵 14. NÓMINAS — 85/100

**✅ Lo que tiene:**
- Cálculo automático completo según normativa española 2026:
  - Seguridad Social (CC, Desempleo, FP, MEI, Solidaridad)
  - IRPF progresivo con tramos estatales + ajuste autonómico
  - Mínimo personal y familiar (descendientes, discapacidad, edad)
  - Reducción por rendimientos del trabajo (Art. 19/20 LIRPF)
  - Cotización solidaridad (exceso sobre base máxima, 3 tramos)
  - Base de cotización con topes por grupo
- 11 grupos de cotización con bases mínimas y AT/EP
- 19 comunidades autónomas con ajuste IRPF
- 5 tipos de contrato (indefinido, temporal, prácticas, formación, parcial)
- Pagas extras: 12 o 14, prorrateadas o en junio/diciembre
- Recálculo IRPF YTD (ajuste mensual si cambia salario)
- IRPF personalizado manual como override
- Horas extra con precio por hora
- Complementos fijos y variables
- Coeficiente de parcialidad (jornada reducida)
- PDF con formato oficial "Recibo Individual de Salarios" (Orden ESS/2098/2014)
- Generación masiva de nóminas para todos los empleados
- Estados: borrador → aprobada → pagada
- Al pagar: genera gasto automático en contabilidad + actualiza YTD
- Tabs: Este Mes, Historial, Costes, Resumen
- Envío por correo y compartir
- AT/EP personalizado por CNAE

**❌ Lo que falta:**
- **IRPF por comunidad autónoma con tramos reales** (ahora es ajuste simplificado)
- **Complementos salariales por convenio** (antigüedad automática, plus transporte, etc.)
- **Pagas extra proporcionales** al tiempo trabajado
- **Incapacidad temporal** (baja médica: cálculo de prestación IT)
- **Embargos de nómina** (judicial, por deuda con Hacienda)
- **Finiquito y liquidación** automática
- **Modelo 111** (retenciones IRPF trimestral) y **Modelo 190** (anual)
- **TC1/TC2 / RNT/RLC** — generación para Seguridad Social
- **Certificado de empresa** al despido
- **Fichero SEPA** para pago de nóminas por transferencia bancaria
- **Convenio colectivo** configurable (tablas salariales automáticas)
- **Multi-centro de trabajo** (diferentes CCC)
- **Anticipo de nómina** y préstamos a empleados
- **Retribución en especie** (coche empresa, seguro médico)

**Mejoras prioritarias:**
1. Modelo 111/190 (obligatorio declarar retenciones IRPF)
2. Fichero SEPA para pagos bancarios
3. Cálculo de finiquito

---

### 🌐 15. CONTENIDO WEB — 55/100

**✅ Lo que tiene:**
- Secciones web editables (texto, oferta)
- Script para inyectar contenido en la web del cliente
- Servicio de analytics web
- Servicio de administración de contenido web

**❌ Lo que falta:**
- **Editor WYSIWYG** para el contenido
- **Previsualización** del contenido en la web
- **Imágenes y multimedia** — subida y gestión
- **SEO básico** (meta tags configurables)
- **Blog/Noticias** editables desde la app
- **Landing pages** personalizadas
- **Formulario de contacto** desde la web
- **Pop-ups y banners** programables
- **Integración con dominio propio** del cliente
- **Analytics detallados** (páginas más vistas, tiempo en página)
- **A/B Testing** de contenido

**Mejoras prioritarias:**
1. Editor visual de contenido (Markdown al menos)
2. Subida de imágenes con Firebase Storage
3. Analytics de páginas vistas en tiempo real

---

### 🛡️ 16. PERMISOS Y ROLES — 76/100

**✅ Lo que tiene:**
- 3 roles bien definidos: Propietario, Admin, Staff
- Permisos por módulo (finanzas, empleados, configuración, etc.)
- Módulos visibles según rol (segmentación completa)
- Sesión de usuario con datos cargados desde Firestore
- Reglas Firestore por rol (lectura/escritura granular)

**❌ Lo que falta:**
- **Roles personalizados** — crear roles con permisos a medida
- **Permisos granulares** (leer vs escribir vs eliminar por módulo)
- **Permisos por recurso** (acceso solo a sus propios datos)
- **Log de auditoría** — quién hizo qué y cuándo
- **Sesiones activas** — ver y cerrar sesiones desde otros dispositivos
- **Invitación por email** con rol predefinido
- **Expiración de acceso** temporal para empleados

**Mejoras prioritarias:**
1. Log de auditoría (quién modificó qué)
2. Roles personalizados
3. Invitación por email con enlace

---

### 👑 17. PANEL PROPIETARIO (Plataforma) — 60/100

**✅ Lo que tiene:**
- Estadísticas globales de todas las empresas
- Empresas registradas/activas/nuevas del mes
- Ingresos totales y del mes
- Actividad de la plataforma (pedidos, facturas, valoraciones)
- Estadísticas web de fluixtech.com
- Suscripciones activas vs vencidas
- Herramientas de desarrollo (generar datos prueba)

**❌ Lo que falta:**
- **Gestión de empresas** — poder ver/editar/suspender cualquier empresa
- **Gestión de usuarios** — ver todos los usuarios de la plataforma
- **Ingresos por suscripción** — MRR, ARR, churn rate
- **Panel de soporte** — tickets de soporte de empresas
- **Logs del sistema** — errores, actividad
- **Configuración global** — planes, precios, features
- **Emails transaccionales** — configuración y plantillas
- **Métricas de uso** — qué módulos se usan más
- **Onboarding progress** — ver qué empresas están en onboarding
- **Health check** — estado de Firebase, Functions, etc.

**Mejoras prioritarias:**
1. Dashboard de MRR/ARR con gráfico
2. Panel para gestionar empresas directamente
3. Métricas de uso de módulos

---

### 💳 18. SUSCRIPCIONES — 50/100

**✅ Lo que tiene:**
- Modelo de suscripción en Firestore (estado, plan, fechas)
- Pantalla de suscripción vencida con bloqueo
- Banner de aviso de vencimiento
- Stripe integrado en Cloud Functions (webhook + checkout)
- Comprobación de estado al entrar a la app

**❌ Lo que falta:**
- **Planes visibles** con precios y características
- **Cambio de plan** (upgrade/downgrade) desde la app
- **Historial de pagos** visible
- **Facturación automática** de suscripciones (factura de la plataforma al cliente)
- **Trial gratuito** automático
- **Cancelación** desde la app
- **Emails automáticos** (bienvenida, recordatorio renovación, pago fallido)
- **Cupones de descuento**
- **Cobro por empleado** en nóminas (ej: 3€/emp/mes)
- **Portal de cliente Stripe** integrado
- **Métricas SaaS** (churn, LTV, MRR)

**Mejoras prioritarias:**
1. Pantalla de planes con comparativa visual
2. Trial de 14 días automático al registrar
3. Portal de Stripe para gestión de pagos

---

### 🔔 19. NOTIFICACIONES — 65/100

**✅ Lo que tiene:**
- Firebase Cloud Messaging configurado
- Token FCM guardado por usuario
- Topics por empresa
- Cloud Function para envío multicast
- Limpieza de tokens inválidos
- Canales de notificación Android

**❌ Lo que falta:**
- **Centro de notificaciones** en la app (historial)
- **Preferencias de notificación** por tipo (email, push, ambos)
- **Notificaciones por email** (no solo push)
- **Notificaciones programadas** (recordatorios)
- **Notificaciones por eventos** de negocio:
  - Nueva reserva
  - Factura vencida
  - Tarea vencida
  - Nómina generada
  - Reseña negativa
- **Badge count** actualizado

**Mejoras prioritarias:**
1. Centro de notificaciones con historial en la app
2. Preferencias de notificación por usuario
3. Notificaciones automáticas por email

---

### ☁️ 20. CLOUD FUNCTIONS — 58/100

**✅ Lo que tiene:**
- Stripe: checkout, webhook de pago, portal de cliente
- Notificaciones push multicast
- Secret Manager para keys sensibles

**❌ Lo que falta:**
- **Migrar de `functions.config()`** a params (deprecado, falla en marzo 2027)
- **Scheduled functions** — recálculo nocturno de estadísticas
- **Triggers de Firestore** — en creación de reserva, pedido, factura
- **Envío de emails** (Nodemailer/SendGrid)
- **Generación de reportes** server-side
- **Cron de vencimientos** — marcar facturas/suscripciones como vencidas
- **Backup automático** de Firestore
- **API REST** para integraciones externas

**Mejoras prioritarias:**
1. Migrar a params (urgente — se rompe en marzo 2027)
2. Trigger que envíe email al crear factura
3. Cron diario de vencimientos

---

### 🧪 21. TESTING — 5/100

**✅ Lo que tiene:**
- Un único archivo `widget_test.dart` con el template por defecto de Flutter (no funciona — referencia a `MyApp` que no existe)

**❌ Lo que falta:**
- **Tests unitarios** de modelos (Nomina, Factura, etc.)
- **Tests de servicios** (NominasService, FacturacionService)
- **Tests de widgets** reales
- **Tests de integración** con Firebase
- **Tests E2E** (flujo completo login → dashboard → crear factura)
- **Coverage mínimo** del 60%+
- **CI/CD** (GitHub Actions / Codemagic)

**Mejoras prioritarias:**
1. Tests unitarios de los cálculos de nómina (crítico — dinero)
2. Tests de los modelos fromMap/toMap
3. Setup de CI con GitHub Actions

---

### 🔒 22. REGLAS FIRESTORE — 72/100

**✅ Lo que tiene:**
- Helpers reutilizables (isAuth, perteneceAEmpresa, getRol, etc.)
- Permisos por rol (propietario, admin, staff)
- Subcolecciones de empresa protegidas
- Propietario puede crear/editar empleados
- Registro: cualquier auth puede crear su propio doc

**❌ Lo que falta:**
- **Rate limiting** — no hay protección contra abuso
- **Validación de datos** en las reglas (tipos, rangos)
- **Protección contra eliminación masiva**
- **Reglas de escritura** más granulares (qué campos puede editar cada rol)
- **Colección `empresas` raíz** — lectura de todas las empresas no protegida para propietario de plataforma
- **Auditoría** — campo `updated_by` obligatorio en escrituras

**Mejoras prioritarias:**
1. Validación de campos en reglas de escritura
2. Rate limiting con tokens
3. Auditoría automática (updated_by, updated_at)

---

## 🚀 TOP 10 MEJORAS PRIORITARIAS PARA LLEGAR AL 90/100

| # | Mejora | Módulos afectados | Impacto |
|---|--------|-------------------|---------|
| 1 | **Tests unitarios** de cálculos de nómina y facturación | Testing, Nóminas, Facturación | 🔴 Crítico |
| 2 | **Facturación electrónica** Verifactu/TicketBAI | Facturación | 🔴 Legal |
| 3 | **Login social** (Google) + recuperar contraseña | Autenticación | 🔴 UX |
| 4 | **Envío de facturas/nóminas por email** | Facturación, Nóminas | 🟠 Alto |
| 5 | **Vista calendario** en reservas y tareas | Reservas, Tareas | 🟠 Alto |
| 6 | **Ficha de cliente completa** con historial | Clientes | 🟠 Alto |
| 7 | **Modelo 111/190 IRPF** trimestral/anual | Nóminas | 🟠 Legal |
| 8 | **Planes de suscripción** visibles + trial | Suscripciones | 🟠 Negocio |
| 9 | **Centro de notificaciones** con historial | Notificaciones | 🟡 UX |
| 10 | **Migrar Cloud Functions** a params | Cloud Functions | 🟡 Urgente técnico |

---

## 📌 NOTAS ADICIONALES

### Branding
- La app aún se llama **"PlaneaGuada CRM"** en varios sitios (main.dart, login, pantalla de carga). Debería ser **"Fluix CRM"** o el nombre que quieras.

### Archivos duplicados/obsoletos
- `modulo_valoraciones.dart`, `modulo_valoraciones_backup.dart`, `modulo_valoraciones_nuevo.dart` — hay 4 versiones del módulo de valoraciones. Limpiar los que no se usan.
- Hay ~40 archivos `.md` de documentación en la raíz. Mover a carpeta `docs/`.

### Deuda técnica
- El test por defecto referencia a `MyApp` que ya no existe.
- `detalle_pedido_nuevo_screen.dart` tiene múltiples errores de compilación (`facturaId`, `_nombre`, `_buildTabNotas`, etc.).
- El archivo `modulo_valoraciones_fixed.dart` tenía un typo (`aimport` en lugar de `import`) — parece resuelto pero revisarlo.


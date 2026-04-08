# 📊 Estado Actual del Proyecto - Abril 2026

**Fecha:** 08/04/2026  
**Versión:** 0.8.0 (Alpha)  
**Completitud:** ~60-65%

---

## ✅ Implementado y Funcional

### Autenticación
- ✅ Login/Signup con Firebase Auth
- ✅ Persistencia de sesión
- ✅ Redireccionamiento automático al dashboard
- ✅ Credenciales de prueba disponibles en login

### Multiempresa
- ✅ Soporte completo para múltiples empresas
- ✅ Switcheo entre empresas
- ✅ Datos aislados por `empresaId`
- ✅ Configuración independiente por empresa

### Dashboard Principal
- ✅ Widget de proximos 3 días (reservas, pedidos, tareas)
- ✅ Resumen de hoy (eventos y reservas)
- ✅ Selección de módulos para mostrar/ocultar
- ✅ Estadísticas en tiempo real (visitantes, reservas, valoraciones)
- ✅ Sincronización automática con cambios

### Módulos Implementados

#### 📋 Reservas
- ✅ CRUD completo de reservas
- ✅ Estados: PENDIENTE, CONFIRMADA, CANCELADA, COMPLETADA
- ✅ Vinculación con clientes y servicios
- ✅ Integración con Google Calendar
- ✅ Notificaciones push (pendientes de pruebas)

#### 🛍️ Pedidos
- ✅ CRUD de pedidos
- ✅ Catálogo de productos (categorías, precio, stock)
- ✅ Carrito de compras
- ✅ Métodos de pago: tarjeta, PayPal, Bizum, efectivo
- ✅ Origen: web, app, WhatsApp
- ⚠️ Falta: mostrar productos en tabla de selección

#### 📞 WhatsApp (pedidos_whatsapp)
- ✅ Recepción de pedidos vía WhatsApp
- ✅ Registro automático en Firestore
- ✅ Confirmación automática al cliente
- ✅ Estado del pedido trackeable

#### 💰 Facturación
- ✅ Generación de facturas desde pedidos
- ✅ Facturas rectificativas
- ✅ Historial de cambios
- ✅ Estados: PENDIENTE, PAGADA, ANULADA
- ✅ Exportación a PDF
- ⚠️ Falta: más estadísticas de productos vendidos

#### 👥 Clientes
- ✅ CRUD con filtros
- ✅ Datos fiscales (NIF/CIF)
- ✅ Historial de transacciones
- ✅ Etiquetas y notas
- ✅ Búsqueda en tiempo real

#### 👨‍💼 Empleados
- ✅ CRUD con roles (PROPIETARIO, ADMIN, STAFF)
- ✅ Gestión de permisos
- ✅ Integración con nóminas
- ✅ Estado activo/inactivo

#### ⭐ Valoraciones/Reviews
- ✅ Importación de Google Reviews
- ✅ Cache de últimas 50 reseñas
- ✅ Estadísticas (promedio, recuento por calificación)
- ⚠️ Falta: responder desde app y reflejar en Google

#### 📈 Estadísticas
- ✅ Dashboard de estadísticas
- ✅ Gráficas de ingresos (diarios, mensuales, anuales)
- ✅ Clientes nuevos por período
- ✅ Tasa de conversión
- ⚠️ Datos: mezcla de reales + simulados (necesita revisión)

#### 📝 Tareas
- ✅ CRUD de tareas (kanban + lista + calendario)
- ✅ Estados: TODO, EN PROGRESO, HECHO
- ✅ Prioridades y etiquetas
- ✅ Vistas múltiples
- ✅ Integración con calendario

#### 🎨 Contenido Web (Secciones)
- ✅ CRUD de secciones dinámicas
- ✅ Campos: título, texto, imagen
- ✅ Sincronización con web en tiempo real
- ✅ Activar/desactivar módulo
- ⚠️ UI: botones padding excesivo, necesita rediseño

#### 📱 Configuración General
- ✅ Activar/desactivar módulos por empresa
- ✅ Configuración de dispositivos
- ✅ Token de notificaciones push
- ✅ Suscripción y vencimiento

---

## ⚠️ Parcialmente Implementado / Con Errores

### 1. **Módulo de Facturación**
- ✅ Generación de facturas
- ❌ **Error:** Syntax en `modulo_facturacion_screen.dart` (líneas de código malformadas)
- ⚠️ Falta: Exportación a .xml para AEAT
- ⚠️ Falta: Integración con Certificado Electrónico

### 2. **Modelos de Declaración (AEAT)**
- ✅ Estructura para 303, 111, 115, 130, 190, 349
- ⚠️ Falta: Exportadores completamente funcionales
- ⚠️ Falta: Pruebas end-to-end

### 3. **Sincronización WordPress**
- ✅ Envía datos a Firebase
- ❌ **Errores HTTP 404:** Intenta hacer GET a endpoints de WordPress que no existen
- ⚠️ Necesita: Actualizar URLs y endpoints

### 4. **Google Reviews**
- ✅ Configuración inicial
- ✅ Importación de reseñas
- ❌ **Error:** Campo `estrellas` no existe en algunos documentos
- ⚠️ Falta: Responder desde app y reflejar en Google

---

## ❌ No Implementado / TODO

### Nóminas (Crítico para release)
- ❌ CRUD completo
- ❌ Cálculos con SS 2026
- ❌ IRPF CLM
- ❌ Convenios colectivos
- ❌ Exportación SEPA XML
- ❌ **Estimado:** 2-3 semanas de desarrollo

### Suscripción y Facturación Comercial
- ⚠️ Estructura creada
- ❌ Integración con Stripe
- ❌ Cálculo de días restantes
- ❌ Bloqueo si vencida
- ❌ Notificaciones de vencimiento
- ❌ **Estimado:** 1 semana

### Notificaciones Push
- ⚠️ Estructura creada
- ❌ Cloud Functions sin probar
- ❌ Llamadas desde app sin confirmar
- ❌ **Estimado:** 3-4 días

### Web (Flutter Web)
- ❌ Responsive completo
- ❌ PWA setup
- ❌ Deployment en Firebase Hosting
- ❌ **Estimado:** 1 semana

### iOS
- ❌ Certificados
- ❌ Provisioning profiles
- ❌ Build release
- ❌ TestFlight
- ❌ **Estimado:** 2-3 días

### Tests
- ⚠️ Estructura de directorios creada
- ❌ Unit tests implementados
- ❌ Widget tests
- ❌ Integration tests

---

## 🐛 Errores Críticos a Resolver

| Archivo | Línea | Error | Severidad |
|---------|-------|-------|-----------|
| `modulo_facturacion_screen.dart` | ~290 | Sintaxis inválida (paréntesis no cerrado) | 🔴 CRÍTICA |
| `widget_proximos_dias.dart` | ~928+ | Variable `dia` no definida | 🔴 CRÍTICA |
| `modulo_reservas.dart` | ~203 | Método `_TarjetaReserva` no existe | 🔴 CRÍTICA |
| `modulo_valoraciones_fixed.dart` | - | Campo `estrellas` missing | 🟡 ALTA |
| `firebase.json` | - | Project no activo para deploy | 🟡 ALTA |
| `google-services.json` | - | Package name mismatch | 🟡 ALTA |

---

## 📈 Estimado de Completitud por Módulo

| Módulo | % | Estado |
|--------|---|--------|
| **Reservas** | 95% | ✅ Casi completo |
| **Pedidos** | 85% | 🟡 Falta UI |
| **Facturación** | 80% | 🟡 Errores de syntax |
| **Clientes** | 90% | ✅ Casi completo |
| **Empleados** | 85% | ✅ Casi completo |
| **Tareas** | 95% | ✅ Casi completo |
| **Valoraciones** | 75% | 🟡 Falta integracion Google |
| **Estadísticas** | 70% | 🟡 Datos simulados |
| **Contenido Web** | 80% | 🟡 UI mejorables |
| **Nóminas** | 20% | 🔴 Prácticamente no hecho |
| **Suscripción** | 30% | 🔴 Estructura only |
| **Push Notifications** | 40% | 🟡 Functions sin probar |

---

## 🎯 Prioridades Inmediatas (Próximos 3 días)

1. **🔴 Corregir errores de syntax en módulos** (2 horas)
2. **🟡 Resolver permission-denied de Firestore** (1-2 horas)
3. **🟡 Actualizar reglas de Firestore** (1 hora)
4. **🟡 Mostrar productos en pedidos** (2 horas)
5. **🟡 Fix Google Reviews parsing** (1 hora)

## 📅 Roadmap a Release (1.0)

- **Semana 1:** Corregir errores críticos + tests
- **Semana 2:** Nóminas MVP
- **Semana 3:** Suscripción + Stripe
- **Semana 4:** Polish, tests, compliance AEAT
- **Semana 5:** Beta testing interno
- **Semana 6:** App Store / Play Store release

---

**Última actualización:** 08/04/2026  
**Próxima revisión:** 10/04/2026


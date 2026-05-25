# FLUIX CRM — Contexto completo para Landing Web

> Generado automáticamente a partir del código fuente del proyecto `planeag_flutter` v1.0.15.
> Solo contiene información extraída del código — sin inventar ni suponer.

---

## 1. IDENTIDAD Y MARCA

| Campo | Valor |
|-------|-------|
| **Nombre del Producto** | Fluix CRM |
| **Empresa Propietaria** | FluxTech |
| **Dominio** | fluixtech.com |
| **Versión actual** | 1.0.15 |
| **Nombre interno del proyecto** | planeag_flutter |
| **Descripción en pubspec** | PlaneaGuada CRM para pymes |

### Colores del Sistema de Diseño

| Rol | Hex | Uso |
|-----|-----|-----|
| Primario | `#1976D2` | Botones, selección activa, NavRail |
| Primario oscuro | `#0D47A1` | Header bienvenida, gradientes |
| Primario claro | `#42A5F5` | Gradientes secundarios |
| Secundario | `#FFC107` | Badges, acentos |
| Éxito | `#4CAF50` | Estado "completado", online |
| Online badge | `#69F0AE` | Indicador "Online" |
| Error | `#F44336` | Errores, cancelaciones |
| Advertencia | `#FF9800` | Avisos, vencimientos |
| Info | `#2196F3` | Tooltips, banners informativos |

#### Colores del TPV Peluquería (tema oscuro especializado)

| Nombre | Hex |
|--------|-----|
| Cian neon | `#00FFC8` |
| Magenta | `#FF3296` |
| Rosa | `#FF4678` |
| Fondo oscuro | `#0A0F23` |
| Superficie | `#151932` |
| Tarjeta | `#1E2139` |
| Divisor | `#2A2E45` |
| Púrpura | `#9C27B0` |

### Tipografía y Estilo
- Sistema base: **Material Design 3** (`useMaterial3: true`)
- Dependencia: **Google Fonts** (`google_fonts: ^6.2.1`)
- Idiomas soportados: Español (es_ES) e Inglés (en_US)

---

## 2. PLANES Y PRECIOS

> Fuente: `lib/core/config/planes_config.dart`

### Plan Base — siempre incluido
- **Precio:** €310 / año
- **Módulos incluidos:** Dashboard, Reservas, Clientes, Servicios, Empleados, Valoraciones, Estadísticas, Contenido Web
- **Color identificativo:** `#1976D2` (azul)

### Packs acumulables sobre el Plan Base

| Pack | Precio/año | Módulos que añade | Color |
|------|-----------|-------------------|-------|
| **Pack Gestión** | €370 | Facturación, Vacaciones, TPV, Fichaje | `#7B1FA2` (púrpura) |
| **Pack Fiscal AI** | €430 | Modelos AEAT automáticos, Contabilidad, Verifactu | `#0288D1` (azul oscuro) |
| **Pack Tienda Online** | €490 | Pedidos y ecommerce | `#E65100` (naranja) |

### Bundles con descuento

| Bundle | Packs incluidos | Precio sin bundle | Precio bundle | Ahorro |
|--------|----------------|-------------------|---------------|--------|
| Gestión + Fiscal AI | Pack Gestión + Pack Fiscal AI | €800 | €700 | €100 |

### Add-ons independientes

| Add-on | Precio/año | Módulo |
|--------|-----------|--------|
| **WhatsApp** | €50 | Gestión de pedidos y bot por WhatsApp |
| **Nóminas** | €310 | Cálculo automático de nóminas, IRPF, SS |
| **Comandas Bar** | Por definir | TPV de comandas de mesa |
| **Tareas** | Por definir | Gestión de tareas y productividad |

### Fórmula de precio total
```
Total = Plan Base (€310)
      + Packs activos
      + Add-ons activos
      - Descuentos de bundle
```

---

## 3. MÓDULOS Y FUNCIONALIDADES

### 3.1 Dashboard
- Hub central configurable con widgets personalizables
- Vista dual: perspectiva empresa vs. perspectiva usuario
- Módulo propietario (FluxTech): estadísticas globales de la plataforma
- Configuración de qué widgets aparecen y en qué orden
- Tipos de widget: estadísticas, próximos días, valoraciones, etc.

### 3.2 Reservas / Agenda
- Calendario de citas con gestión de disponibilidad
- Estados: pendiente, confirmada, cancelada, completada
- Campos: cliente, servicio, empleado, mesa, origen (web/manual/teléfono), ubicación (salón/terraza)
- Alergenos y observaciones
- Formulario web personalizable (por negocio)
- Recordatorios automáticos por email/push
- Reservas recurrentes con configuración de intervalos

### 3.3 Clientes (CRM)
- Ficha completa: nombre, teléfono, email, NIF, dirección
- Historial de actividad y visitas
- Etiquetas libres y notas
- Detección automática de duplicados
- Importación masiva por CSV
- Clientes silenciosos (sin actividad reciente)
- Soporte a clientes intracomunitarios (NIF IVA comunitario)
- Estados: contacto, activo, inactivo

### 3.4 TPV — Terminal Punto de Venta

#### TPV Peluquería / Salón
- Agenda visual con timeline horizontal por profesional
- Color-coding automático por empleado
- Avatar/foto del profesional
- Duración variable de servicios
- Horarios de entrada/salida por empleado
- Servicios especializados por profesional
- Impresión de tickets (impresora térmica Bluetooth)
- Tema oscuro neon (diferenciado del resto de la app)

#### TPV Bar / Restaurante
- Gestión de mesas
- Comandas por mesa (o caja rápida sin mesa)
- Estado de comanda: abierta / cobrada
- Descuentos por mesa (importe o porcentaje)
- Nota general por comanda
- Cierre de caja
- Impresora Bluetooth integrada

#### TPV Tienda
- Carrito de compras
- Escáner de código de barras
- Variantes de producto (talla, color, sabor)
- Gestión de stock en tiempo real

### 3.5 Facturación
- Series de facturas: ordinaria (fac), rectificativa (rect), proforma (pro), TPV (tpv)
- Estados: pendiente, pagada, anulada, vencida, rectificada
- Métodos de pago: tarjeta, PayPal, Bizum, efectivo, transferencia, mixto
- Generación automática de PDF
- Libro de facturas emitidas y recibidas
- Contabilidad con asientos automáticos
- Exportación para gestorías

### 3.6 Fiscal AI (España)
- Modelos AEAT generados automáticamente:
  - **Modelo 111** — Retenciones e ingresos a cuenta
  - **Modelo 115** — IVA soportado / renta
  - **Modelo 130** — Estimación directa IRPF
  - **Modelo 180** — Pagos a cuentas corrientes
  - **Modelo 190** — Resumen anual retenciones
  - **Modelo 202** — IVA simplificado
  - **Modelo 303** — IVA trimestral
  - **Modelo 347** — Declaración anual de terceros
  - **Modelo 349** — IVA intracomunitario
  - **Modelo 390** — Resumen anual IVA
- **Verifactu (RD 1007/2023):** Presentación telemática con hash chain y QR en facturas
- **Escaneo OCR de facturas:** Captura automática de datos desde PDF/imagen con IA
- Exportación directa a Sede Electrónica AEAT
- Certificado digital cualificado (firma XAdES, PKCS12)
- Periodicidad configurable: mensual o trimestral

### 3.7 Nóminas
- Cálculo automático: salario bruto, IRPF, SS trabajador, SS empresa, neto
- Tramos IRPF por comunidad autónoma (valores 2026)
- Tipos de contrato: indefinido, temporal, prácticas, formación, parcial
- Complementos y deducciones personalizables
- Horas extra: estructurales, fuerza mayor, no estructurales
- Gestión de ausencias: vacaciones, bajas, permisos
- Regularización anual IRPF
- Exportación remesa SEPA para pago bancario
- Finiquitos: liquidación automática de trabajadores
  - Días no disfrutados, indemnización, pendiente de pago

### 3.8 Fichajes / Control Horario
- Entrada, salida, pausa inicio, pausa fin
- Localización GPS en cada fichaje
- Firma biométrica (huella dactilar)
- Edición por administrador con auditoría
- Reportes de horas por empleado y período

### 3.9 Empleados
- Ficha de empleado con rol y permisos modulares
- Configuración de qué módulos ve cada empleado
- Baja laboral
- Invitación por deep link: `fluixcrm://invite?token=...`

### 3.10 Servicios
- Catálogo con nombre, descripción, precio, duración (15–480 min), categoría
- Imágenes
- Asignación a empleados específicos

### 3.11 Tienda Online y Pedidos
- Catálogo de productos: nombre, descripción, precio, stock, SKU, código de barras
- Variantes de producto (talla, color, sabor con precio diferencial)
- Imágenes con miniaturización automática (Cloud Function)
- Integración Stripe Connect para cobros online
- Pedidos desde web, app, WhatsApp o presencial
- Estados: pendiente, confirmado, en preparación, listo, entregado, cancelado
- Seguimiento de envíos

### 3.12 WhatsApp Bot
- Recepción y gestión de pedidos por WhatsApp
- Confirmaciones automáticas
- Configuración del mensaje de bienvenida del bot
- Envío de notificaciones de estado de pedido

### 3.13 Fidelización
- Programa de puntos / sellos
- Escaneo QR para canje de recompensas
- QR de negocio para identificación del cliente

### 3.14 Flash Slots
- Ofertas de disponibilidad limitada
- Creación y gestión de slots flash
- Visibilidad en el marketplace de negocios

### 3.15 Valoraciones
- Reseñas internas (Fluix) y externas (Google)
- Sincronización con Google My Business
- Respuesta a reseñas desde la app
- Rating agregado con resumen visual

### 3.16 Tareas
- Gestión de tareas con estado, prioridad y fecha de vencimiento
- Asignación a empleados y equipos
- Cronometraje: tiempo estimado vs. real
- Tareas recurrentes con configuración de recurrencia
- Etiquetas y equipos

### 3.17 Vacaciones y Permisos
- Solicitud y aprobación de vacaciones
- Festivos locales configurables
- Calendario de ausencias del equipo

### 3.18 Perfil de Negocio Público
- Categorías: restaurantes, peluquerías, estéticas, tatuajes, clínicas, gimnasios, hoteles, tiendas, carnicerías, fruterías
- Formulario de reserva personalizable por tipo de negocio
- Integración Google My Business
- Gestión de reseñas Google desde la app

### 3.19 Explorar Negocios (Marketplace)
- Directorio de negocios para clientes finales
- Búsqueda por categoría y ubicación
- Reserva directa desde perfil público

### 3.20 Contenido Web
- Gestión de blog: crear, editar y publicar posts desde la app
- Analytics web: tráfico del sitio
- SEO: auditoría básica, palabras clave
- Gestión de reseñas Google (respuestas)
- Integración de scripts/pixel en web externa

---

## 4. SECTORES OBJETIVO

| Sector | TPV especializado | Características clave |
|--------|------------------|----------------------|
| **Peluquería / Barbería / Salón de belleza** | TPV Peluquería | Agenda por profesional, timeline visual, duración variable, tema oscuro |
| **Restaurante / Bar / Cafetería** | TPV Bar | Mesas, comandas, cierre de caja, impresora térmica |
| **Tienda / Comercio** | TPV Tienda | Inventario, variantes, códigos de barras, ecommerce |
| **Clínica / Consultorio** | Reservas | Citas por especialista, recordatorios |
| **Gimnasio / Centro deportivo** | Reservas + Clientes | Membresías, historial |
| **Hotel / Alojamiento** | Reservas | Disponibilidad |
| **Cualquier negocio con citas** | Reservas | CRM, servicios, estadísticas |

---

## 5. MODELOS DE DATOS PRINCIPALES

### Negocio / Empresa
`nombre`, `correo`, `teléfono`, `dirección`, `ciudad`, `CP`, `provincia`, `país` (ES por defecto), `descripción`, `logo_url`, `web`, `fecha_creación`
Configuración fiscal: tipo, periodicidad IVA, obligado SII, Verifactu, CNAE

### Usuario
`id`, `nombre`, `correo`, `teléfono`, `empresa_id`, `rol` (propietario | admin | staff), `activo`, `permisos[]`, `token_dispositivo`

### Cliente
`id`, `nombre`, `teléfono`, `correo`, `NIF`, `dirección`, `total_gastado`, `última_visita`, `nº_reservas`, `etiquetas[]`, `notas`, `estado` (contacto | activo | inactivo)

### Reserva
`id`, `fecha_hora`, `cliente`, `servicio`, `empleado`, `mesa`, `estado` (pendiente | confirmada | cancelada | completada), `origen` (web | manual | teléfono), `alergenos`, `observaciones`

### Factura
`número`, `serie`, `fecha`, `cliente`, `líneas[]`, `base_imponible`, `IVA`, `total`, `estado`, `método_pago`, `tipo` (pedido | venta | servicio | rectificativa | proforma)

### Comanda (TPV Bar)
`mesa_id`, `camarero`, `líneas[]`, `estado` (abierta | cobrada), `importe_total`, `descuento`, `nota`

### Producto (Tienda)
`nombre`, `descripción`, `categoría`, `precio`, `stock`, `variantes[]`, `SKU`, `código_barras`, `stripe_product_id`

### Nómina
`empleado_id`, `mes`, `año`, `salario_bruto`, `IRPF`, `SS_trabajador`, `SS_empresa`, `complementos[]`, `deducciones[]`, `neto`, `estado` (borrador | aprobada | pagada)

### Fichaje
`empleado_id`, `tipo` (entrada | salida | pausa_inicio | pausa_fin), `timestamp`, `latitud`, `longitud`, `firma_tipo`

---

## 6. ARQUITECTURA TÉCNICA

### Stack
| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3.x, Dart 3.11.1+, Material Design 3 |
| State Management | Provider 6.1.2 |
| Backend | Firebase (Firestore, Auth, Functions, Storage, Analytics, Crashlytics) |
| Base de datos local | SQLite (sqflite), Firestore cache offline |
| Pagos | Stripe Connect |
| Notificaciones | Firebase Cloud Messaging (FCM) 15.1.3 |
| PDF | pdf 3.11.1 + printing 5.14.1 |
| Gráficas | FL Chart 0.69.0 |
| Criptografía | PointyCastle 3.7.3 (RSA-SHA256), ASN1Lib 1.6.0 |
| Escáner | mobile_scanner 6.0.0 |
| Biometría | local_auth 2.3.0, Sign in with Apple 6.1.4 |
| Impresora | blue_thermal_printer 1.0.9 (Bluetooth) |
| GPS | geolocator 13.0.1 |
| QR | qr_flutter 4.1.0 |

### Autenticación
- Email/contraseña
- Google Sign-In
- Apple Sign-In
- Biometría (Face ID, huella)
- 2FA (token + SMS/email)
- Deep links para invitaciones: `fluixcrm://invite?token=...`
- Almacenamiento seguro: `flutter_secure_storage`

### Plataformas soportadas
- Android
- iOS
- Windows (desktop)
- Web (Chrome, Edge)

### Patrón de arquitectura
- Clean Architecture (Domain / Data / Presentation)
- Repository Pattern
- Use Cases separados
- Provider como ChangeNotifier para estado global
- Offline-first: Firestore cache + SQLite local

### Auditoría y compliance
- Log de auditoría por operación (quién, qué, cuándo)
- Pantalla de auditoría histórica por empresa
- Tracking de versión de app y dispositivo

---

## 7. INTEGRACIONES EXTERNAS

| Integración | Uso |
|-------------|-----|
| **Firebase** | Auth, Firestore, Storage, Functions, Analytics, Crashlytics, FCM |
| **Stripe Connect** | Pagos online, ecommerce, suscripciones |
| **Google My Business** | Perfil público, sincronización de reseñas |
| **Google Sign-In** | Autenticación |
| **WhatsApp Bot** | Pedidos por chat, confirmaciones automáticas |
| **AEAT Sede Electrónica** | Presentación de modelos fiscales |
| **Google Fonts** | Tipografías |
| **Impresora Bluetooth** | Tickets TPV (bar, peluquería, tienda) |

---

## 8. PROPUESTA DE VALOR (INFERIDA DEL CÓDIGO)

Fluix CRM es una solución all-in-one para pequeños negocios en España que combina en una sola app:

- **Gestión operativa completa:** reservas, agenda, TPV, clientes, empleados
- **Administración financiera:** facturación, contabilidad, modelos fiscales AEAT automáticos
- **Gestión de personal:** nóminas, fichajes GPS, vacaciones, finiquitos
- **Presencia digital:** perfil público, marketplace, blog, valoraciones Google
- **Ecommerce integrado:** tienda online, pedidos WhatsApp, Stripe

Especializado en el mercado español con soporte nativo para:
- Verifactu (RD 1007/2023)
- Todos los modelos AEAT relevantes para autónomos y pymes
- Régimen de estimación directa e IVA trimestral/mensual
- Tramos IRPF autonómicos 2026
- Remesas SEPA para nóminas

### Sectores con TPV especializado (diferenciador clave)
A diferencia de soluciones genéricas, Fluix CRM incluye tres TPV distintos adaptados a cada sector:
1. **TPV Peluquería** — agenda visual por profesional, timeline, tema oscuro especializado
2. **TPV Bar** — comandas de mesa, caja rápida, cierre de caja
3. **TPV Tienda** — carrito, variantes, código de barras

---

## 9. LO QUE NO SE ENCONTRÓ EN EL CÓDIGO

- Referencias a competidores (Booksy, Fresha, Square, Holded) — no aparecen
- Textos de marketing o copywriting — el código es técnico
- Precios definitivos para los add-ons "Tareas" y "Comandas Bar" — figuran como `null` (por definir)
- Integraciones con Mailchimp, Zapier, Make.com — no presentes
- Precio mensual — solo se encontraron precios anuales

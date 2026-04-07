# 🔍 AUDITORÍA UX/UI COMPLETA — FLUIX CRM
**Fecha:** 5 abril 2026  
**Auditor:** Consultor Senior UX/UI — Apps B2B para pymes españolas  
**Versión analizada:** Código fuente Flutter completo

---

## PARTE 1 — ANÁLISIS POR MÓDULO

---

### 1. 🔐 LOGIN (`pantalla_login.dart`)

**PRIMER VISTAZO:**  
Logo + "Fluix CRM" + formulario clásico. Correcto, pero el PRIMER elemento visible es un cuadro azul gigante con credenciales de demo (`AdminInitializer.adminEmail`/`adminPassword`). Un empresario real que abre la app por primera vez pensará "¿qué es esto?" o creerá que es una app de pruebas.

**FLUJOS CRÍTICOS:**  
- Login email: 2 taps (rellenar + pulsar). ✅ Correcto.  
- Login Google: 1 tap. ✅ Correcto.  
- Registro: Botón al fondo "Registrar Nueva Empresa" — demasiado abajo, requiere scroll.

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 98-166 | 🔴 **Cuadro de credenciales demo** visible en producción. El empresario no sabe qué es "AdminInitializer". DEBE eliminarse con `kDebugMode`. |
| 130 | Texto `AdminInitializer.adminEmail` y `adminPassword` expuestos → riesgo de seguridad en prod. |
| 155 | Botón "Reinicializar" — concepto de desarrollo, no de usuario final. |
| 285-288 | Logo de Google cargado desde URL remota (`Image.network`) → si no hay internet, el botón muestra un icono genérico `g_mobiledata` que el usuario no reconoce como Google. |
| 307-322 | "Registrar Nueva Empresa" al fondo con scroll — es la acción más importante para un usuario nuevo y está escondida. |

**PROBLEMAS UI:**
- SizedBox(height: 80) al inicio → demasiado espacio vacío en pantallas pequeñas.
- El botón de Google (52px alto) y el de email (56px alto) tienen alturas diferentes → inconsistencia.

**QUICK WINS:**
1. Mover cuadro de credenciales detrás de `if (kDebugMode)` — 5 minutos.
2. Subir "Registrar Nueva Empresa" encima del formulario o como tab alternativa.

---

### 2. 📋 ONBOARDING (`pantalla_onboarding.dart`)

**PRIMER VISTAZO:**  
4 pasos con barra de progreso clara (1/4, 2/4...). Header azul con "Configura tu cuenta". **Bien diseñado en general.**

**FLUJOS CRÍTICOS:**
- Completar onboarding: 4 pantallas + guardar. Correcto para la cantidad de datos.
- El paso 2 "Primer servicio" es **opcional** — bien pensado.

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 86 | `'categoria': 'General'` — El empresario no sabe qué categoría poner, pero no importa porque es interno. Bien. |
| 112-119 | Crea suscripción de prueba de 30 días silenciosamente — el usuario NO se entera. Debería mostrarse "¡Tienes 30 días gratis!" |

**QUICK WINS:**
1. Mostrar un mensaje de bienvenida final "¡Todo listo! Tienes 30 días de prueba gratuita" antes de entrar al dashboard.

---

### 3. 🏠 DASHBOARD (`pantalla_dashboard.dart` — 1390 líneas)

**PRIMER VISTAZO:**  
Tarjeta de bienvenida + badge "Online" + TabBar horizontal con todos los módulos activos. El usuario ve una barra de pestañas con 6-16 iconos pequeños (fontSize: 13, icon: 20px) que debe deslizar horizontalmente.

**FLUJOS CRÍTICOS:**  
- Acceder a un módulo: 1 tap en pestaña. ✅  
- Pero con 16 módulos activos, las pestañas de la derecha (Nóminas, Vacaciones, Web) requieren **deslizar la barra**, lo cual un usuario de 45 años no intuye.

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 300-304 | Estado de carga: `CircularProgressIndicator()` desnudo sobre fondo blanco → sin contexto, el usuario no sabe qué está cargando. |
| 420-421 | Tab labels fontSize: 13 + iconos 20px → **demasiado pequeño** para el target (mínimo recomendado: 14px). |
| 670-680 | Badge "Online" permanente → ocupa espacio sin aportar valor. El usuario siempre tiene internet si está viendo la app. |
| 973-1013 | Botón de "Datos de prueba" (icono ciencia) visible en la AppBar del dashboard → **el empresario NO debe ver esto**. |
| 494 | "Vista de Administrador" / "Vista de Usuario/Staff" — útil para desarrollo, confuso para producción. |
| 355 | `ModulosDisponibles.todos` sin lazy loading → carga TODOS los módulos aunque el usuario solo use 3. |

**PROBLEMAS UI:**
| Línea | Problema |
|-------|----------|
| 394 | Si `_tabController.length != modulosVisibles.length` → muestra **otro CircularProgressIndicator** indefinido. |
| 584 | Tarjeta bienvenida: 3 niveles de información (nombre + email + rol) en espacio reducido. El email fontSize: 12 y rol fontSize: 11 son **ilegibles** para muchos usuarios de 45+. |

**QUICK WINS:**
1. Ocultar botón datos de prueba con `kDebugMode` — 2 minutos.
2. Eliminar badge "Online" — no aporta.
3. Aumentar fontSize de tabs a 14px mínimo.
4. Si hay más de 6 módulos, usar grid en lugar de tabs horizontales.

---

### 4. 📅 RESERVAS (`modulo_reservas.dart`)

**PRIMER VISTAZO:**  
KPIs arriba (Pendientes/Confirmadas/Canceladas/Total) + 5 pestañas + lista. **Buena estructura.**

**FLUJOS CRÍTICOS:**  
- Crear reserva: 1 tap en FAB → BottomSheet con formulario. ✅ Correcto.
- Confirmar/cancelar: acciones en cada tarjeta. ✅

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 48 | 5 pestañas (Calendario, Pendientes, Confirmadas, Canceladas, Todas) → demasiadas para una pantalla que ya está dentro del TabBar principal del dashboard. **Tabs dentro de tabs dentro de tabs.** |
| 180 | KPI labels fontSize: 10 → **ilegible**. |

**PROBLEMAS UI:**
- Selector de fecha horizontal (60px ancho por día, 90px alto) — los puntos indicadores de reservas son de 5x5px → **invisibles** para dedos grandes.

---

### 5. 👥 CLIENTES (`modulo_clientes_screen.dart` — 2030 líneas)

**PRIMER VISTAZO:**  
Buscador + filtros de etiquetas (chips horizontales) + lista. **Clara y funcional.**

**FLUJOS CRÍTICOS:**  
- Buscar cliente: 1 tap en buscador. ✅  
- Crear cliente: 1 tap en FAB "Nuevo cliente". ✅  
- Importar CSV: icono en AppBar. ✅

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 139 | Error genérico: `Text('Error: ${snapshot.error}')` → el usuario ve un stack trace de Firebase. |
| 208-264 | Botón "Filtros" usa GestureDetector → **no tiene feedback visual** (InkWell sería mejor). |
| 298-301 | Chips de filtro con `materialTapTargetSize: shrinkWrap` y `visualDensity: compact` → **zona táctil demasiado pequeña** para dedos. |
| 82 | Icono `upload_file` sin texto → el empresario no sabe que es "Importar CSV". Solo tooltip. |

**QUICK WINS:**
1. Reemplazar `Text('Error: ${snapshot.error}')` por "No se pudieron cargar los clientes. Comprueba tu conexión." en todos los módulos.
2. Añadir texto al botón de importar o moverlo a un menú.

---

### 6. 🧾 FACTURACIÓN (`modulo_facturacion_screen.dart` + `formulario_factura_screen.dart`)

**PRIMER VISTAZO:**  
6 pestañas: Todas, Pendientes, Pagadas, Vencidas, Estadísticas, Contabilidad. + 2 FABs apilados verticalmente.

**FLUJOS CRÍTICOS:**  
- Crear factura: 1 tap en FAB → pantalla completa con formulario largo (6 secciones). **Demasiados campos para la primera factura.**
- Taps para completar: ~15-20 campos → el empresario abandonará antes de terminar.

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 63-83 | 2 FABs apilados → confuso. El FAB pequeño "Resumen Fiscal" compite visualmente con "Nueva Factura". |
| 99 | Tab labels fontSize: 12 → **demasiado pequeño**. |
| 193-279 | Formulario de factura: sección "Datos del Cliente" exige entender "Tipo de cliente: Particular vs Empresa/Autónomo" → el carnicero de 50 años no sabe la diferencia fiscal. |
| 327 | Sección "💰 Opciones Fiscales Avanzadas" con "Retención IRPF (freelancer)" → **jerga fiscal** que el 90% de los usuarios no necesita. |
| 344 | "initialValue" en DropdownButtonFormField → deprecado, genera warning. |
| 104 | Tab "⚠️ Vencidas" con emoji → inconsistente con las demás que no tienen emoji. |

**PROBLEMAS UI:**
- Formulario de factura tiene 6 secciones + ~20 campos en un ListView scrolleable → **no cabe en una pantalla** y el usuario pierde la referencia de dónde está.

**QUICK WINS:**
1. Dividir el formulario en steps (Stepper) con solo los campos esenciales visibles por defecto.
2. Ocultar "Opciones Fiscales Avanzadas" detrás de un expansión tile colapsado por defecto.
3. Un solo FAB. Mover "Resumen Fiscal" a la AppBar o a las acciones del menú.

---

### 7. 👷 EMPLEADOS (`modulo_empleados_screen.dart`)

**PRIMER VISTAZO:**  
Lista de empleados con resumen de roles arriba. Limpio y funcional.

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 40-51 | `_seedConveniosSeguros()` se ejecuta en `initState()` → **bloquea la carga** del módulo cada vez que se abre. Son 5 llamadas secuenciales a Firestore. |
| 66-67 | Errores raw: `Text('Error: ${snapshot.error}')`. |
| 129-141 | Chips de resumen en scroll horizontal → en pantallas de 320px no caben. Los labels "Propietario", "Admin", "Staff" son **jerga de roles** que un empleado normal no entiende. |

---

### 8. 💰 NÓMINAS (`modulo_nominas_screen.dart`)

**PRIMER VISTAZO:**  
Cabecera azul "Gestión de Nóminas — Cálculo automático · Normativa española 2026" + 4 tabs.

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 85-86 | "Normativa española 2026" → el usuario no necesita saber esto, le genera ansiedad ("¿y si no está actualizado?"). |
| 131-141 | FAB "Generar nóminas" → el texto cambia a "Generando..." sin indicar progreso ni cuánto faltará. |
| 159-175 | Estado vacío dice "Pulsa Generar nóminas para crear las del mes" → correcto pero no explica QUÉ necesita antes (empleados con datos de nómina configurados). |

---

### 9. ✅ TAREAS (`modulo_tareas_screen.dart`)

**PRIMER VISTAZO:**  
AppBar azul "Gestión de Tareas" + 3 vistas (Kanban/Lista/Calendario) + 5 tabs. **Demasiadas opciones de vista para un primer uso.**

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 57-67 | Toggle de vista (kanban→lista→calendario) usa un solo icono que cambia → el usuario no sabe que hay 3 vistas. |
| 86-92 | 5 tabs (Todas, Pendientes, En Progreso, Revisión, Completadas) + 3 vistas = **15 combinaciones** de vista. Excesivo. |
| 190 | Labels de resumen rápido fontSize: 10 → **ilegible**. |

---

### 10. 📦 PEDIDOS (`modulo_pedidos_nuevo_screen.dart`)

**PRIMER VISTAZO:**  
AppBar "Pedidos" + 6 tabs (Hoy, Esta semana, Pendientes, En Preparación, Listos, Todos) + resumen KPIs.

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 66-73 | 6 tabs es demasiado. "Hoy" y "Pendientes" se solapan conceptualmente. |
| 174 | Chip "Cobrado" con importe — buena información. |

---

### 11. 🏖️ VACACIONES (`vacaciones_screen.dart`)

**PRIMER VISTAZO:**  
Cabecera verde "Vacaciones y Ausencias — Gestión integral · Art. 38 ET + convenios". 

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 86-88 | "Art. 38 ET + convenios" → **jerga legal** que intimida. El usuario quiere gestionar vacaciones, no estudiar derecho laboral. |
| 162-177 | Estado vacío de solicitudes → solo icono + "No hay solicitudes". **No guía al usuario** sobre qué hacer. |

---

### 12. 💇 SERVICIOS (`modulo_servicios_screen.dart`)

**PRIMER VISTAZO:**  
Cabecera púrpura con KPIs + filtro por categoría + lista. **Limpio y correcto.**

**PROBLEMAS UX:**  
- Sin problemas graves. Buen diseño para este módulo.

**PROBLEMAS UI:**
| Línea | Problema |
|-------|----------|
| 84-89 | Chips de categoría fontSize: 13 → aceptable pero justo en el límite. |

---

### 13. 👤 PERFIL (`pantalla_perfil.dart`)

**PRIMER VISTAZO:**  
Tabs condicionales (Mi Perfil, Mi Empresa, Cuentas). Formulario de perfil editable.

**PROBLEMAS UX:**  
- Bien diseñado. El formulario de cambio de contraseña se esconde por defecto → correcto.

---

### 14. 💸 FINIQUITOS (`nuevo_finiquito_form.dart`)

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 39 | `CausaBaja.dimision` → terminología laboral correcta pero posiblemente confusa para el usuario. Debería tener descripción: "Dimisión (el empleado se va voluntariamente)". |
| 41-42 | "Días trabajados", "Días vac. disfrutadas", "Días vac. convenio" → 3 campos numéricos que requieren **conocimiento previo** de nóminas. |

---

### 15. ⚡ VALORACIONES / RESEÑAS (`modulo_valoraciones_fixed.dart`)

**PRIMER VISTAZO:**  
Si no hay reseñas: estado vacío centrado. Si hay: lista de reseñas con rating.

**PROBLEMAS UX EXISTENTES:**
- Overflow ya corregido en el fix anterior (SingleChildScrollView).

---

### 16. 💳 SUSCRIPCIÓN VENCIDA (`pantalla_suscripcion_vencida.dart`)

**PRIMER VISTAZO:**  
Pantalla de bloqueo con icono grande + título + botón de renovar. **Bien diseñada.**

**PROBLEMAS UX:**
| Línea | Problema |
|-------|----------|
| 100 | URL `https://fluixtech.com/renovar` → si la web no está lista, el botón lleva a un 404. |

---

## PARTE 2 — ANÁLISIS GLOBAL

---

### 1. 🔴 TOP 10 PROBLEMAS MÁS GRAVES

| # | Problema | Archivo | Por qué afecta | Solución |
|---|---------|---------|----------------|----------|
| **1** | Credenciales de demo y botones de desarrollo visibles en producción | `pantalla_login.dart:98-166` | Un empresario real ve emails/passwords de demo y botones "Reinicializar" → piensa que es una app de pruebas, pierde confianza | Envolver en `if (kDebugMode)` |
| **2** | Botón "Datos de prueba" (icono ciencia) visible en dashboard producción | `pantalla_dashboard.dart:973-1013` | El empresario puede pulsar "Generar datos de prueba" y llenar su negocio real de datos falsos | Envolver en `if (kDebugMode)` |
| **3** | Navegación por tabs con 16 módulos requiere deslizar lateralmente | `pantalla_dashboard.dart:410-426` | Un usuario de 45+ no intuye que debe deslizar una barra de pestañas. Los módulos del final son invisibles. | Reemplazar TabBar por grid de módulos o bottom navigation con menú "Más" |
| **4** | Errores raw de Firebase visibles al usuario en 5+ pantallas | Múltiples (`snapshot.error`) | El usuario ve "Error: [cloud_firestore/permission-denied]..." → no entiende nada | Crear widget `ErrorGenerico` con mensaje humano y botón reintentar |
| **5** | Textos con fontSize 10-11px en KPIs y labels | `modulo_reservas.dart:180`, `modulo_tareas_screen.dart:190`, `pantalla_dashboard.dart:651` | Ilegible para el 50% del target (personas 45+, frecuentemente sin gafas a mano) | Mínimo 13px para labels secundarios, 14px para texto de lectura |
| **6** | Seed de convenios en initState del módulo empleados | `modulo_empleados_screen.dart:40-51` | Cada vez que el usuario abre Empleados, se ejecutan 5 queries a Firestore. Bloquea la UI y consume reads innecesarios | Mover a Cloud Function o a primer arranque (una sola vez) |
| **7** | Formulario de factura con 20+ campos sin separación de complejidad | `formulario_factura_screen.dart:192-368` | El empresario medio crea su primera factura y se encuentra "Retención IRPF", "NIF/CIF/NIE", "Días hasta vencimiento" → abandona | Formulario simplificado por defecto + "Opciones avanzadas" colapsadas |
| **8** | Múltiples niveles de tabs (dashboard→módulo→sub-tabs) | Dashboard tabs + Reservas (5 tabs) + Facturación (6 tabs) | El usuario se pierde en 3 niveles de navegación. "¿Dónde estaba?" | Limitar a 2 niveles máximo. Sub-tabs máximo 4. |
| **9** | Estados vacíos inconsistentes y sin CTA claros | `vacaciones_screen.dart:162-177`, múltiples módulos | Algunos estados vacíos guían ("Pulsa X para..."), otros solo dicen "No hay datos" sin explicar qué hacer | Estandarizar componente `EstadoVacioFluix` con ilustración + texto + botón acción |
| **10** | CircularProgressIndicator desnudo como único estado de carga | Todos los módulos | El usuario ve un spinner sin contexto → no sabe si la app se colgó, si está cargando, o cuánto tardará | Usar skeleton loaders (ya creados) + mensaje "Cargando reservas..." |

---

### 2. INCONSISTENCIAS GLOBALES

| Patrón | Estado actual | Problema |
|--------|--------------|---------|
| **Navegación principal** | TabBar horizontal scrollable en AppBar del dashboard | Inconsistente: algunos módulos usan AppBar propia (Tareas, Pedidos), otros no (Reservas, Valoraciones) |
| **Botón primario** | FAB.extended en la mayoría → colores diferentes: azul (0xFF0D47A1), teal (0xFF00796B), púrpura (0xFF7B1FA2) | Cada módulo tiene un color de FAB diferente. El usuario no tiene un "botón de acción" consistente |
| **Estado de carga** | `CircularProgressIndicator()` en todos los módulos | Nunca se usan los skeleton loaders. Experiencia monótona y sin contexto |
| **Estado vacío** | Varía: icono 72px + texto en algunos; icono 56px + texto + CTA en otros; solo texto en otros | Sin componente estándar. Tamaños de icono, espaciados y presencia de CTA varían |
| **Formularios** | BottomSheet en Empleados/Servicios; Pantalla completa en Facturas/Tareas | El usuario no sabe predecir si crear algo abrirá media pantalla o una pantalla nueva |
| **Colores de estado** | Rojo = cancelado/error, verde = confirmado/activo, naranja = pendiente | ✅ Consistente — bien hecho |
| **Cabeceras de módulo** | Algunos tienen (Nóminas, Vacaciones, Empleados) con gradiente + icono + subtítulo legal. Otros no (Facturación, Clientes, Tareas) | La mitad de los módulos tiene cabecera premium y la otra mitad no |

---

### 3. LENGUAJE Y TEXTOS

| Término actual | Propuesta más clara | Archivo |
|---------------|---------------------|---------|
| "Retención IRPF (freelancer)" | "Retención de impuestos (solo autónomos)" + tooltip explicativo | formulario_factura_screen.dart:345 |
| "NIF/CIF/NIE" | "Número de identificación fiscal" con ejemplo "Ej: 12345678Z" | formulario_factura_screen.dart:257 |
| "Art. 38 ET + convenios" | "Según la normativa laboral vigente" o eliminar | vacaciones_screen.dart:86 |
| "Normativa española 2026" | Eliminar — no aporta confianza, genera duda | modulo_nominas_screen.dart:85 |
| "CausaBaja.dimision" | "Baja voluntaria (dimisión)" | nuevo_finiquito_form.dart:39 |
| "EstadoPedido.enPreparacion" | "En preparación" (ya bien traducido en UI) | ✅ |
| "kDebugMode" | No visible al usuario | ✅ (pero widgets de debug SÍ son visibles) |
| "Seed de convenios" | No visible | ✅ |
| "StreamBuilder" / "snapshot" | No visible | ✅ |
| "Error: ${snapshot.error}" | "No se pudo cargar. Toca para reintentar." | Múltiples archivos |
| "Error: $e" | "Ha ocurrido un error. Inténtalo de nuevo." | Múltiples archivos |
| "Ingresa tu correo electrónico" | "Escribe tu correo" (más natural en España) | pantalla_login.dart:180 |
| "Ingresa tu contraseña" | "Escribe tu contraseña" | pantalla_login.dart:214 |
| "💰 Opciones Fiscales Avanzadas" | "Opciones adicionales" (colapsado) | formulario_factura_screen.dart:327 |
| "Dias hasta vencimiento" | "Plazo de pago (días)" | formulario_factura_screen.dart:322 |
| "Staff" (rol) | "Empleado" | modulo_empleados_screen.dart:140 |

---

### 4. ACCESIBILIDAD BÁSICA

| Criterio | Estado | Detalle |
|----------|--------|---------|
| Contraste textos principales | ⚠️ | Textos en `Colors.grey[500]` sobre fondo `0xFFF5F7FA` → ratio ~2.5:1, **no pasa WCAG AA** (mínimo 4.5:1) |
| Iconos con tooltip | ⚠️ | Algunos sí (`tooltip: 'Catálogo de productos'`), otros no (iconos de filtro, reordenar) |
| Labels de formulario | ✅ | Todos usan `labelText` en InputDecoration → bien |
| Acciones destructivas con confirmación | ✅ | "Reinicializar empresa" tiene diálogo de confirmación. "Cancelar reserva" también |
| Tamaño mínimo de targets táctiles | ❌ | Chips de filtro (clientes) usan `shrinkWrap` + `compact` → **<44px**. Puntos del calendario (5x5px) → inaccessible |
| Semántica (Semantics) | ❌ | No se usa `Semantics` widget en ningún lugar → lectores de pantalla no pueden describir la UI |

---

### 5. ADAPTACIÓN AL TARGET

| Criterio | Evaluación |
|----------|-----------|
| **Elementos táctiles suficientemente grandes** | ❌ Chips de filtro, puntos de calendario, iconos de AppBar de 20px → demasiado pequeños para manos de cocinero o peluquera con guantes |
| **Acciones frecuentes a 1 tap** | ⚠️ Crear reserva/pedido/factura = 1 tap (FAB). Pero ver el módulo correcto puede requerir deslizar la barra de tabs → 2-3 gestos |
| **Poco scroll para lo importante** | ❌ Dashboard requiere scroll horizontal en tabs + scroll vertical en contenido. Formulario de factura requiere mucho scroll vertical |
| **Una sola mano** | ⚠️ FABs están abajo a la derecha → alcanzable. Pero las tabs del dashboard están arriba → requiere cambiar de mano o estirarse |
| **Entorno ruidoso** | ✅ No depende de audio. Notificaciones son visuales (badge) |

---

## PARTE 3 — TABLA DE PRIORIZACIÓN

### 🔴 CRÍTICO — Confunde o impide usar la app

| # | Módulo | Problema | Solución | Esfuerzo |
|---|--------|---------|----------|----------|
| C1 | Login | Credenciales demo + botón Reinicializar en producción | `if (kDebugMode)` wrapper | Bajo (<1h) |
| C2 | Dashboard | Botón "Datos de prueba" visible en producción | `if (kDebugMode)` wrapper | Bajo (<1h) |
| C3 | Dashboard | Botón "Vista simulada" (Propietario/Admin/Staff) en producción | `if (kDebugMode)` o solo si `esPlatformaAdmin` | Bajo (<1h) |
| C4 | Múltiples | `Text('Error: ${snapshot.error}')` muestra errores de Firebase al usuario | Widget `ErrorGenerico` con mensaje humano | Medio (2h) |
| C5 | Empleados | Seed de convenios bloquea UI cada vez que se abre el módulo | Mover a Cloud Function o flag `ya_sembrado` | Medio (2h) |

### 🟡 IMPORTANTE — Fricción significativa

| # | Módulo | Problema | Solución | Esfuerzo |
|---|--------|---------|----------|----------|
| I1 | Dashboard | 16 tabs horizontales inilegibles | Grid de módulos o bottom nav + "Más" | Alto (>4h) |
| I2 | Facturación | Formulario 20+ campos sin separación de complejidad | Stepper simplificado + "Avanzado" colapsado | Alto (>4h) |
| I3 | Global | fontSize 10-11px en KPIs y labels | Audit global: mínimo 13px labels, 14px cuerpo | Medio (3h) |
| I4 | Global | CircularProgressIndicator sin contexto | Integrar skeleton_loaders.dart ya creado | Medio (3h) |
| I5 | Global | Estados vacíos inconsistentes | Componente `EstadoVacioFluix` estándar | Medio (2h) |
| I6 | Dashboard | TabBar dentro de TabBar dentro de TabBar | Reducir a 2 niveles máximo | Alto (>4h) |
| I7 | Login | "Registrar Nueva Empresa" escondido al fondo con scroll | Mover arriba o hacer tab Login/Registro | Bajo (<1h) |
| I8 | Múltiples | Cabeceras con subtítulos legales ("Art. 38 ET") | Eliminar referencias legales de la UI | Bajo (<1h) |
| I9 | Global | Colores de FAB diferentes por módulo | Un solo color primario para todas las acciones principales | Bajo (<1h) |
| I10 | Clientes/Filtros | Chips con target <44px | Aumentar padding y quitar `shrinkWrap` | Bajo (<1h) |

### 🟢 MEJORA — Pulir cuando haya tiempo

| # | Módulo | Problema | Solución | Esfuerzo |
|---|--------|---------|----------|----------|
| M1 | Login | Logo Google desde URL remota | Bundear como asset local | Bajo (<1h) |
| M2 | Dashboard | Badge "Online" permanente sin valor | Eliminar o mostrar solo cuando hay issues de conexión | Bajo (<1h) |
| M3 | Tareas | 3 vistas (Kanban/Lista/Calendario) con toggle no intuitivo | Usar SegmentedButton con labels | Medio (2h) |
| M4 | Facturación | 2 FABs apilados | Un FAB + menú contextual | Bajo (<1h) |
| M5 | Nóminas | "Generando..." sin barra de progreso | Mostrar progreso (1/5, 2/5...) | Medio (2h) |
| M6 | Onboarding | No dice "30 días gratis" al completar | Pantalla de bienvenida final | Bajo (<1h) |
| M7 | Global | Sin Semantics para accesibilidad | Añadir Semantics a widgets clave | Alto (>4h) |
| M8 | Global | "Ingresa" → "Escribe" (español de España, no LatAm) | Buscar y reemplazar en todo el proyecto | Bajo (<1h) |
| M9 | Reservas | Puntos indicadores 5x5px en calendario | Aumentar a 8px mínimo | Bajo (<1h) |
| M10 | Perfil | Sin foto de perfil visual (solo iniciales) | Añadir opción de subir avatar | Medio (3h) |

---

## PARTE 4 — RECOMENDACIONES DE DISEÑO

---

### 1. Sistema de Tipografía Recomendado

```dart
// theme_typography.dart
class FluixTypography {
  // Títulos de pantalla / módulo
  static const titulo = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, height: 1.2,
  );
  // Subtítulos / headers de sección  
  static const subtitulo = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, height: 1.3,
  );
  // Texto de lectura principal
  static const cuerpo = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400, height: 1.5,
  );
  // Labels de formulario, KPIs, chips
  static const label = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, height: 1.4,
  );
  // Captions, timestamps, metadatos
  static const caption = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, height: 1.3,
    color: Color(0xFF757575), // grey[600]
  );
  // Botones
  static const boton = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600, height: 1.2,
  );
}
```

**Regla de oro para este target:** Nada por debajo de 13px.

---

### 2. Sistema de Colores Recomendado

```dart
class FluixColors {
  // Primario — toda la app, FABs, acciones principales
  static const primario = Color(0xFF1976D2);
  static const primarioOscuro = Color(0xFF0D47A1);
  static const primarioClaro = Color(0xFFE3F2FD);
  
  // Secundario — acentos, elementos destacados
  static const secundario = Color(0xFF00796B);
  
  // Estados semánticos
  static const exito = Color(0xFF2E7D32);     // Verde — confirmado, activo, pagado
  static const error = Color(0xFFC62828);      // Rojo — cancelado, vencido, error
  static const advertencia = Color(0xFFF57C00);// Naranja — pendiente, atención
  static const info = Color(0xFF1565C0);       // Azul — informativo
  
  // Neutros
  static const fondo = Color(0xFFF5F7FA);
  static const superficie = Colors.white;
  static const textoP = Color(0xFF212121);     // grey[900]
  static const textoS = Color(0xFF616161);     // grey[700] — NO grey[500]
  static const borde = Color(0xFFE0E0E0);      // grey[300]
}
```

**Cambio clave:** Dejar de usar `Colors.grey[500]` para texto secundario → usar `grey[700]` (0xFF616161) para cumplir contraste WCAG.

---

### 3. Componentes a Estandarizar

| Widget | Reemplaza | Propósito |
|--------|-----------|-----------|
| `AppBarFluix` | AppBars inconsistentes (blanca en Clientes, azul en Tareas) | AppBar estándar con título, acciones opcionales, siempre mismo color |
| `EstadoVacioFluix` | 10+ implementaciones diferentes de estado vacío | Icono (72px) + título + subtítulo + botón acción opcional |
| `EstadoCargaFluix` | `Center(child: CircularProgressIndicator())` | Skeleton loader con mensaje opcional |
| `EstadoErrorFluix` | `Text('Error: ${snapshot.error}')` | Mensaje humano + botón "Reintentar" + icono |
| `BotonPrincipalFluix` | FABs con colores diferentes | FAB.extended siempre con `FluixColors.primario` |
| `TarjetaModuloFluix` | Cards con estilos diferentes en cada módulo | Card con borde radius 12, elevation 2, padding 16 |
| `CabeceraModuloFluix` | Cabeceras gradiente que solo existen en algunos módulos | Gradiente + icono + título + subtítulo (sin jerga legal) |
| `ChipFiltroFluix` | Chips con target <44px | Chip con mínimo 44px alto, padding correcto |
| `KpiBadgeFluix` | KPIs con fontSize 10 | Badge con valor grande (20px+) y label 13px+ |
| `FormularioSeccionFluix` | Cards de sección en formularios | Sección colapsable con título y contenido |

---

### 4. Patrones de Navegación Recomendados

| Situación | Recomendación | Por qué |
|-----------|---------------|---------|
| **Módulos principales (>6)** | BottomNavigationBar con 4-5 items + "Más" (grid) | Las tabs horizontales no escalan a 16 módulos. BottomNav es el patrón más familiar para usuarios no técnicos. |
| **Sub-navegación dentro de módulo** | TabBar (máximo 4 tabs) | 5-6 tabs es demasiado. Agrupar: "Hoy"+"Esta semana" → "Próximos". |
| **Crear/editar item simple** (reserva, servicio) | BottomSheet (media pantalla) | Rápido, no pierde contexto, vuelve al módulo al cerrar. |
| **Crear/editar item complejo** (factura, nómina) | Pantalla completa con Stepper | Necesita espacio. El Stepper muestra progreso. |
| **Acciones sobre un item** (confirmar, cancelar, borrar) | BottomSheet con 2-3 opciones | Familiar (como WhatsApp al mantener pulsado). |
| **Configuración** | Pantalla completa con back | Siempre desde menú o perfil. |

**Layout recomendado para el Dashboard:**

```
┌─────────────────────────────┐
│  AppBar: Fluix CRM    🔔 ⚙️ │
├─────────────────────────────┤
│  Bienvenido, Juan           │
│  📊 Tu resumen de hoy       │
├─────────────────────────────┤
│  [Grid 2x3 de módulos]     │
│  📅 Reservas    👥 Clientes  │
│  🧾 Facturas    ✅ Tareas   │
│  📦 Pedidos     ⭐ Reseñas  │
│  → Ver todos los módulos    │
├─────────────────────────────┤
│  BottomNav:                 │
│  🏠 Inicio  📅 Reservas     │
│  🧾 Facturas  ⋯ Más         │
└─────────────────────────────┘
```

---

## RESUMEN EJECUTIVO

**Estado actual:** La app tiene una **funcionalidad impresionante** (16+ módulos con profundidad real) pero la UX está diseñada para un desarrollador, no para un empresario de 45 años. Los problemas más graves son: elementos de desarrollo visibles en producción (credenciales demo, botones de prueba), navegación por tabs que no escala a 16 módulos, textos de error crudos de Firebase, y fuentes demasiado pequeñas para el target.

**Prioridad #1:** Envolver TODOS los elementos de desarrollo (`if (kDebugMode)`) — son 3 cambios de 5 minutos que transforman la percepción de la app de "prototipo" a "producto profesional".


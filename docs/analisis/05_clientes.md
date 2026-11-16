# 05 — Clientes (Multi-tenant, RGPD, CRM)

> Análisis: 2026-10-26 | Versión app: 1.0.18 | Firebase: planeaapp-4bea4

---

## Estado actual

El módulo Clientes es un CRM embebido dentro del SaaS multi-tenant Fluix. Almacena personas físicas y jurídicas bajo la ruta `empresas/{empresaId}/clientes/{clienteId}`, lo que proporciona aislamiento estructural por empresa.

**Modelo de datos (`cliente.dart`):** nombre, teléfono, correo, NIF/CIF, dirección, localidad, total_gastado, ultima_visita, numero_reservas, etiquetas, notas, fecha_registro, activo, es_intracomunitario, nif_iva_comunitario, estado (contacto/activo/inactivo), ficha_incompleta, no_contactar, estado_fusionado, fusionado_con_id, ultima_actividad. La pantalla añade adicionalmente: fecha_nacimiento, instagram, preferencias/alergias, origen (cómo nos conoció).

**Datos sensibles presentes:**
- NIF/CIF (dato fiscal protegido por la LOPDGDD)
- Fecha de nacimiento
- Preferencias/alergias (potencialmente datos de salud — categoría especial art. 9 RGPD)
- Instagram handle (dato personal)
- Notas internas (texto libre, puede contener datos arbitrarios)
- Email y teléfono (datos de contacto)

**Flujos de escritura de clientes:**
1. Manual desde UI (propietario/admin)
2. Automático via Cloud Functions: reserva confirmada, pedido web, pedido WhatsApp, factura creada/anulada
3. Importación masiva CSV (nombre + NIF obligatorios)

**Fidelización:** implementada como tarjetas de sellos en `usuarios/{uid}/tarjetas_sellos/{negocioId}` (B2C) y programa en `negocios_publicos/{negocioId}/programa_fidelizacion`. Los puntos y el monedero se almacenan en `usuarios/{uid}/monedero` (colección independiente del cliente CRM), lo que implica que el cliente CRM (B2B) y el usuario B2C son entidades diferentes no vinculadas automáticamente.

---

## Riesgos

| Nivel | Descripción | Fichero:Línea |
|-------|-------------|---------------|
| **CRÍTICO** | **Datos de salud sin base legal explícita**: el campo `preferencias/alergias` se muestra en amber como "alergias" pero se almacena en texto libre sin base legal documentada (art. 9 RGPD exige consentimiento explícito o excepción). No hay flag de consentimiento en el modelo. | `modulo_clientes_screen.dart:893`, `cliente.dart` — campo ausente |
| **CRÍTICO** | **Sin campo de consentimiento RGPD en el modelo de cliente.** Ni `consentimiento_fecha`, ni `consentimiento_tipo`, ni `base_legal`. La importación CSV puede crear miles de contactos sin acreditar el consentimiento previo de cada persona. | `cliente.dart` — campo ausente; `importacion_clientes_service.dart:57` |
| **ALTO** | **`buscarOCrearCliente` hace full-scan de la colección** (líneas 74, 84, 522, 526 de `automaciones_clientes.ts`): `col.get()` sin filtros en pasos 2 (teléfono) y 3 (nombre). Con 1.000+ clientes esto genera lecturas masivas en cada reserva/pedido, potencial desbordamiento de tiempo de función y coste. | `automaciones_clientes.ts:74,84` |
| **ALTO** | **Exportación CSV sin protección**: cualquier usuario autenticado en la empresa puede exportar y compartir la lista completa de clientes (nombre, teléfono, correo, NIF, ciudad) sin log de auditoría ni confirmación. El CSV se guarda en carpeta temporal y se comparte via share_plus sin cifrado. | `modulo_clientes_screen.dart:1456–1517` |
| **ALTO** | **Borrado de cliente no elimina subcolecciones ni datos vinculados**: `_eliminarCliente` hace `doc.delete()` pero no borra interacciones, actividad, snapshots de fusión ni actualiza reservas/facturas que referencian al cliente. Incumple el "derecho de supresión" (art. 17 RGPD) de forma completa. | `modulo_clientes_screen.dart:1422–1453` |
| **ALTO** | **`clienteFinal` no tiene regla de acceso a sus propios datos en `/clientes`**: el rol existe en usuarios (firestore.rules:183) y en el enrutamiento de la app (main.dart:443), pero la regla de `empresas/{id}/clientes` solo permite acceso a `puedeVerModulo` (staff+) y `esAdminOPropietario`. Un `clienteFinal` con cuenta propia no puede ver ni sus propios datos en el CRM. | `firestore.rules:449–452` |
| **MEDIO** | **Sin índice Firestore para búsqueda por email en clientes**: `buscarOCrearCliente` hace `where("correo", "==", ...)` pero solo existe índice para `activo+nombre` y `telefono+activo`. Consultas por correo generan full-scan o error en colecciones grandes. | `firestore.indexes.json:100–126` |
| **MEDIO** | **Fusión no reversible para reservas/pedidos**: `deshacerFusion` revierte facturas pero no existe código de rollback para interacciones (`actividad`) copiadas al cliente principal. El snapshot expira en 30 días. | `fusion_clientes_service.dart:273–367` |
| **MEDIO** | **Fecha de nacimiento almacenada como String sin formato validado**: `cumpleCtrl` acepta `DD/MM` sin parseo ni validación en UI ni en servicio, lo que impide uso seguro (cumpleaños, cálculo de edad). | `modulo_clientes_screen.dart:1186,1249` |
| **BAJO** | **`_fusionSnapshot` no está cubierta por reglas Firestore**: la subcolección `clientes/{id}/_fusion_snapshot` almacena datos personales completos del duplicado durante 30 días pero no tiene regla explícita en `firestore.rules`. Queda cubierta por el catch-all `allow read, write: if false`, lo que es correcto pero involuntario. | `firestore.rules:1762`, `fusion_clientes_service.dart:138` |
| **BAJO** | **`recalcularStatsCliente` callable no verifica que el caller pertenezca a la misma empresa que el cliente**: verifica autenticación (`request.auth.uid`) pero no llama a `perteneceAEmpresa`. Un usuario de empresa A podría recalcular stats de un cliente de empresa B si conoce los IDs. | `automaciones_clientes.ts:382–455` |

---

## Diferencias por plataforma (iOS / Android / Windows)

| Aspecto | iOS | Android | Windows (web/desktop) |
|---------|-----|---------|-----------------------|
| Descarga CSV | Guarda en temp + muestra toast ("guardado localmente") | Guarda en Downloads (getDownloadsDirectory) + toast de ruta | Guarda en temp — no hay ruta accesible para el usuario |
| Compartir CSV | share_plus funciona (Share Sheet nativo) | share_plus funciona | share_plus no disponible en Windows desktop |
| Importación CSV | FilePicker con `withData: true` — funciona | FilePicker con `withData: true` — funciona | Windows: leyó desde bytes (correcto tras fix commit b5b21188) |
| Llamar/Email | `tel:` y `mailto:` via launchUrl | Igual | Links no se abren en modo web de escritorio |
| Fidelización QR | Cámara disponible | Cámara disponible | QR no disponible sin webcam |

---

## Cumplimiento legal (RGPD, LOPDGDD, derechos ARCO)

| Requisito | Estado | Observación |
|-----------|--------|-------------|
| **Base legal documentada** | Ausente | No hay campo en el modelo ni en la UI que registre la base jurídica (contrato, consentimiento, interés legítimo) para cada cliente. |
| **Consentimiento explícito** | Ausente | No existe campo `consentimiento_fecha` ni `consentimiento_canal`. |
| **Datos de salud (alergias)** | No conforme | Campo `preferencias/alergias` almacena potencial dato de salud (art. 9 RGPD). Requiere consentimiento explícito o supresión del campo o separación clara entre preferencias no-sanitarias y alergias. |
| **Derecho de acceso** | Parcial | Un `clienteFinal` autenticado no puede acceder a sus propios datos en el CRM. Solo el admin puede verlos. |
| **Derecho de rectificación** | Parcial | El admin puede editar. El propio interesado no tiene flujo propio. |
| **Derecho de supresión (art. 17)** | No conforme | `_eliminarCliente` borra el doc pero deja subcolecciones (interacciones, actividad, _fusion_snapshot) y referencias en facturas/reservas. Borrado no es completo. |
| **Portabilidad (art. 20)** | Parcial | El CSV exporta campos básicos pero no las interacciones, actividad CRM ni histórico de reservas del cliente. |
| **Retención de datos** | No definida | No existe política de retención en código. Clientes inactivos no se purgan automáticamente. El `_fusion_snapshot` tiene 30 días pero sin proceso de limpieza automático. |
| **Importación masiva** | No conforme | No hay validación ni checkbox de "consentimiento previo verificado" antes de importar. Un archivo CSV de terceros podría importarse sin base legal. |
| **Registro de actividad (logs)** | Ausente | No hay log de quién exportó, importó o eliminó datos de clientes. Existe colección `auditoria` pero no se escribe en operaciones de clientes. |
| **Transferencias internacionales** | Neutral | Firebase europe-west1 (Bélgica). Correcto para UE/RGPD. |

---

## Deuda técnica

1. **Modelo desincronizado entre `cliente.dart` y `modulo_clientes_screen.dart`**: la pantalla usa campos `ciudad`, `instagram`, `preferencias`, `fecha_nacimiento` que no existen en `Cliente.fromFirestore` ni en `toFirestore`, pero sí se escriben directamente desde el popup. Esto crea documentos con esquema inconsistente.

2. **`toFirestore()` serializa `estado_cliente` pero `fromFirestore()` lee `estado`** (discrepancia de nombre de campo): `toFirestore` escribe `estado_cliente` pero el Enum se llama `estado` en el modelo y el servicio de estado escribe `estado_cliente`. El campo en Firestore puede tener dos nombres distintos según el origen de escritura.

3. **`upsertClienteDesdeReserva` en `clientes_service.dart` incrementa `num_reservas`** pero el campo real del modelo es `numero_reservas`. Campo desincronizado que produce dos contadores paralelos.

4. **Búsqueda de texto solo en memoria**: `filtrarClientes` carga todos los docs del stream y filtra en cliente. Para empresas con >500 clientes, esto implica leer toda la colección en cada render. No hay paginación server-side.

5. **Importación usa NIF como ID de documento** pero los clientes creados manualmente o desde reservas usan IDs auto-generados. La colección tendrá dos convenciones de ID coexistentes sin que la app pueda distinguirlas.

6. **`ClienteEstadoService` tiene dos métodos para el umbral** (`obtenerUmbralDias` y `obtenerUmbralInactividad`) que leen campos distintos del mismo doc de configuración (`umbral_inactividad_dias` vs `umbral_alerta_inactividad_dias`). El módulo silenciosos usa `obtenerUmbralInactividad` (60 días default) pero el recálculo general usa `obtenerUmbralDias` (90 días default). Dos umbrales inconsistentes.

---

## Lista priorizada de acciones

| Prioridad | Acción | Esfuerzo |
|-----------|--------|----------|
| P0 — Legal | Añadir campos `consentimiento_fecha`, `base_legal` y `consentimiento_canal` al modelo `Cliente` y al formulario de creación/importación | M |
| P0 — Legal | Separar campo `preferencias` (gastronómico/servicio) de `alergias_salud` (dato categoría especial) y requerir base legal para este último | M |
| P0 — Legal | Implementar borrado completo RGPD: cascade delete de subcolecciones + anonimización de referencias en facturas/reservas (función callable `borrarDatosCliente`) | L |
| P1 — Seguridad | Añadir verificación `perteneceAEmpresa(empresaId)` en `recalcularStatsCliente` y `enviarEmailBienvenidaCliente` callables | S |
| P1 — Rendimiento | Refactorizar `buscarOCrearCliente` para usar índices: `where("correo",...)` con índice + `where("telefono_norm",...)` con índice. Eliminar full-scan `col.get()` | M |
| P1 — Datos | Añadir índice Firestore para `correo ASC` en colección `clientes` | S |
| P1 — Datos | Unificar campo `estado_cliente` (toFirestore escribe `estado_cliente`, fromFirestore lee `estado`) | S |
| P2 — Funcional | Regla Firestore: permitir a `clienteFinal` leer y actualizar su propio documento en `/clientes` (buscar por `usuario_uid`) | S |
| P2 — Funcional | Añadir log de auditoría en exportación CSV, importación y borrado de clientes (`auditoria/{empresaId}/accesos`) | M |
| P2 — UX | Añadir validación de fecha de nacimiento (DD/MM) con regexp y parseo real | S |
| P2 — Datos | Unificar campo `num_reservas` vs `numero_reservas` en `upsertClienteDesdeReserva` | S |
| P3 — Deuda | Sincronizar `cliente.dart` con campos adicionales que usa la pantalla (`ciudad`, `instagram`, `fecha_nacimiento`, `preferencias`) | M |
| P3 — Rendimiento | Implementar paginación server-side (`startAfter`) para empresas con >500 clientes en lugar de filtrado en memoria | L |
| P3 — Deuda | Unificar los dos umbrales de inactividad (60 vs 90 días) en un único campo `umbral_inactividad_dias` | S |

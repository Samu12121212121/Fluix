# 03 — Fichajes (RDL 8/2019)

> Análisis de solo lectura — planeag_flutter v1.0.18 · 2026-10-26

---

## Estado actual

El módulo de fichajes es el más maduro del proyecto en términos de arquitectura legal. Está dividido en dos rutas de acceso paralelas:

- **Kiosk PIN** (`PantallaFichajeEmpleado`) — empleados sin cuenta de app que fichan mediante un teclado numérico de 4 dígitos en un tablet o PC compartido.
- **App personal** (`PantallaFichaje`, en `lib/features/fichaje/`) — empleados con cuenta Firebase Auth que fichan desde su propio dispositivo.

Ambas rutas comparten el mismo `FichajeService` y el mismo modelo `Fichaje`, que sigue el esquema **un documento por jornada** (entrada, salida y array de pausas en un mismo documento de Firestore). Las correcciones generan un documento nuevo con `es_correccion: true`, dejando el original intacto.

El módulo incluye: exportación CSV para Inspección de Trabajo, resumen mensual por empleado (`ResumenMensualEmpleadosScreen`), historial individual (`HistorialEmpleadoSheet`), y generación de informe PDF (a través del botón "Informe PDF" en `GestionFichajesScreen` que llama a `_TabInformes`).

### Dependencias relevantes en pubspec.yaml

| Paquete | Versión | Uso declarado |
|---|---|---|
| `geolocator` | ^13.0.1 | GPS en el comentario del pubspec ("control horario / fichaje") |
| `local_auth` | ^2.3.0 | Biometría (FaceID / Huella) |
| `signature` | ^6.0.0 | Firma manuscrita |
| `crypto` | ^3.0.3 | SHA-256 en fichaje_service.dart |
| `device_info_plus` | ^10.1.2 | Log de auditoría |

---

## Riesgos

| Nivel | Descripción | Fichero:Línea |
|---|---|---|
| **CRÍTICO** | El PIN de 4 dígitos se almacena en texto plano en Firestore (`empleados_fichaje/{uid}.pin`). Un admin de plataforma o cualquier persona con acceso a la consola Firebase puede leerlos directamente. No hay hash (bcrypt, SHA-256 salted) ni cifrado. | `fichaje.dart:206`, `fichaje_service.dart:79-87` |
| **CRÍTICO** | La subcollección `audit_log` que registra cada corrección no tiene reglas en `firestore.rules`. Un atacante autenticado que conozca el path puede escribir o leer entradas de auditoría sin restricción, invalidando la trazabilidad exigida por RDL 8/2019. | `fichaje_service.dart:349`, `firestore.rules` (ausente) |
| **ALTO** | El hash SHA-256 de integridad (`firma_integridad`, `firma_salida`) se calcula con `DateTime.now()` en el cliente antes de que Firestore asigne el `serverTimestamp`. El hash y el timestamp real del servidor pueden diferir en hasta varios segundos (o más si el dispositivo tiene el reloj mal ajustado), rompiendo la verificación. No existe ninguna Cloud Function que verifique los hashes en servidor. | `fichaje_service.dart:128-134`, `fichaje_service.dart:278-289` |
| **ALTO** | Las pausas usan `Timestamp.now()` (reloj del cliente), no `serverTimestamp`, porque Firestore no admite serverTimestamp dentro de arrays. Esto es una limitación documentada del SDK, pero hace que los tiempos de pausa sean falsificables desde el cliente con el reloj manipulado. No existe mitigación (p. ej. Cloud Function que corrija el timestamp). | `fichaje_service.dart:199`, `fichaje_service.dart:246` |
| **ALTO** | Geolocalización declarada en `pubspec.yaml` pero **no se captura ni se almacena** en ningún campo del documento de fichaje. El modelo `Fichaje` no tiene campos `lat`, `lon` ni `direccion`. La pantalla de gestión muestra una columna "UBICACIÓN" que siempre muestra `'—'`. | `fichaje.dart` (modelo completo), `gestion_fichajes_screen.dart:910` |
| **MEDIO** | Biometría (`local_auth`) declarada en pubspec y con `BiometriaService` implementado, pero **no se llama en ningún punto del flujo de fichaje**. Se usa solo para el login de la app, no para confirmar el fichaje. El kiosk (pantalla de empleados) no tiene ninguna capa de seguridad más allá del PIN numérico de 4 dígitos. | `biometria_service.dart`, `pantalla_fichaje_empleado.dart` (sin referencia) |
| **MEDIO** | La firma manuscrita (`signature`) tampoco se usa en el flujo de fichaje. `FirmaService` solo gestiona firmas de nóminas. Si se añadiese como fallback al PIN no existiría para empleados sin cuenta. | `firma_service.dart` |
| **MEDIO** | No existe política de retención / TTL configurada en Firestore para borrar datos después de 4 años. La UI muestra el texto "Registros conservados 4 años · RDL 8/2019" pero ninguna Cloud Function, scheduled job ni regla de Firestore TTL hace cumplir esa retención (ni el borrado automático al cumplirse). | `historial_empleado_sheet.dart:253` |
| **MEDIO** | La regla de escritura del empleado en Firestore permite modificar solo `salida` y `pausas`, pero no bloquea la edición de `salida` en un fichaje ya cerrado (`salida != null`). Un empleado podría reabrir su jornada sobreescribiendo la salida con `null` si el documento original no está en `es_correccion: false`. | `firestore.rules:711-715` |
| **BAJO** | El gráfico de tabla en `GestionFichajesScreen` limita la vista a `fichajes.take(10)` o `take(12)`, lo que puede ocultar fichajes si hay muchos empleados ese día. No afecta al cumplimiento pero sí a la visibilidad operativa del admin. | `gestion_fichajes_screen.dart:851` |
| **BAJO** | Carpeta duplicada (`lib/features/fichaje/` legacy + `lib/features/fichajes/` activa). La carpeta legacy contiene código vivo (`PantallaFichaje`, `MisHorasMesSection`) importado por la carpeta nueva. Si se modifica el service en la carpeta activa la carpeta legacy queda desincronizada. | `pantalla_fichaje.dart:7-9` |

---

## Diferencias por plataforma

### iOS
- `local_auth` (FaceID) está configurado en `Info.plist` y funciona. No se usa en el flujo de fichaje, solo en login.
- `geolocator` funciona correctamente. La geolocalización en el fichaje podría activarse sin cambios de infraestructura.
- El kiosk PIN funciona en cualquier iPad. El código usa `maxWidth < 640` para detectar móvil/tablet.

### Android
- Huella dactilar vía `local_auth` disponible, no usada en fichaje.
- `geolocator` funciona correctamente.
- Sin diferencias funcionales respecto a iOS en este módulo.

### Windows (Desktop)
- `local_auth` **no tiene soporte en Windows** (`BiometriaService` usa `isDeviceSupported()` que devuelve `false` en escritorio). No hay fallback específico para fichaje desde PC.
- `geolocator` en Windows puede devolver errores en máquinas sin receptor GPS. El módulo no captura geolocalización, por lo que esto no genera un crash, pero cuando se implemente la geolocalización habrá que añadir un guard para desktop.
- La exportación CSV usa `Printing.sharePdf()` que en Windows abre el sistema de impresión. La exportación de CSV como archivo no usa la API nativa del sistema operativo (no hay `FileSaver`), lo que puede generar confusión. Sin embargo, `share_plus` y `printing` tienen soporte básico en Windows.
- El kiosk PIN funciona en Windows sin cambios.

---

## Cumplimiento legal (RDL 8/2019, art. 34.9 ET)

### Art. 34.9 ET — Obligaciones de registro

| Requisito | Estado | Observación |
|---|---|---|
| Registro diario de jornada por trabajador | **Cumple** | Un documento Firestore por jornada con `entrada` y `salida` vía `serverTimestamp`. |
| Fecha y hora de inicio y fin de jornada | **Cumple** | `entrada` y `salida` son `FieldValue.serverTimestamp()` (campos raíz). |
| Organización y documentación (accessible al trabajador y representantes) | **Parcial** | El empleado puede ver su historial en la app. No existe panel de representantes sindicales ni exportación directa para el comité de empresa. |
| Conservación durante 4 años | **No garantizado** | La UI menciona 4 años pero no existe ningún mecanismo técnico de retención garantizada (TTL, backup periódico, archivado). Firestore no borra datos por defecto, pero tampoco garantiza la conservación si la cuenta se cierra o los datos se eliminan manualmente. |
| Entrega de copia al trabajador | **Parcial** | El empleado puede ver su historial en la app y el admin puede exportar CSV. No existe un mecanismo de "entrega firmada" o notificación periódica de resumen al trabajador. |

### Inmutabilidad de registros

El diseño es correcto: las correcciones crean un nuevo documento (`es_correccion: true`, `correccion_de: id_original`) y el original nunca se modifica. La subcollección `audit_log` registra cada corrección con motivo y UID del corrector. Sin embargo:

1. La regla de Firestore para `update` del empleado sobre su propio fichaje (`hasOnly(['salida', 'pausas'])`) no impide que se sobrescriba una salida ya registrada.
2. La subcollección `audit_log` no tiene reglas propias, lo que compromete la trazabilidad.

### Identificación del trabajador

El sistema usa PIN de 4 dígitos (kiosk) o Firebase Auth UID (app). El PIN es conocido por el admin y podría suplantarse. No existe confirmación biométrica en el punto de fichaje. Esto puede no satisfacer la exigencia de "garantías de no manipulación" que algunos criterios de la Inspección de Trabajo consideran necesarios.

---

## Deuda técnica

1. **PIN en texto plano** — deuda de seguridad más grave. Migrar a hash SHA-256 con salt (mínimo) o bcrypt en Cloud Function.
2. **Hash SHA-256 cliente-only** — el hash se genera con `DateTime.now()` antes de que Firestore asigne el serverTimestamp. Mover la generación de la firma a una Cloud Function `onDocumentCreate` que tenga acceso al serverTimestamp real.
3. **Ausencia de geolocalización en el modelo** — el campo está en el diseño de tabla de la UI pero no en el modelo ni en el service. Implica trabajo adicional cuando se quiera cumplir la recomendación de fichar con ubicación.
4. **`local_auth` declarada pero sin uso en fichaje** — el paquete suma ~2MB a la build y genera prompts de permisos que el usuario no entiende por qué se solicitan en el contexto de fichaje.
5. **Carpeta `lib/features/fichaje/` legacy** — contiene código vivo (`PantallaFichaje`, `MisHorasMesSection`) que depende del módulo activo. Debería unificarse en `lib/features/fichajes/` para evitar divergencias.
6. **Ausencia de retención garantizada** — necesario un Cloud Scheduler o política de backup para garantizar los 4 años del RDL 8/2019.
7. **Regla Firestore `audit_log` ausente** — añadir regla de solo lectura para admin/propietario y solo escritura para Cloud Functions.
8. **Exportación CSV vía `Printing.sharePdf()`** — el CSV se codifica como Uint8List y se pasa a la API de impresión, no a un sistema de descarga de archivos. En Windows esto abre el diálogo de impresión en lugar de guardar el archivo.

---

## Lista priorizada de acciones

| Prioridad | Acción | Esfuerzo |
|---|---|---|
| P1 — Crítico | Hashear PIN con SHA-256+salt (o bcrypt) antes de almacenar en Firestore. Actualizar `verificarPIN` para comparar el hash, nunca el texto plano. | M |
| P1 — Crítico | Añadir regla Firestore para `fichajes/{id}/audit_log/{entradaId}`: lectura solo para admin/propietario, escritura solo denegada para cliente (solo Cloud Functions o backend). | S |
| P2 — Alto | Crear Cloud Function `onDocumentCreate` para `fichajes` que recalcule `firma_integridad` con el serverTimestamp real y la almacene de vuelta. Marcar el campo con `firma_verificada_servidor: true`. | M |
| P2 — Alto | Crear Cloud Function `onDocumentUpdate` para pausas: cuando se detecta un cambio en el array `pausas`, registrar la hora del servidor en un campo de auditoría separado. | M |
| P2 — Alto | Bloquear en la regla Firestore la sobreescritura de `salida` cuando ya tiene valor: `resource.data.get('salida', null) == null`. | S |
| P3 — Medio | Implementar geolocalización opcional en `ficharEntrada` y `ficharSalida`: capturar lat/lon con guard para Windows/desktop, almacenar en campos `lat_entrada`, `lon_entrada`, `lat_salida`, `lon_salida`. | M |
| P3 — Medio | Añadir confirmación biométrica en el momento del fichaje en la `PantallaFichaje` (app personal) vía `BiometriaService.autenticar()`. En Windows, saltarse el paso o pedir contraseña. | M |
| P3 — Medio | Configurar Cloud Scheduler que ejecute cada mes una Cloud Function de backup de fichajes a Google Cloud Storage para garantizar retención de 4 años independientemente del estado de la cuenta Firestore. | M |
| P4 — Bajo | Unificar `lib/features/fichaje/` (legacy) en `lib/features/fichajes/` moviendo `PantallaFichaje` y `MisHorasMesSection`. Eliminar la carpeta legacy. | S |
| P4 — Bajo | Cambiar exportación CSV en `ResumenMensualEmpleadosScreen._exportar()` para usar `FileSaver`/`path_provider` en desktop y `share_plus` en móvil, en lugar de `Printing.sharePdf()`. | S |
| P5 — Cosmético | Añadir paginación en `_fichajesTable` (actualmente `take(10)`) y `_fichajesListMobile` (`take(12)`) para que el admin vea todos los fichajes del día. | S |

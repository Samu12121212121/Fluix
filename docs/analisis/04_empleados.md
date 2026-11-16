# 04 — Empleados (Roles, Nóminas, RGPD)

> Análisis en modo solo lectura. Fecha: 2026-10-26.  
> Alcance: módulo Empleados, Nóminas, Finiquitos, Convenios, RGPD.

---

## Estado actual

### Alta de empleados
El módulo soporta tres rutas de alta distintas, todas desde `modulo_empleados_screen.dart`:

1. **"Nuevo empleado" (formulario directo)** — `formulario_empleado_form.dart`. Crea la cuenta Firebase Auth usando una `FirebaseApp` temporal para no cerrar sesión del admin, genera una contraseña de 10 caracteres (pool seguro, `Random.secure()`), crea el documento en `/usuarios/{uid}` y envía un email de reset de contraseña. La contraseña temporal se muestra en pantalla al admin. Opcionalmente el empleado puede ser creado como "solo ficha" (sin cuenta Auth, `es_solo_ficha: true`).

2. **"Invitar empleado" (modal)** — mismo flujo inline en el `_ModuloEmpleadosScreen`, sin pasar por la Cloud Function `crearEmpleadoConCredenciales`. Los dos caminos coexisten y hacen lo mismo, lo que supone duplicidad de lógica.

3. **Cloud Function `crearEmpleadoConCredenciales`** — `functions/src/crearEmpleado.ts`. Usa Firebase Admin SDK, garantiza atomicidad server-side y envía email de bienvenida con plantilla HTML via Resend. Es el camino correcto para producción, pero la app Flutter no lo llama: crea la cuenta directamente desde el cliente.

### Baja de empleados
`BajaEmpleadoService.procesarBaja()` ejecuta una secuencia de batch writes Firestore:
- Marca `activo: false`, `estado: 'baja'`, `acceso_bloqueado: true`, elimina el token FCM.
- Congela el saldo de vacaciones (campo `congelado: true`).
- Cancela solicitudes de vacaciones pendientes.
- Reasigna tareas activas al propietario.
- Vincula el finiquito generado.
- El historial de fichajes, nóminas y documentos **no se elimina** — se conserva íntegramente porque los registros están en subcolecciones (`/fichajes/`, `/nominas/`, `/documentos/`) con su propio ciclo de vida. La baja es un soft-delete completo.

La reversión (`revertirBaja`) restaura el acceso y limpia los campos de baja pero no descongela vacaciones automáticamente — puede deixar saldos incoherentes.

### Portal del empleado
`PortalEmpleadoScreen` tiene un guard de seguridad client-side: si `!modoAdmin && currentUid != _uid`, muestra pantalla de acceso restringido. Sin embargo este guard es solo visual: las reglas Firestore son la barrera real.

---

## Riesgos

| Nivel | Descripción | Fichero:Línea |
|-------|-------------|---------------|
| CRÍTICO | La creación de cuentas Firebase Auth se hace **desde el cliente** (`createUserWithEmailAndPassword` en app Flutter), sin pasar por la Cloud Function. Esto expone la lógica de creación a cualquier usuario admin y elimina el beneficio de la CF `crearEmpleadoConCredenciales`. | `formulario_empleado_form.dart:141` / `modulo_empleados_screen.dart:1652` |
| CRÍTICO | La regla Firestore `allow list: if isAuth() && !esAnonimo()` en `/usuarios/{userId}` permite a **cualquier usuario autenticado** listar todos los usuarios del sistema (sin filtro de empresa). Un empleado de empresa A puede listar empleados de empresa B con una query sin filtro. | `firestore.rules:175` |
| ALTO | La regla Storage para `/empresas/{empresaId}/empleados/{allPaths=**}` solo exige `request.auth != null` — cualquier usuario autenticado (de cualquier empresa) puede leer contratos, nóminas PDF y documentos personales de empleados. No hay verificación de empresa. | `storage.rules:105` |
| ALTO | `_eliminarEmpleado()` llama directamente a `_firestore.collection('usuarios').doc(id).delete()` sin soft-delete, sin borrar la cuenta Firebase Auth, y sin archivar documentos. El empleado queda con cuenta Auth huérfana y documentos en Storage sin referencia. | `modulo_empleados_screen.dart:1431` |
| ALTO | La contraseña temporal generada para nuevos empleados **se muestra en texto plano en pantalla** al admin y nunca se hashea. Si hay captura de pantalla o grabación en MDM corporativo queda expuesta. No existe política de forzar cambio al primer login (el campo `requiere_cambio_password` se escribe solo por la CF, no por el flujo cliente). | `modulo_empleados_screen.dart:1720-1722` / `formulario_empleado_form.dart:204` |
| ALTO | El CSV de exportación de empleados (nombres, correos, puestos, roles, estado, vacaciones) se guarda en `getApplicationDocumentsDirectory()` en iOS/Android — directorio no cifrado, accesible por backups de iTunes/Android sin cifrar. En Windows no existe ruta de descarga dedicada (misma función para todas las plataformas). | `modulo_empleados_screen.dart:1346-1355` |
| ALTO | La regla de vacaciones (`/vacaciones/{empresaId}/{document=**}`) solo permite lectura/escritura a `esAdminOPropietario`. Los empleados (staff) **no pueden ver su propio saldo de vacaciones** via Firestore directo — el portal las obtiene via stream pero staff sin ese módulo no puede acceder. Esto es intencionado pero contradice el portal que muestra saldos. Puede causar errores silenciosos. | `firestore.rules:388-394` |
| MEDIO | El token de invitación en `/invitaciones/{token}` no tiene expiración forzada por Firestore rules: el campo `expira` se escribe pero la regla de lectura no lo valida (`allow read: if esUsuarioReal()`). Un token expirado sigue siendo legible y usable si la validación solo existe en la app. | `firestore.rules:407-422` |
| MEDIO | En `revertirBaja`, el saldo de vacaciones congelado (`congelado: true`) **no se descongela** — el empleado rehabilitado puede ver su saldo como 0 días disponibles si la UI lee el campo congelado. | `baja_empleado_service.dart:197-237` |
| MEDIO | DNI, NSS, IBAN y dirección se almacenan en el documento principal `/usuarios/{uid}` (raíz de la colección, no subcolección). Estos datos están expuestos a cualquier regla que permita leer el documento del usuario, incluida la lectura pública de usuarios activos. | `firestore.rules:170-174` / `formulario_empleado_form.dart:99-106` |
| MEDIO | Las nóminas en PDF no tienen firma digital certificada. El campo `firma_url` en el modelo `Nomina` almacena una URL a Storage, pero no hay mecanismo de firma criptográfica (p.ej. sello eIDAS). En España el recibo de salario firmado electrónicamente requiere consentimiento explícito (art. 29.1 ET). | `nomina.dart:836-839` |
| BAJO | La Cloud Function `crearEmpleadoConCredenciales` devuelve `tempPassword` en el objeto de retorno (`return { exito: true, uid, tempPassword }`), exponiendo la contraseña temporal en los logs de Firebase Functions. | `crearEmpleado.ts:106` |
| BAJO | La pantalla `configurar_acceso_staff_screen.dart` configura módulos de forma **global para todo el rol staff**; no hay granularidad por empleado individual. El campo `modulos_permitidos` en el doc usuario existe pero el widget de configuración solo escribe a nivel empresa. | `configurar_acceso_staff_screen.dart:8` |

---

## Diferencias por plataforma (iOS / Android / Windows)

### iOS
- La creación de `FirebaseApp` temporal para crear cuentas funciona en iOS, pero puede fallar en escenarios de bajo nivel de memoria. La limpieza en `finally { tempApp?.delete() }` es correcta.
- `share_plus` funciona correctamente para compartir el CSV via AirDrop/Files.
- La ruta de documentos (`getApplicationDocumentsDirectory`) en iOS está dentro del sandbox de la app — protegida pero incluida en backups de iCloud/iTunes.

### Android
- El CSV exportado a `getApplicationDocumentsDirectory` en Android está en almacenamiento interno — no expuesto por defecto, pero accesible si el dispositivo tiene root.
- La biometría para fichar no está implementada (solo portal web con botón).

### Windows
- La generación y descarga de CSV usa la misma ruta `getApplicationDocumentsDirectory` independientemente de la plataforma, resultando en `C:\Users\{user}\Documents\empleados_export.csv` sin diálogo de selección de carpeta. En Windows debería usarse `getDownloadsDirectory` o un `FilePicker`.
- La generación de PDFs de nóminas puede comportarse distinto en Windows si usa `pdf` package de dart (no hay `dart:io` issues) pero la firma digital con imagen requiere `canvas` disponible en Windows Desktop — testeado en las correcciones de `Fase 1`.
- El módulo de fichaje del portal del empleado llama `FichajeService().ficharEntrada()` con `dispositivoId: 'portal_empleado'` — funciona en Windows pero sin validación de geolocalización (Windows Desktop no soporta `geolocator` fácilmente).
- `share_plus` en Windows no lanza el diálogo del sistema para compartir ficheros — la función `_compartirCSV` puede fallar silenciosamente o abrir el explorador en algunos entornos.

---

## Cumplimiento legal (RGPD, ET, protección datos laborales)

### Datos personales almacenados en `/usuarios/{uid}`
El documento principal del empleado puede contener: nombre, correo, teléfono, dirección, DNI/NIE, NSS, IBAN, estado civil, número de hijos, porcentaje de discapacidad, fecha de nacimiento, otras rentas, situación familiar numerosa. Estos datos son categoría especial (discapacidad, estado de salud en baja IT) y datos bancarios.

### Análisis RGPD

| Aspecto | Estado |
|---------|--------|
| **Base legal** | No documentada en código. La relación contractual (art. 6.1.b RGPD) y obligación legal (6.1.c) cubren nóminas y cotizaciones. Los datos de discapacidad/salud requieren base explícita del art. 9.2.b RGPD (ejecución contrato trabajo) y deben figurar en el contrato o política de privacidad. |
| **Minimización de datos** | DNI, NSS, IBAN, estado civil, hijos y discapacidad se almacenan en el doc principal del usuario, visible a admins de la empresa. No hay separación por sensibilidad (no existe subcolección `datos_sensibles`). |
| **Derecho de supresión** | No hay mecanismo de supresión RGPD implementado. `_eliminarEmpleado()` borra el doc Firestore pero no: la cuenta Auth, los documentos en Storage, las nóminas, los fichajes ni los datos en colecciones derivadas (vacaciones, finiquitos). Art. 17 RGPD exige supresión real o anonimización. |
| **Portabilidad** | El CSV exportado cubre datos básicos pero no incluye nóminas, historial de fichajes ni documentos. No hay mecanismo de exportación completa (art. 20 RGPD). |
| **Consentimiento para datos de salud** | Los campos `bajas_laborales`, `porcentaje_discapacidad` se recogen sin registro de consentimiento en el sistema. Art. 9.2.b RGPD requiere que el tratamiento sea necesario para obligaciones del Derecho laboral y esté autorizado por normativa. |
| **Retención** | No hay política de retención implementada. Los datos de empleados dados de baja permanecen indefinidamente. El ET exige conservar nóminas 4 años; la LGSS exige 5 años para cotizaciones; el art. 17 RGPD exige supresión tras fin del período. |
| **Logs de acceso** | La colección `/auditoria/{empresaId}/accesos/` existe pero no se escribe automáticamente cuando se accede a datos de nóminas o documentos personales. |
| **Transferencia internacional** | Firebase/Firestore usa servidores EU (`europe-west1`). Cumple adecuadamente si no hay otros procesadores. |

### ET (Estatuto de los Trabajadores)
- Art. 29.1 ET: el recibo de salario debe entregarse al trabajador. La app genera PDFs pero no tiene mecanismo de notificación de entrega al empleado (solo el portal permite ver nóminas).
- Art. 35.5 ET: las horas extra deben documentarse. El modelo `Nomina` tiene campos `horasExtra`, `tipoHoraExtra` y cotizaciones diferenciadas. Correcto en modelo, pendiente validar UI de entrada.
- Los finiquitos incluyen referencias correctas a arts. 49-56 ET por causa de baja.

---

## Deuda técnica

1. **Duplicidad del flujo de invitación**: dos implementaciones (Flutter directo + Cloud Function `crearEmpleadoConCredenciales`) que hacen lo mismo. Solo una debería existir; la CF es la correcta.

2. **Modelo `Usuario` vs campos extra en Firestore**: el modelo Dart `usuario.dart` no tiene campos `dni`, `nss`, `iban`, `direccion`, `discapacidad`, etc. Estos se manejan como `Map<String,dynamic>` sin tipado. Discrepancia entre modelo y persistencia.

3. **Regla `allow list` en `/usuarios`**: la regla `allow list: if isAuth() && !esAnonimo()` es demasiado permisiva. Debe restringirse a empresa propia.

4. **Storage rules sin verificación de empresa**: todos los archivos de empleados (`/empresas/{empresaId}/empleados/`) solo requieren `request.auth != null`. No hay verificación de pertenencia a la empresa.

5. **Vacaciones solo accesibles a admin**: el stream de saldos del portal del empleado usa una query que las reglas Firestore bloquean para staff. El portal funciona solo si el admin tiene el módulo activo, pero los empleados staff no pueden leer sus propios saldos directamente.

6. **`configurar_modulos_empleado_screen.dart`** (no analizado por no existir en repo — probable archivo pendiente de implementar): la granularidad por empleado individual está en el modelo de datos (`permisos: []`) pero la pantalla de configuración solo escribe a nivel empresa.

7. **Ausencia de validación del formato DNI/NSS/IBAN en el formulario**: los campos se guardan como texto libre sin regex de validación. DNI incorrecto puede causar problemas en modelos 111/190 AEAT.

8. **`regularizacion_irpf_service.dart`** calcula correctamente la regularización de diciembre (arts. 86-87 RIRPF) pero el cálculo de la base de Navarra y País Vasco usa las tarifas del régimen foral como combinadas — habría que validar que son las correctas para 2026 con las fuentes oficiales.

---

## Lista priorizada de acciones

| Prioridad | Acción | Esfuerzo |
|-----------|--------|----------|
| P1 | Corregir regla Firestore `/usuarios` `allow list` — añadir filtro `getUserData().empresa_id == resource.data.empresa_id`. | S |
| P1 | Migrar creación de empleados al flujo exclusivo via Cloud Function `crearEmpleadoConCredenciales` y eliminar el flujo Flutter-directo. Eliminar exposición de `tempPassword` en el return de la CF. | M |
| P1 | Implementar supresión RGPD (art. 17): función que anonimiza el doc usuario (elimina DNI/NSS/IBAN/nombre real), revoca Auth y elimina archivos en Storage al tramitar una solicitud de supresión. | L |
| P1 | Restringir reglas Storage para `/empresas/{empresaId}/empleados/` — añadir verificación de empresa (custom claim o path matching). | M |
| P2 | Mover datos sensibles (DNI, NSS, IBAN, discapacidad, estado civil, datos familiares) a una subcolección `datos_laborales/{uid}` con reglas propias y acceso solo para admin/propietario. Nunca deben estar en el doc principal del usuario. | L |
| P2 | Implementar política de retención automática: Cloud Function que, transcurridos N años tras baja del empleado, anonimiza datos personales manteniendo solo los legalmente requeridos (cotizaciones 5 años, nóminas 4 años). | L |
| P2 | Corregir `revertirBaja` para descongelar el saldo de vacaciones y recalcularlo. | S |
| P2 | Añadir validación de formato (regex) para DNI/NIE, NSS e IBAN en `formulario_empleado_form.dart` y `formulario_datos_nomina_form.dart`. | S |
| P3 | Unificar CSV export en Windows para usar `getDownloadsDirectory` o `FilePicker.saveFile`. | S |
| P3 | Añadir granularidad de módulos por empleado individual en `ConfigurarAccesoStaffScreen` o crear `ConfigurarModulosEmpleadoScreen`. | M |
| P3 | Implementar expiración forzada del token de invitación en las reglas Firestore (verificar campo `expira > request.time`). | S |
| P3 | Documentar la base legal en el código (comentario o constante) para cada categoría de dato personal: nóminas → art. 6.1.c RGPD + ET, datos salud → art. 9.2.b RGPD + LOPDGDD. | S |
| P3 | Añadir escritura de auditoría automática cuando un admin accede a datos de nóminas o documentos personales de empleados. | M |

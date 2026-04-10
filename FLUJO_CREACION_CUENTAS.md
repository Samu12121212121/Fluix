# FLUJO DE CREACIÓN DE CUENTAS — Fluix CRM

> Última actualización: Abril 2026

---

## SISTEMA DE ROLES

| Rol | Uso | Quién lo tiene |
|-----|-----|---------------|
| `propietario` | **Exclusivo** de la empresa FluixTech (plataforma) | Solo el dueño de la plataforma (Samu) — `empresaPropietariaId: ztZblwm1w71wNQtzHV7S` |
| `admin` | Dueño de empresa cliente | Cualquier usuario que registra una empresa nueva |
| `staff` | Empleado invitado | Usuarios que se registran mediante invitación del admin |

> **IMPORTANTE:** Un usuario nunca puede auto-registrarse como `propietario`. 
> Este rol se asigna solo a la empresa FluixTech vía `AdminInitializer` o manualmente en Firestore.

---

## FLUJO 1: REGISTRO DE NUEVA EMPRESA (email + contraseña)

**Pantalla:** `PantallaRegistro` → `FormularioRegistro`  
**Archivo:** `lib/features/registro/widgets/formulario_registro_simple.dart`

### Paso a paso:

1. El usuario accede desde el botón "Registrar Nueva Empresa" en la pantalla de login
2. Rellena un formulario en 2 pasos:
   - **Paso 1:** Datos de empresa (nombre, correo, teléfono, dirección)
   - **Paso 2:** Datos del propietario (nombre, correo personal, teléfono, contraseña)
3. Al confirmar:
   - Se crea el usuario en **Firebase Auth** (`createUserWithEmailAndPassword`)
   - Se crea el documento de empresa en **Firestore:** `empresas/{empresaId}`
     ```
     {
       nombre, correo, telefono, direccion, descripcion,
       fecha_creacion: Timestamp
     }
     ```
   - Se crea el documento de usuario en **Firestore:** `usuarios/{uid}`
     ```
     {
       nombre, correo, telefono,
       rol: "admin",          ← SIEMPRE admin (no propietario)
       empresa_id: empresaId,
       activo: true,
       permisos: [],
       fecha_creacion, token_dispositivo
     }
     ```
   - Se inicializan subcolecciones:
     - `empresas/{id}/configuracion/modulos` — módulos por defecto
     - `empresas/{id}/suscripcion/actual` — 30 días de prueba
     - `empresas/{id}/contadores/facturas` — contadores de facturación
     - `empresas/{id}/estadisticas/resumen` — estadísticas vacías
4. Se carga la sesión (`PermisosService().cargarSesion()`)
5. Se navega directamente al **Dashboard**

---

## FLUJO 2: REGISTRO CON GOOGLE / APPLE SIGN-IN

**Pantalla:** `PantallaLogin` → `PantallaRegistrarEmpresaSocial`  
**Archivos:**
- `lib/features/autenticacion/pantallas/pantalla_login.dart`
- `lib/features/registro/pantallas/pantalla_registrar_empresa_social.dart`

### Paso a paso:

1. El usuario pulsa "Continuar con Google" o "Continuar con Apple"
2. Se autentica con el proveedor social (Google/Apple)
3. Si **NO existe** documento en `usuarios/{uid}`:
   - Se crea con `rol: "admin"` y `empresa_id: ""` (vacío)
   - Se redirige a `PantallaRegistrarEmpresaSocial` para completar datos de empresa
4. Si **YA existe** y `empresa_id` está vacío → se redirige a completar empresa
5. Si **YA existe** y `empresa_id` es válido → se navega al Dashboard

### En PantallaRegistrarEmpresaSocial:
1. Recoge: nombre empresa, tipo de negocio, teléfono, dirección
2. Crea `empresas/{empresaId}` con `propietario_id: uid`
3. Inicializa contadores de facturación
4. Actualiza `usuarios/{uid}` con el `empresa_id`
5. Navega al **Onboarding** → luego al Dashboard

---

## FLUJO 3: REGISTRO DE EMPLEADO POR INVITACIÓN

**Pantalla:** `PantallaRegistroInvitacion`  
**Archivo:** `lib/features/registro/pantallas/pantalla_registro_invitacion.dart`  
**Servicio:** `InvitacionesService`

### Paso a paso:

1. El admin/propietario invita desde el módulo de empleados
2. Se envía un email con un deep link: `fluixcrm://invite?token=XXX`
3. Al abrir el link:
   - Se valida el token (existencia, expiración 72h, no usado)
   - Se muestra formulario: nombre + contraseña
4. Al confirmar:
   - Se crea usuario en **Firebase Auth**
   - Se crea `usuarios/{uid}` con:
     ```
     {
       rol: "staff" (o "admin" según invitación),
       empresa_id: empresaId_del_invitador,
       modulos_permitidos: [según configuración del admin]
     }
     ```
   - Se marca la invitación como usada
5. Se navega al **Dashboard** (solo verá los módulos asignados)

### Restricciones del empleado invitado:
- **NO** puede crear empresa propia
- **NO** ve el módulo `propietario`
- Solo ve los módulos que el admin le haya asignado
- Si no hay módulos personalizados, ve los del rol por defecto

---

## FLUJO 4: CUENTA PROPIETARIO (solo FluixTech)

**Archivo:** `lib/core/utils/admin_initializer.dart`  
**Constante:** `ConstantesApp.empresaPropietariaId = 'ztZblwm1w71wNQtzHV7S'`

### Protecciones automáticas:
1. **Protección 1 (`PermisosService`):** Si `empresa_id == empresaPropietariaId` y rol != `propietario` → se fuerza a `propietario`
2. **Protección 2:** Si no hay ningún admin/propietario en la empresa → se promueve automáticamente
3. **Protección 3:** Si el correo del usuario coincide con el correo de la empresa → se promueve

> Para empresas normales, las protecciones 2 y 3 promueven a `admin` (no `propietario`)

---

## MÓDULOS POR ROL

| Módulo | propietario | admin | staff |
|--------|:-----------:|:-----:|:-----:|
| propietario (plataforma) | ✅ | ❌ | ❌ |
| dashboard | ✅ | ✅ | ❌ |
| reservas | ✅ | ✅ | ✅ |
| citas | ✅ | ✅ | ✅ |
| clientes | ✅ | ✅ | ✅ |
| valoraciones | ✅ | ✅ | ✅ |
| estadísticas | ✅ | ✅ | ❌ |
| servicios | ✅ | ✅ | ❌ |
| pedidos | ✅ | ✅ | ❌ |
| whatsapp | ✅ | ✅ | ❌ |
| tareas | ✅ | ✅ | ❌ |
| empleados | ✅ | ✅ | ❌ |
| facturación | ✅ | ✅ | ❌ |
| nóminas | ✅ | ✅ | ❌ |
| vacaciones | ✅ | ✅ | ❌ |
| web | ✅ | ✅ | ❌ |

---

## PERMISOS POR ROL

| Permiso | propietario | admin | staff |
|---------|:-----------:|:-----:|:-----:|
| Gestionar empleados | ✅ | ✅ | ❌ |
| Configurar dashboard | ✅ | ✅ | ❌ |
| Ver finanzas | ✅ | ✅ | ❌ |
| Ver resumen fiscal | ✅ | ✅ | ❌ |
| Gestionar servicios | ✅ | ✅ | ❌ |
| Gestionar clientes | ✅ | ✅ | ❌ |
| Gestionar reservas/citas | ✅ | ✅ | ❌ |
| Gestionar pedidos | ✅ | ✅ | ❌ |
| Crear facturas | ✅ | ✅ | ❌ |
| Editar web | ✅ | ✅ | ❌ |
| Gestionar suscripción | ✅ | ✅ | ❌ |
| Ver valoraciones | ✅ | ✅ | ✅ |
| Ver reservas | ✅ | ✅ | ✅ |
| Cambiar estado reserva | ✅ | ✅ | ✅ |

---

## BIOMETRÍA (Face ID / Huella dactilar)

**Archivo:** `lib/services/auth/biometria_service.dart`

### Flujo:
1. Primer login exitoso con email/contraseña
2. Se comprueba si el dispositivo soporta biometría
3. Se muestra diálogo **bloqueante** preguntando si activar
4. Si acepta → se guarda en `flutter_secure_storage`:
   - `biometria_activa: true`
   - `biometria_uid: {uid}`
   - `biometria_email: {email}`
5. Siguiente apertura de app → se muestra `PantallaLoginBiometrico`
6. Si falla 3 veces → login normal

### Requisitos iOS:
- `NSFaceIDUsageDescription` configurado en `ios/Runner/Info.plist` ✅
- `REVERSED_CLIENT_ID` en `CFBundleURLSchemes` para Google Sign-In ✅

---

## DIAGRAMA DE FLUJO SIMPLIFICADO

```
App abierta
    │
    ├── ¿Biometría activa? ─── Sí ──→ PantallaLoginBiometrico
    │                                       │
    │                                   ¿Éxito? ─ Sí ──→ Dashboard
    │                                       │
    │                                      No ──→ Login normal
    │
    └── No ──→ PantallaLogin
                    │
                    ├── Login email/pass ──→ ¿2FA? ──→ Dashboard
                    │                            │
                    │                        Ofrecer biometría
                    │
                    ├── Google/Apple ──→ ¿Usuario nuevo?
                    │                       │       │
                    │                      Sí      No ──→ Dashboard
                    │                       │
                    │                  ¿empresa_id vacío?
                    │                       │
                    │                      Sí ──→ RegistrarEmpresaSocial ──→ Onboarding
                    │
                    └── Registrar Empresa ──→ FormularioRegistro ──→ Dashboard
```

---

## ARCHIVOS RELEVANTES

| Archivo | Descripción |
|---------|-------------|
| `lib/features/autenticacion/pantallas/pantalla_login.dart` | Login (email, Google, Apple) |
| `lib/features/registro/widgets/formulario_registro_simple.dart` | Registro empresa (email) |
| `lib/features/registro/pantallas/pantalla_registrar_empresa_social.dart` | Registro empresa (social) |
| `lib/features/registro/pantallas/pantalla_registro_invitacion.dart` | Registro empleado invitado |
| `lib/core/utils/permisos_service.dart` | Roles, permisos, sesión |
| `lib/core/constantes/constantes_app.dart` | IDs de empresa plataforma |
| `lib/core/utils/admin_initializer.dart` | Inicialización cuenta Fluix |
| `lib/services/auth/biometria_service.dart` | Face ID / Huella dactilar |
| `lib/services/auth/invitaciones_service.dart` | Sistema de invitaciones |
| `lib/features/dashboard/pantallas/pantalla_dashboard.dart` | Dashboard principal |

---

## CUENTA DEMO

**Email:** `demoFluix2026@gmail.com`  
**Contraseña:** `FlFluix26`

- Si el usuario autenticado es la cuenta demo, aparece un **FloatingActionButton** morado con `Icons.auto_fix_high` en la esquina inferior derecha del Dashboard.
- Al pulsarlo, genera datos de prueba realistas (clientes, reservas, facturas, empleados, nóminas, tareas, pedidos, datos fiscales).
- Invisible para cualquier otro usuario.
- Servicio: `DemoCuentaService` en `lib/services/demo_cuenta_service.dart`



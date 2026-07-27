# Módulo: Autenticación

## Qué hace

Gestiona el ciclo completo de login, logout, registro y recuperación de contraseña. Es la base de toda la app — ningún otro módulo es accesible sin pasar por aquí.

---

## Archivos principales

| Archivo | Rol |
|---------|-----|
| `features/autenticacion/pantallas/pantalla_login_fixed.dart` | Pantalla principal de login |
| `features/autenticacion/pantallas/pantalla_login_biometrico.dart` | Login con FaceID/huella |
| `features/autenticacion/pantallas/pantalla_verificacion_2fa.dart` | Validación de OTP (2FA) |
| `features/autenticacion/widgets/formulario_login.dart` | Formulario email/password |
| `features/autenticacion/widgets/cabecera_login.dart` | Header visual de la pantalla |
| `features/registro/pantallas/pantalla_registro.dart` | Registro de nuevas empresas |
| `data/datasources/autenticacion_datasource.dart` | Acceso directo a Firebase Auth |
| `data/repositorios/repositorio_autenticacion_impl.dart` | Implementación del repositorio |
| `domain/repositorios/repositorio_autenticacion.dart` | Interfaz/contrato |
| `domain/casos_uso/autenticacion_casos_uso.dart` | Casos de uso (login, logout, reset) |
| `services/auth/sesion_service.dart` | Control de sesión activa |
| `services/auth/token_refresh_service.dart` | Refresh automático de token |
| `services/auth/dos_factores_service.dart` | Lógica 2FA |
| `services/auth/biometria_service.dart` | FaceID/huella dactilar |
| `services/auth/fuerza_bruta_service.dart` | Bloqueo anti-brute force |
| `services/auth/auditoria_service.dart` | Log de accesos |
| `services/apple_auth_service.dart` | Apple Sign-In |

---

## Cómo funciona internamente

### Flujo de login normal
1. El usuario introduce email + contraseña en `formulario_login.dart`
2. Se llama al caso de uso `loginConEmail()` en `autenticacion_casos_uso.dart`
3. El caso de uso llama al repositorio → datasource → `FirebaseAuth.signInWithEmailAndPassword()`
4. Si hay 2FA activo, se redirige a `pantalla_verificacion_2fa.dart` para validar el OTP
5. Si es biométrico, `biometria_service.dart` valida con el sensor del dispositivo y el token guardado localmente
6. Tras login exitoso, `sesion_service.dart` inicia el tracking de inactividad

### Anti-fuerza bruta
- `fuerza_bruta_service.dart` cuenta intentos fallidos por IP/email
- Tras N intentos (configurable), bloquea temporalmente el acceso
- Se sincroniza con la Cloud Function `verificarLoginIntento`

### Refresh de token
- `token_refresh_service.dart` corre en background y renueva el token de Firebase Auth antes de que expire (cada ~55 minutos)

### Auditoría
- Cada login/logout queda registrado en `usuarios/{uid}/auditoria` con timestamp, IP, dispositivo

---

## Colecciones Firestore usadas

| Colección | Uso |
|-----------|-----|
| `usuarios/{uid}` | Perfil del usuario (rol, empresa_id, nombre) |
| `usuarios/{uid}/auditoria` | Historial de accesos |
| `usuarios/{uid}/renovaciones` | Alertas de renovación de contrato |

---

## Cloud Functions relacionadas

| Función | Cuándo se llama |
|---------|----------------|
| `verificarLoginIntento` | En cada intento de login — valida anti-brute force |
| `sendResetPasswordEmail` | Al solicitar recuperación de contraseña |

---

## Métodos de autenticación soportados

- **Email/Password** — estándar Firebase Auth
- **Google Sign-In** — OAuth2 via Google
- **Apple Sign-In** — OAuth2 via Apple (obligatorio iOS)
- **Biometría** — FaceID/TouchID, usa token guardado localmente
- **2FA (OTP)** — código de verificación enviado por email/SMS

---

## Conexión con otros módulos

- **Registro:** tras crear cuenta nueva en Firebase Auth, el flujo continúa en el módulo de registro para crear la empresa
- **Dashboard:** destino tras login exitoso
- **Onboarding:** se activa si `onboarding_completado = false` en la empresa
- **Suscripción:** verifica si la suscripción está activa justo después del login
- **Perfil:** gestión posterior de contraseña, biometría y 2FA

---

## Roles y acceso

El campo `rol` en `usuarios/{uid}` determina qué ve cada usuario tras hacer login:
- `propietario` / `admin` → Dashboard completo
- `staff` → Dashboard con módulos limitados según `modulos_permitidos`
- `clienteFinal` → App pública de explorar negocios
- `plataforma_admin` → Panel de administración de plataforma

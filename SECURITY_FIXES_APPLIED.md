# 🔒 CORRECCIONES DE SEGURIDAD — Fluix CRM
### Fecha: 2026-04-05 | Aplicadas por: GitHub Copilot

---

## RESUMEN DE CAMBIOS

### ✅ Archivos modificados (7):

| # | Archivo | Cambio |
|---|---------|--------|
| 1 | `firestore.rules` | **Reescrito completo** — 9 correcciones de seguridad |
| 2 | `functions/src/gmbTokens.ts` | Auth guards en 4 funciones + eliminar access_token de respuesta |
| 3 | `functions/src/index.ts` | Auth guards en 5 funciones + Stripe webhook hardened + crearEmpresaHTTP deshabilitada + export fuerzaBruta |
| 4 | `lib/services/auth/fuerza_bruta_service.dart` | Migrado de Firestore directo a Cloud Function HTTP |
| 5 | `lib/core/utils/admin_initializer.dart` | Credenciales restringidas a kDebugMode |
| 6 | `.gitignore` | Patrones adicionales (.env.local, *.jks) |
| 7 | `firebase.json` | Añadida referencia a storage.rules |

### ✅ Archivos nuevos (3):

| # | Archivo | Contenido |
|---|---------|-----------|
| 1 | `storage.rules` | Reglas completas para Firebase Storage |
| 2 | `functions/src/utils/authGuard.ts` | Helper centralizado de autenticación |
| 3 | `functions/src/auth/fuerzaBruta.ts` | Cloud Function anti-fuerza-bruta |

---

## VULNERABILIDADES CORREGIDAS

| # | Severidad | Corrección | Archivo |
|---|-----------|-----------|---------|
| 1 | 🔴 CRÍTICA | `allow read: if true` en empresa raíz → `perteneceAEmpresa` | firestore.rules |
| 2 | 🔴 CRÍTICA | `allow read: if true` en suscripción → `perteneceAEmpresa` | firestore.rules |
| 3 | 🔴 ALTA | `allow read: if true` en estadísticas → `perteneceAEmpresa` | firestore.rules |
| 4 | 🔴 CRÍTICA | Staff ve nóminas de todos (RGPD) → solo propias | firestore.rules |
| 5 | 🟡 ALTA | `allow create: if true` en valoraciones → validación anti-spam | firestore.rules |
| 6 | 🟡 ALTA | `allow create: if true` en pedidos → validación empresaId | firestore.rules |
| 7 | 🟡 MEDIA | login_intentos sin reglas → `allow: false` (solo Admin SDK) | firestore.rules |
| 8 | 🟡 MEDIA | notificaciones PERMISSION_DENIED → `perteneceAEmpresa` | firestore.rules |
| 9 | 🟡 MEDIA | embargos PERMISSION_DENIED → reglas correctas | firestore.rules |
| 10 | 🔴 CRÍTICA | Storage sin reglas → storage.rules completo | storage.rules |
| 11 | 🔴 CRÍTICA | Cloud Functions sin auth → authGuard centralizado | authGuard.ts |
| 12 | 🔴 CRÍTICA | Stripe webhook acepta sin firma → reject obligatorio | index.ts |
| 13 | 🔴 CRÍTICA | crearEmpresaHTTP sin auth → deshabilitada (410 Gone) | index.ts |
| 14 | 🔴 CRÍTICA | Contraseña hardcodeada en código fuente → solo kDebugMode | admin_initializer.dart |
| 15 | 🟡 ALTA | access_token devuelto al cliente → eliminado de respuesta | gmbTokens.ts |
| 16 | 🟡 ALTA | Anti-fuerza-bruta falla silenciosamente → Cloud Function | fuerzaBruta.ts |

---

## COMANDO DE DESPLIEGUE

```powershell
# Desde el directorio raíz del proyecto
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter

# Desplegar todo de una vez
firebase deploy --only firestore:rules,storage,functions

# O por separado para verificar paso a paso:
firebase deploy --only firestore:rules
firebase deploy --only storage
firebase deploy --only functions
```

## ⚠️ ACCIÓN MANUAL REQUERIDA

1. **Cambiar contraseña en Firebase Console**: La contraseña real de `samuel.corcho@fluixtech.com` estaba hardcodeada. Cámbiala en Firebase Console > Authentication > Usuarios.

2. **Verificar historial git**: Ejecuta:
   ```powershell
   git log --all --full-history -- credentials.json
   git log --all --full-history -- "lib/core/utils/admin_initializer.dart"
   ```
   Si `credentials.json` o la contraseña aparecen en el historial, limpia con:
   ```powershell
   # Instalar BFG: https://rtyley.github.io/bfg-repo-cleaner/
   java -jar bfg.jar --delete-files credentials.json
   java -jar bfg.jar --replace-text passwords.txt  # archivo con la contraseña antigua
   git reflog expire --expire=now --all && git gc --prune=now --aggressive
   git push --force
   ```

3. **Rotar la contraseña**: Como la contraseña `D3?papanata` estuvo en el código fuente, considérala comprometida. Cámbiala inmediatamente.


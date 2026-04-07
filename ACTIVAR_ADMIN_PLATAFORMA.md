# ══════════════════════════════════════════════════════════════════
# ACTIVAR ADMIN DE PLATAFORMA — FluxTech
# ══════════════════════════════════════════════════════════════════

## ✅ Método RÁPIDO (script automático)

Ejecuta esto en la terminal, desde la raíz del proyecto:

```powershell
node scripts/activar_admin_plataforma.js TU_EMAIL@aqui.com
```

Eso es todo. El script:
1. Busca tu cuenta en Firebase Auth por email
2. Pone `es_plataforma_admin = true` en Firestore
3. Te confirma el resultado

Luego cierra sesión en la app y vuelve a entrar → verás el tab **Cuentas** en Perfil.

---

## Método manual (Firebase Console)

1. Ve a https://console.firebase.google.com
2. **Firestore Database → usuarios → TU_UID**
3. Edita/crea el campo: `es_plataforma_admin` = **true** (boolean)

---

## Desplegar Cloud Functions (después de activar)

```powershell
cd functions
npm run build
firebase deploy --only functions
```

---

## Configurar webhook en tu web

Cuando alguien compra en tu web, envía un POST a:
```
https://europe-west1-TU_PROYECTO.cloudfunctions.net/webhookPagoWeb
```

**Headers:**
```
Content-Type: application/json
X-Fluix-Secret: EL_TOKEN_DE_TU_.ENV
```

**Body JSON:**
```json
{
  "email": "cliente@ejemplo.com",
  "planId": "basico",
  "nombreEmpresa": "Peluquería María",
  "importe": 300,
  "referenciaPago": "ORDER_12345",
  "crearCuentaAuto": true
}
```

| planId | Precio |
|--------|--------|
| `basico` | €300/año |
| `profesional` | €500/año |
| `premium` | €800/año |

Con `crearCuentaAuto: true` la cuenta se crea sola y el cliente recibe el email con sus credenciales. Con `false`, te llega la notificación push y la creas tú desde la app.

---

## Generar token secreto para el webhook

```powershell
# En PowerShell:
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 40 | % {[char]$_})
```

Pega el resultado en `functions/.env`:
```
FLUIX_WEBHOOK_SECRET=el_resultado_aqui
```

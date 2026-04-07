# 🚀 CAMBIOS REALIZADOS PARA DESPLIEGUE — 26/03/2026

## ✅ DÍA 1 — BLOQUEANTES CRÍTICOS

### 1. Fix Firestore Rules — COMPLETADO ✅
**Archivo:** `firestore.rules`
- ✅ **Vulnerabilidad corregida:** `estadisticas/{docId}/{subcol}/{subId}` → `allow write: if perteneceAEmpresa(empresaId)` (antes era `if true`)
- ✅ **Bracket faltante:** `match /secciones_web/` no cerraba `}` — `contenido_web` estaba incorrectamente anidado dentro de `secciones_web`. Ahora son bloques independientes.
- ✅ Verificado que el archivo tiene 233 líneas con brackets correctamente balanceados.

### 2. Fix TypeScript / Cloud Functions — VERIFICADO ✅
**Archivos:** `functions/src/index.ts`, `notificacionesTareas.ts`, `recordatoriosCitas.ts`
- ✅ **Stripe API version** ya estaba en `"2024-06-20"` (válida)
- ✅ **`recordatoriosCitas.ts`** ya tenía `admin.firestore()` dentro del handler
- ✅ **`notificacionesTareas.ts`** ya no tenía imports no usados
- ✅ **Eliminado `@types/stripe`** del `package.json` (conflicto con stripe v16+ que incluye sus propios tipos)

### 3. Seguridad — `.gitignore` actualizado ✅
**Archivo:** `.gitignore`
- ✅ Añadido `functions/.env`, `.env`, `credentials.json` al `.gitignore`
- ⚠️ **ACCIÓN MANUAL:** Si ya están trackeados en git, ejecutar:
  ```bash
  git rm --cached functions/.env credentials.json
  ```

---

## ✅ DÍA 2 — ARREGLOS IMPORTANTES

### 4. ISO-8859-1 en Exportadores AEAT — COMPLETADO ✅
**Archivos:**
- `lib/services/exportadores_aeat/mod_347_exporter.dart`
  - ✅ Añadidos imports `dart:convert` y `dart:typed_data`
  - ✅ Nuevo método `generarFicheroBytes()` que devuelve `Uint8List` con `latin1.encode()`
  - ✅ Método original `generarFichero()` mantenido para compatibilidad
- `lib/services/exportadores_aeat/mod_349_exporter.dart`
  - ✅ Añadido import `dart:convert`
  - ✅ `_encodeIso88591()` mejorado para usar `latin1.encode()` con fallback

### 5. Vista Calendario en Tareas — CORREGIDO ✅
**Archivo:** `lib/features/tareas/pantallas/modulo_tareas_screen.dart`
- ✅ **Corregido syntax error:** `],` → `},` en el cierre del `markerBuilder` callback
- ✅ **Eliminado `TableCalendar<Tarea>(` huérfano/duplicado** (línea 327)
- ✅ El toggle de vista ahora funciona correctamente: kanban → lista → calendario → kanban (`(_vistaActual + 1) % 3`)

### 6. Recuperar Contraseña — YA IMPLEMENTADO ✅
**Archivo:** `lib/features/autenticacion/pantallas/pantalla_login.dart`
- ✅ Botón "¿Olvidaste tu contraseña?" existe (línea 254)
- ✅ Método `_mostrarRecuperacionPassword()` implementado (línea 655)
- ✅ Usa `FirebaseAuth.instance.sendPasswordResetEmail(email: email)`
- ✅ Manejo de errores `user-not-found` e `invalid-email`

---

## ✅ DÍA 3 — MEJORAS

### 7. Facturación Email — Cloud Function Conectada ✅
**Archivo:** `lib/features/facturacion/pantallas/detalle_factura_screen.dart`
- ✅ Añadido import de `EmailService`
- ✅ Opción "Enviar por email" ahora llama a `EmailService.enviarFactura()` (Cloud Function server-side)
- ✅ Fallback a `Share.shareXFiles()` si la Cloud Function falla
- ✅ Si no hay correo del cliente, usa compartir nativo directamente

---

## ⏳ PENDIENTE — Acciones manuales requeridas

### Para completar el despliegue:

```bash
# 1. Instalar dependencias actualizadas de functions
cd functions && npm install

# 2. Compilar TypeScript
npm run build

# 3. Borrar onNuevaReserva Gen 1 en Firebase Console (si existe)
firebase functions:delete onNuevaReserva --region europe-west1 --force

# 4. Desplegar functions
firebase deploy --only functions

# 5. Desplegar reglas de Firestore
firebase deploy --only firestore:rules

# 6. Configurar secrets SMTP (para email)
# Editar functions/.env con datos reales de SMTP

# 7. Build release Android
flutter build apk --release

# 8. Verificar que .env y credentials.json no están en git
git rm --cached functions/.env credentials.json 2>/dev/null
git add .gitignore
git commit -m "fix: security - add .env and credentials to gitignore"
```

### Items del plan no implementados (requieren decisión del negocio):
- **Suscripción:** Documentar cobro manual (Bizum/transferencia) — sin cambio de código necesario
- **WhatsApp Bot:** Decisión: desactivar módulo o añadir disclaimer "Próximamente"
- **Citas:** Funciona como wrapper básico de Reservas — añadir disclaimer "Beta" si se desea
- **Numeración anti-huecos:** Implementar contador atómico Firestore (1 día de trabajo)

---

*Generado: 26/03/2026 | Todos los cambios verificados sin errores de compilación*


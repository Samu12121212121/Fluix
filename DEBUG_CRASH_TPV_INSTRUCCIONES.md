# 🔍 GUÍA COMPLETA: Debugging de Crash Silencioso en TPV Flutter Windows

**Última actualización:** 2026-05-26  
**Problema:** La aplicación se cierra silenciosamente al ejecutar el flujo de cobro desde el TPV, sin mostrar ningún error.

---

## ✅ **CAMBIOS IMPLEMENTADOS**

### 1️⃣ Sistema Global de Captura de Errores (main.dart)

Se ha añadido un sistema completo de captura y logging de errores que:

- ✅ **Captura errores de Flutter** (widgets, render) con `FlutterError.onError`
- ✅ **Captura errores de plataforma** (async, platform channels) con `PlatformDispatcher.instance.onError`
- ✅ **Captura errores async no manejados** con `runZonedGuarded`
- ✅ **Escribe logs a archivo** en disco antes del cierre: `fluixcrm_crash.log`
- ✅ **Imprime logs en consola** en tiempo real con timestamps

### 2️⃣ Logging Detallado en Flujo de Cobro (caja_rapida_screen.dart)

Se ha añadido logging exhaustivo paso a paso:

```
💰 [COBRO] Paso 1/6: Construyendo líneas de pedido...
📝 [COBRO] Paso 2/6: Creando pedido en Firestore...
🚚 [COBRO] Paso 3/6: Marcando como entregado...
💳 [COBRO] Paso 4/6: Marcando como pagado...
📄 [COBRO] Paso 5/6: Generando documento PDF...
🎟️ [COBRO] Paso 6/6: Generando ticket texto...
```

**→ Permite identificar exactamente en qué paso falla el cobro**

---

## 📋 **PASO 1: EJECUTAR EN MODO DEBUG DESDE CONSOLA**

### Opción A: Ejecutar y ver logs en tiempo real

```powershell
# Navegar a la carpeta del proyecto
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter

# Limpiar compilación previa
flutter clean

# Ejecutar en Windows con salida detallada
flutter run -d windows --verbose
```

**Qué observar:**
- ✅ Logs con prefijo `[COBRO]` durante el flujo de pago
- 🔴 Stack traces completos si hay excepciones
- ⚠️ Mensajes de error de Firebase, PDF, o platform channels

---

### Opción B: Ejecutar y guardar logs en archivo

```powershell
# Ejecutar y guardar TODO en un archivo de texto
flutter run -d windows --verbose > C:\Users\Samu\debug_tpv_log.txt 2>&1
```

**Después del crash, revisar:**
```powershell
# Abrir el archivo de log
notepad C:\Users\Samu\debug_tpv_log.txt

# Buscar líneas con "[COBRO]" para seguir el flujo
# Buscar líneas con "ERROR" o "EXCEPTION" para ver el crash
```

---

## 📂 **PASO 2: UBICACIÓN DEL LOG PERSISTENTE**

El sistema escribe automáticamente un archivo de log que **persiste incluso si la app cierra**:

### 📍 Ubicación del archivo:

```
%USERPROFILE%\Documents\fluixcrm_crash.log
```

**Ruta absoluta:**
```
C:\Users\Samu\Documents\fluixcrm_crash.log
```

### Abrir el archivo:

```powershell
# Abrir en notepad
notepad C:\Users\Samu\Documents\fluixcrm_crash.log

# O abrir carpeta
explorer C:\Users\Samu\Documents
```

### 🔍 Qué buscar en el log:

| Símbolo | Significado |
|---------|-------------|
| 🚀 | Inicio de aplicación |
| ⚙️ | Inicialización de Firebase |
| 💰 [COBRO] | Flujo de cobro activo |
| ✅ | Operación exitosa |
| ⚠️ | Warning/advertencia |
| 🔴 | **ERROR CRÍTICO** ← **BUSCA ESTO** |
| Stack: | **Stack trace completo** ← **BUSCA ESTO** |

---

## 🪟 **PASO 3: REVISAR EL VISOR DE EVENTOS DE WINDOWS**

Si la app cierra sin logs, puede ser un crash a nivel de sistema operativo.

### Abrir Event Viewer:

```powershell
# Método 1: Ejecutar desde PowerShell
eventvwr.msc

# Método 2: Buscar en inicio
# Escribe: "Visor de eventos" o "Event Viewer"
```

### Navegar a:

```
Windows Logs → Application
```

### Buscar entradas:

| Campo | Valor |
|-------|-------|
| **Source** | `Application Error` |
| **Faulting application name** | `planeag_flutter.exe` |
| **Fault module** | Indica qué DLL/módulo causó el crash |
| **Exception code** | `0xc0000005` (Access Violation) es el más común |

### Campos importantes:

```
Faulting application name: planeag_flutter.exe
Faulting module name: firebase_core_windows_plugin.dll   ← Indica origen
Exception code: 0xc0000005                                 ← Tipo de error
```

---

## 🧪 **PASO 4: PROBAR CON CONFIGURACIÓN SIMPLIFICADA**

### Test 1: Deshabilitar generación de PDF

Editar temporalmente `caja_rapida_screen.dart`:

```dart
// Comentar esta sección en _cobrar()
/*
pdfBytes = await _facturacionAuto.procesarCobro(
  empresaId: widget.empresaId,
  pedido: pedido,
);
*/
```

**Si el crash desaparece → El problema está en:**
- `tpv_document_renderer.dart`
- `facturacion_automatica_service.dart`
- Librería `pdf` o `printing`

---

### Test 2: Verificar plugins de Windows

```powershell
# Ver plugins instalados
flutter pub get
flutter pub deps
```

**Plugins que pueden causar crashes en Windows:**
- `blue_thermal_printer` → **Solo mobile, NO soporta Windows**
- `printing` → Requiere configuración especial en Windows
- `path_provider` → Verificar permisos de escritura

---

## 🚨 **ERRORES COMUNES Y CÓMO DETECTARLOS**

### 1. ❌ **Null Safety Violation**

**Síntomas:** Crash sin mensaje, o mensaje `Null check operator used on a null value`

**Cómo detectar:**
```dart
// Buscar en logs:
"🔴 PLATFORM ERROR:"
"Null check operator used on a null value"
```

**Causas comunes:**
- `pedido.metadata!.field` → usar `pedido.metadata?.field ?? default`
- `config!.campo` → verificar que config no sea null

---

### 2. ❌ **Platform Channel Error (Windows)**

**Síntomas:** Crash al llamar método nativo (impresión, almacenamiento)

**Cómo detectar:**
```dart
// Buscar en logs:
"🔴 PLATFORM ERROR:"
"MissingPluginException"
"PlatformException"
```

**Causas comunes:**
- Plugin no soporta Windows (`blue_thermal_printer`)
- Plugin no registrado en `windows/runner/flutter_window.cpp`

---

### 3. ❌ **Firebase WriteOperation Sin Await**

**Síntomas:** Crash async después de operación en Firestore

**Cómo detectar:**
```dart
// Buscar en logs:
"🔴 UNCAUGHT ASYNC ERROR:"
"FirebaseException"
```

**Revisar código:**
```dart
// ❌ MAL (sin await)
_svc.cambiarEstado(empresaId, pedidoId, estado);

// ✅ BIEN (con await)
await _svc.cambiarEstado(empresaId, pedidoId, estado);
```

---

### 4. ❌ **setState() After dispose()**

**Síntomas:** Crash al volver de diálogo o navegación

**Cómo detectar:**
```dart
// Buscar en logs:
"🔴 FLUTTER ERROR:"
"setState() called after dispose()"
```

**Verificar siempre:**
```dart
if (!mounted) return;
setState(() { /* ... */ });
```

---

### 5. ❌ **Desbordamiento de Memoria en PDF**

**Síntomas:** Crash silencioso al generar PDF grande

**Cómo detectar:**
```dart
// Buscar en logs:
"📄 [COBRO] Paso 5/6: Generando documento PDF..."
// Si NO aparece "✅ PDF generado" después → crash aquí
```

**Revisar:**
- Tamaño del pedido (muchas líneas)
- Imágenes embebidas en PDF
- Uso de memoria (`Task Manager → planeag_flutter.exe`)

---

## 📊 **CHECKLIST DE REVISIÓN DEL CÓDIGO**

### ✅ Flujo de cobro (`caja_rapida_screen.dart`)

- [ ] ¿Todos los `await` están presentes en operaciones async?
- [ ] ¿Se verifica `mounted` antes de `setState()`?
- [ ] ¿Los servicios están inicializados correctamente?
- [ ] ¿El `try-catch` captura todas las excepciones?

### ✅ Servicios Firebase

- [ ] ¿Las colecciones de Firestore existen?
- [ ] ¿Los permisos de seguridad permiten escritura?
- [ ] ¿Los índices compuestos están creados?

### ✅ Generación de PDF

- [ ] ¿La configuración de TPV existe en Firestore?
- [ ] ¿Los datos del pedido son válidos?
- [ ] ¿La librería `pdf` está actualizada?

### ✅ Plugins y Dependencies

- [ ] ¿Todos los plugins son compatibles con Windows?
- [ ] ¿Las versiones de plugins son estables (no alpha/beta)?
- [ ] ¿Se ejecutó `flutter pub get` después de editar `pubspec.yaml`?

---

## 🎯 **PRÓXIMOS PASOS**

### 1. Ejecutar la app con logging activado

```powershell
flutter run -d windows --verbose > C:\Users\Samu\debug_tpv_log.txt 2>&1
```

### 2. Reproducir el crash

1. Abre la app
2. Ve a TPV → Caja Rápida
3. Agrega productos al ticket
4. Click en "COBRAR"
5. Confirma el cobro
6. **→ Observa dónde se detienen los logs**

### 3. Revisar los archivos de log

```powershell
# Log en tiempo real (archivo persistente)
notepad C:\Users\Samu\Documents\fluixcrm_crash.log

# Log completo de ejecución
notepad C:\Users\Samu\debug_tpv_log.txt
```

### 4. Buscar el último mensaje antes del crash

**Ejemplo de análisis:**

```
[14:32:15.123] 💰 [COBRO] Paso 4/6: Marcando como pagado...
[14:32:15.456] ✅ [COBRO] Estado de pago cambiado a Pagado
[14:32:15.789] 📄 [COBRO] Paso 5/6: Generando documento PDF...
[14:32:16.001] 🔴 PLATFORM ERROR:
[14:32:16.002] PlatformException(printing_not_available)
[14:32:16.003] Stack: ...
```

**→ En este ejemplo, el crash ocurre al generar el PDF**

---

## 📧 **COMPARTIR INFORMACIÓN DEL CRASH**

Una vez tengas los logs, comparte:

1. **Archivo de log persistente:**
   ```
   C:\Users\Samu\Documents\fluixcrm_crash.log
   ```

2. **Últimas 50 líneas del log de ejecución:**
   ```powershell
   Get-Content C:\Users\Samu\debug_tpv_log.txt -Tail 50
   ```

3. **Información del Event Viewer:**
   - Captura de pantalla del error en Application Log
   - Nombre del módulo que causó el fallo (Fault module)

4. **Paso exacto donde falla:**
   - "Paso 5/6: Generando documento PDF" (por ejemplo)

---

## 🛠️ **COMANDOS ÚTILES**

```powershell
# Ver versión de Flutter
flutter --version

# Ver dispositivos disponibles
flutter devices

# Limpiar y reconstruir
flutter clean ; flutter pub get ; flutter run -d windows

# Ver logs en tiempo real con filtro
flutter run -d windows --verbose | Select-String "COBRO|ERROR|EXCEPTION"

# Verificar plugins instalados
flutter pub deps --style=compact

# Abrir carpeta de logs
explorer C:\Users\Samu\Documents
```

---

## ✨ **RESUMEN**

| Acción | Comando / Archivo |
|--------|------------------|
| **Ejecutar con logs** | `flutter run -d windows --verbose > debug_tpv_log.txt 2>&1` |
| **Ver log persistente** | `notepad C:\Users\Samu\Documents\fluixcrm_crash.log` |
| **Ver Event Viewer** | `eventvwr.msc` → Application Logs |
| **Buscar en logs** | `[COBRO]`, `🔴`, `Stack:`, `ERROR`, `EXCEPTION` |

---

**Una vez tengascualquiera de estos logs con el stack trace, compártelos para identificar la causa exacta y aplicar el fix. 🚀**


#  CHECKLIST TÉCNICO: Revisión del Código de Cobro

**Objetivo:** Identificar la causa del crash silencioso en el flujo de cobro del TPV

---

##  **SECCIÓN 1: FLUJO DE COBRO PRINCIPAL**

### ✅ Archivo: `caja_rapida_screen.dart` → método `_cobrar()`

Revisa cada operación async línea por línea:

```dart
// Paso 2/6: Crear pedido
final pedido = await _svc.crearPedido(...)
```

**Preguntas:**

- [ ] ¿El método `crearPedido()` tiene `await`? SI ✅ | NO ❌
- [ ] ¿El método maneja excepciones internas? SI ✅ | NO ❌
- [ ] ¿Todos los parámetros requeridos están presentes? SI ✅ | NO ❌
- [ ] ¿`widget.empresaId` existe y no es null? SI ✅ | NO ❌

---

```dart
// Paso 3/6: Cambiar estado
await _svc.cambiarEstado(widget.empresaId, pedido.id, EstadoPedido.entregado, '', 'TPV');
```

**Preguntas:**

- [ ] ¿`pedido.id` existe después de `crearPedido()`? SI ✅ | NO ❌
- [ ] ¿El método tiene try-catch interno? SI ✅ | NO ❌
- [ ] ¿El documento existe en Firestore antes de actualizarlo? SI ✅ | NO ❌

---

```dart
// Paso 4/6: Cambiar estado de pago
await _svc.cambiarEstadoPago(widget.empresaId, pedido.id, EstadoPago.pagado, '', 'TPV');
```

**Preguntas:**

- [ ] ¿Este método accede a subcollections o campos anidados? SI ✅ | NO ❌
- [ ] ¿Los permisos de Firestore permiten esta escritura? SI ✅ | NO ❌

---

```dart
// Paso 5/6: Generar PDF
pdfBytes = await _facturacionAuto.procesarCobro(empresaId: widget.empresaId, pedido: pedido);
```

**Preguntas:**

- [ ] ¿Este paso está dentro de un try-catch? SI ✅ | NO ❌
- [ ] ¿La configuración de TPV existe en Firestore? SI ✅ | NO ❌
- [ ] ¿El plugin `pdf` es compatible con Windows? SI ✅ | NO ❌
- [ ] ¿El plugin `printing` funciona en Windows? SI ✅ | NO ❌

---

##  **SECCIÓN 2: SERVICIO DE FACTURACIÓN AUTOMÁTICA**

### ✅ Archivo: `facturacion_automatica_service.dart` → método `procesarCobro()`

```dart
Future<Uint8List?> procesarCobro({
  required String empresaId,
  required Pedido pedido,
}) async {
  // ...
}
```

**Preguntas:**

- [ ] ¿Lee correctamente la configuración de Firestore? SI ✅ | NO ❌
- [ ] ¿Maneja el caso de configuración no existente? SI ✅ | NO ❌
- [ ] ¿Todas las operaciones Firebase tienen `await`? SI ✅ | NO ❌
- [ ] ¿Retorna `null` si no debe generar documento? SI ✅ | NO ❌

### Código a verificar:

```dart
// ¿Este código está protegido?
final configDoc = await FirebaseFirestore.instance
    .collection('empresas')
    .doc(empresaId)
    .collection('configuracion_tpv')
    .doc('facturacion')
    .get();

if (!configDoc.exists) {
  // ¿Maneja este caso?
  return null; // o lanza excepción controlada
}
```

**Posibles problemas:**

- ❌ No verifica si `configDoc.exists`
- ❌ No maneja `data()` siendo null
- ❌ Asume campos existen sin validar

---

##  **SECCIÓN 3: RENDERIZADOR DE DOCUMENTOS TPV**

### ✅ Archivo: `tpv_document_renderer.dart` → método `renderizarDocumento()`

```dart
Future<Uint8List> renderizarDocumento({
  required ConfiguracionFacturacionTpv config,
  required Pedido pedido,
  required Map<String, dynamic> empresaData,
}) async {
  // ...
}
```

**Preguntas:**

- [ ] ¿Valida que `empresaData` tenga campos requeridos? SI ✅ | NO ❌
- [ ] ¿Maneja listas vacías en `pedido.lineas`? SI ✅ | NO ❌
- [ ] ¿Usa operador null-safety (`??`) correctamente? SI ✅ | NO ❌

### Código sospechoso:

```dart
// ❌ PELIGROSO: Puede fallar si el campo no existe
final nif = empresaData['nif'] as String;

// ✅ SEGURO
final nif = empresaData['nif'] as String? ?? 'Sin NIF';
```

**Buscar en el código:**

```dart
// Busca líneas que usen:
as String       // Sin '?' → Puede crashear
as int          // Sin '?' → Puede crashear
!               // Operador de null-assertion → Puede crashear
```

---

##  **SECCIÓN 4: PLUGINS DE WINDOWS**

### ✅ Verificar compatibilidad de plugins

```powershell
# Ver dependencias instaladas
flutter pub deps --style=compact
```

**Plugins que causan crashes en Windows:**

| Plugin | Compatible Windows | Acción |
|--------|-------------------|--------|
| `blue_thermal_printer` | ❌ NO | **Comentar código que lo use** |
| `printing` | ✅ SI (con cuidado) | Verificar configuración |
| `path_provider` | ✅ SI | Verificar permisos |
| `pdf` | ✅ SI | OK |

### Revisar código de impresión:

```dart
// ❌ CRASH en Windows
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

// Cualquier llamada a:
BlueThermalPrinter printer = BlueThermalPrinter.instance;
await printer.connect(device);  // ← CRASH
```

**Solución:**

```dart
// ✅ CORRECTO: Detección de plataforma
if (Platform.isAndroid || Platform.isIOS) {
  // Usar blue_thermal_printer
} else {
  // Usar printing (sistema)
}
```

---

##  **SECCIÓN 5: OPERACIONES FIRESTORE**

### ✅ Verificar permisos y estructura

**Colecciones involucradas:**

```
empresas/{empresaId}
  └─ pedidos/{pedidoId}
  └─ configuracion_tpv/facturacion
  └─ documentos_tpv/{documentoId}
```

**Verificar en Firebase Console:**

- [ ] ¿La colección `pedidos` existe? SI ✅ | NO ❌
- [ ] ¿La colección `configuracion_tpv` existe? SI ✅ | NO ❌
- [ ] ¿Las reglas de seguridad permiten escritura? SI ✅ | NO ❌

**Reglas de seguridad necesarias:**

```javascript
// Firestore Rules
match /empresas/{empresaId} {
  match /pedidos/{pedidoId} {
    allow read, write: if request.auth != null && 
                        get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.empresa_id == empresaId;
  }
  match /configuracion_tpv/{docId} {
    allow read: if request.auth != null;
  }
}
```

---

##  **SECCIÓN 6: ANÁLISIS DE LOGS**

### ✅ Buscar patrones de fallo

**Ejecuta el debug y busca esto en el log:**

```
 [COBRO] Paso 5/6: Generando documento PDF...
// Si después NO aparece "✅ PDF generado" → Crash aquí
```

**Otros patrones:**

| Patrón en Log | Significado |
|---------------|-------------|
| ` PLATFORM ERROR:` | Error en platform channel (plugin de Windows) |
| ` FLUTTER ERROR:` | Error en widget/render |
| ` UNCAUGHT ASYNC ERROR:` | Error en Future sin await |
| `MissingPluginException` | Plugin no registrado o incompatible |
| `PlatformException` | Error llamando código nativo |
| `Null check operator` | Error de null safety (`!`) |
| `NoSuchMethodError` | Llamada a método en objeto null |

---

##  **SECCIÓN 7: CAUSAS MÁS PROBABLES**

Basándome en el análisis del código, estas son las causas más probables del crash:

###  **Causa #1: Plugin printing en Windows (50% probabilidad)**

**Síntoma:** Crash en "Paso 5/6: Generando documento PDF"

**Código sospechoso:**
```dart
await _facturacionAuto.procesarCobro(empresaId: widget.empresaId, pedido: pedido);
```

**Test rápido:**
```dart
// Comentar temporalmente esta sección
/*
pdfBytes = await _facturacionAuto.procesarCobro(...);
*/
// Si el crash desaparece → Confirmado
```

**Fix:**
```dart
// Añadir detección de plataforma en tpv_document_renderer.dart
if (kIsWeb || Platform.isWindows) {
  // Usar solo generación de bytes, sin imprimir directamente
}
```

---

###  **Causa #2: Null safety en ConfiguracionFacturacionTpv (30% probabilidad)**

**Síntoma:** Crash al leer configuración que no existe

**Código sospechoso:**
```dart
final config = await _facturacionSvc.obtenerConfig(widget.empresaId);
// ¿Qué pasa si config es null o tiene campos null?
```

**Test rápido:**
```dart
// En Firestore Console, verifica si existe:
empresas/{tu-empresa-id}/configuracion_tpv/facturacion
```

**Fix:**
```dart
final config = await _facturacionSvc.obtenerConfig(widget.empresaId) 
    ?? const ConfiguracionFacturacionTpv(); // Config por defecto
```

---

###  **Causa #3: Operación Firestore sin await (15% probabilidad)**

**Síntoma:** Crash async después de cambiar estado

**Buscar en `pedidos_service.dart`:**
```dart
// ❌ PELIGROSO
void cambiarEstado(...) {
  FirebaseFirestore.instance.collection(...).doc(...).update(...);
  // Sin await → puede fallar silenciosamente
}

// ✅ CORRECTO
Future<void> cambiarEstado(...) async {
  await FirebaseFirestore.instance.collection(...).doc(...).update(...);
}
```

---

###  **Causa #4: setState() después de dispose() (5% probabilidad)**

**Síntoma:** Crash al volver al diálogo o cerrar pantalla

**Código sospechoso:**
```dart
setState(() => _cobrando = false);
```

**Ya está protegido:**
```dart
if (mounted) setState(() => _cobrando = false); // ✅
```

---

##  **PLAN DE ACCIÓN INMEDIATO**

### Paso 1: Ejecutar el script de debug

```powershell
.\debug_tpv.ps1
```

### Paso 2: Reproducir el crash y buscar en el log

Busca el **último paso completado** antes del crash:

```
✅ [COBRO] Paso X/6: [nombre del paso]
// Si no aparece el siguiente "Paso X+1" → Crash en paso X
```

### Paso 3: Revisar el código de ese paso específico

- **Paso 2** → `pedidos_service.dart` → `crearPedido()`
- **Paso 3** → `pedidos_service.dart` → `cambiarEstado()`
- **Paso 4** → `pedidos_service.dart` → `cambiarEstadoPago()`
- **Paso 5** → `facturacion_automatica_service.dart` + `tpv_document_renderer.dart`
- **Paso 6** → `caja_rapida_screen.dart` → `_generarTicketTexto()`

### Paso 4: Aplicar test rápido

Comenta el código del paso donde falla y vuelve a probar.

### Paso 5: Compartir logs

```
C:\Users\Samu\Documents\fluixcrm_crash.log
C:\Users\Samu\debug_tpv_complete_YYYYMMDD_HHMMSS.txt
```

---

## ✅ **CUANDO ENCUENTRES EL ERROR...**

Comparte esta información:

1. **Paso donde falla:** "Paso 5/6: Generando documento PDF"
2. **Mensaje de error:** El texto después de `` en el log
3. **Stack trace:** Las líneas después de `Stack:`
4. **Contexto:** ¿Existe la configuración TPV en Firestore? ¿Qué plugins están activos?

Con esto podré identificar la causa exacta y darte el fix específico. 

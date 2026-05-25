# AUDITORÍA TÉCNICA COMPLETA — FLUIX CRM
**Fecha:** 19 de Mayo de 2026  
**Auditor:** CTO Senior & Arquitecto de Software  
**Alcance:** Análisis completo de arquitectura, código, seguridad, rendimiento y escalabilidad

---

## RESUMEN EJECUTIVO

### ⚠️ **VEREDICTO GENERAL: APLICACIÓN EN ESTADO CRÍTICO**

Esta aplicación presenta **problemas estructurales graves** que comprometen su viabilidad como producto SaaS enterprise. Si bien demuestra funcionalidad operativa y una implementación fiscal avanzada, la arquitectura subyacente es **insostenible a medio plazo**.

**Estado actual:** Aplicación funcional pero con **deuda técnica masiva**, **antipatrones generalizados**, **riesgos de seguridad críticos**, y **arquitectura deficiente** que impide el crecimiento.

**Riesgo de colapso:** **ALTO** — sin refactorización urgente, el coste de mantenimiento será exponencial y la aplicación colapsará bajo su propio peso.

---

## SCORE GLOBAL

| Dimensión | Score | Estado |
|-----------|-------|--------|
| **Arquitectura** | 3.5/10 | 🔴 CRÍTICO |
| **Seguridad** | 5.0/10 | 🟠 ALTO RIESGO |
| **Rendimiento** | 4.0/10 | 🟠 DEFICIENTE |
| **Escalabilidad** | 3.0/10 | 🔴 CRÍTICO |
| **Calidad de código** | 5.5/10 | 🟠 REGULAR |
| **UX/UI** | 6.5/10 | 🟡 ACEPTABLE |
| **DevOps/CI/CD** | 4.0/10 | 🟠 DEFICIENTE |
| **Mantenibilidad** | 3.0/10 | 🔴 CRÍTICO |
| **Testing** | 4.5/10 | 🟠 INSUFICIENTE |
| **Observabilidad** | 2.5/10 | 🔴 CRÍTICO |

**SCORE GLOBAL: 4.1/10** — **INACEPTABLE PARA PRODUCCIÓN ENTERPRISE**

---

## TOP 10 PROBLEMAS MÁS CRÍTICOS

### 1. 🔴 **ACCESO DIRECTO A FIRESTORE DESDE UI — RIESGO ARQUITECTÓNICO CATASTRÓFICO**

**Gravedad:** CRÍTICA  
**Impacto:** Imposible escalar, imposible testear, imposible mantener, seguridad comprometida

**Problema:**
La aplicación accede directamente a `FirebaseFirestore.instance` desde **widgets, pantallas y servicios** de forma masiva y descontrolada:

```dart
// ❌ ANTIPATRÓN MASIVO EN TODA LA APP
final snap = await FirebaseFirestore.instance
  .collection('empresas')
  .doc(empresaId)
  .collection('clientes')
  .where('activo', isEqualTo: true)
  .get();
```

**Ubicaciones detectadas:**
- `lib/features/perfil/pantallas/pantalla_perfil.dart` (líneas 112, 837, 1628, 1638)
- `lib/features/tpv/widgets/dialogo_devoluciones.dart` (líneas 68, 79, 165)
- `lib/features/tpv/widgets/tpv_bar_mejoras.dart` (líneas 176, 242, 383)
- `lib/features/tpv/widgets/tpv_bar_cobro.dart` (líneas 364, 597, 708)
- Y **más de 100 servicios** que instancian directamente `FirebaseFirestore.instance`

**Consecuencias:**
1. **Imposible testear:** No puedes hacer mock de Firestore en tests unitarios
2. **Imposible migrar:** Estás casado con Firebase para siempre
3. **Lógica de negocio mezclada con infraestructura:** Viola Clean Architecture
4. **Queries duplicados:** Cada servicio escribe su propia query manual
5. **Sin caché central:** Cada widget hace su propia petición HTTP
6. **Sin control de acceso centralizado:** Rules de Firestore son tu única defensa
7. **Debugging imposible:** ¿Cuántas peticiones hace cada pantalla? No lo sabes
8. **Performance impredecible:** Sin control sobre Network I/O

**Solución obligatoria:**
Implementar **Repository Pattern** con interfaces de dominio:

```dart
// ✅ SOLUCIÓN
abstract class ClienteRepository {
  Future<List<Cliente>> obtenerClientes(String empresaId);
  Future<Cliente?> obtenerClientePorId(String empresaId, String clienteId);
  Stream<List<Cliente>> watchClientes(String empresaId);
}

class FirestoreClienteRepository implements ClienteRepository {
  final FirebaseFirestore _db;
  FirestoreClienteRepository(this._db);
  
  @override
  Future<List<Cliente>> obtenerClientes(String empresaId) async {
    final snap = await _db.collection('empresas')
      .doc(empresaId)
      .collection('clientes')
      .get();
    return snap.docs.map((d) => Cliente.fromFirestore(d)).toList();
  }
}
```

**Esfuerzo:** ALTO (3-4 semanas)  
**Prioridad:** **URGENTE** — esto es lo primero que debe hacerse

---

### 2. 🔴 **SERVICIOS GIGANTES CON RESPONSABILIDADES MÚLTIPLES — GOD OBJECTS**

**Gravedad:** CRÍTICA  
**Impacto:** Mantenimiento imposible, bugs en cascada, testing imposible

**Problema:**
Los servicios violan brutalmente el **Single Responsibility Principle**:

- **`demo_cuenta_service.dart`:** 1,118 líneas, 43,576 caracteres
- **`facturacion_service.dart`:** 1,192 líneas
- **`nominas_service.dart`:** 1,458 líneas

Estos servicios hacen **DEMASIADO**:

```dart
// ❌ demo_cuenta_service.dart hace de TODO:
// - Crear empresas de prueba
// - Crear empleados
// - Crear clientes
// - Crear reservas
// - Crear facturas
// - Crear pedidos
// - Crear tareas
// - Crear valoraciones
// - Crear contenido web
// - Configurar Verifactu
// - Configurar TPV
// - Y 30 cosas más...
```

**Consecuencias:**
1. **Imposible testear:** ¿Cómo mockeas 30 dependencias?
2. **Bugs en cascada:** Un cambio en línea 500 rompe código en línea 1000
3. **Merge conflicts constantes:** Múltiples devs editando el mismo archivo
4. **Carga mental brutal:** Nadie entiende todo el código
5. **Violación de Open/Closed:** Cada nueva feature modifica el mismo archivo
6. **God Object antipattern:** El servicio lo sabe todo, lo hace todo

**Solución obligatoria:**
Dividir cada servicio en **casos de uso específicos**:

```dart
// ✅ SOLUCIÓN: Domain-Driven Design + CQRS
// Comandos (escritura)
class CrearFacturaUseCase {
  final FacturaRepository _repo;
  final VerifactuService _verifactu;
  final ValidadorFiscal _validador;
  
  Future<Factura> ejecutar(CrearFacturaCommand cmd) async {
    // Lógica de negocio aislada
    final factura = Factura.crear(...);
    await _validador.validar(factura);
    await _repo.guardar(factura);
    await _verifactu.registrar(factura);
    return factura;
  }
}

// Queries (lectura)
class ObtenerFacturasDelMesQuery {
  final FacturaRepository _repo;
  
  Future<List<Factura>> ejecutar(int mes, int año, String empresaId) {
    return _repo.obtenerPorMesYAño(mes, año, empresaId);
  }
}
```

**Esfuerzo:** ALTO (4-6 semanas)  
**Prioridad:** **CRÍTICA**

---

### 3. 🔴 **SIN DEPENDENCY INJECTION REAL — SINGLETON HELL**

**Gravedad:** CRÍTICA  
**Impacto:** Testing imposible, acoplamiento brutal, memory leaks

**Problema:**
La aplicación usa **singletons manuales** en todos los servicios:

```dart
// ❌ ANTIPATRÓN MASIVO
class NominasService {
  static final NominasService _i = NominasService._();
  factory NominasService() => _i;
  NominasService._();
  
  FirebaseFirestore get _db => FirebaseFirestore.instance; // ⚠️ HARDCODED
  final ContabilidadService _contaSvc = ContabilidadService(); // ⚠️ HARDCODED
  final ConvenioFirestoreService _convSvc = ConvenioFirestoreService(); // ⚠️ HARDCODED
}
```

**Consecuencias:**
1. **Imposible testear:** No puedes inyectar mocks
2. **Dependencias ocultas:** No sabes qué necesita cada servicio
3. **Acoplamiento temporal:** Los servicios se instancian en orden impredecible
4. **Memory leaks:** Los singletons viven para siempre
5. **Imposible hacer lazy loading:** Todos se crean al inicio
6. **Imposible hacer feature flags:** No puedes cambiar implementaciones

**Solución obligatoria:**
Usar **GetIt** (que ya está en `pubspec.yaml` pero **NO SE USA**):

```dart
// ✅ SOLUCIÓN: Dependency Injection real
final getIt = GetIt.instance;

void setupDI() {
  // Infraestructura
  getIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  
  // Repositories
  getIt.registerLazySingleton<ClienteRepository>(
    () => FirestoreClienteRepository(getIt<FirebaseFirestore>())
  );
  
  // Use Cases
  getIt.registerFactory<CrearFacturaUseCase>(
    () => CrearFacturaUseCase(
      getIt<FacturaRepository>(),
      getIt<VerifactuService>(),
      getIt<ValidadorFiscal>(),
    )
  );
  
  // Servicios
  getIt.registerLazySingleton<NominasService>(
    () => NominasService(
      getIt<NominaRepository>(),
      getIt<ConvenioRepository>(),
    )
  );
}

// En los widgets/servicios:
class MiWidget extends StatelessWidget {
  final CrearFacturaUseCase _crearFactura = getIt<CrearFacturaUseCase>();
}
```

**Esfuerzo:** MEDIO (2-3 semanas)  
**Prioridad:** **URGENTE**

---

### 4. 🔴 **QUERIES SIN ÍNDICES — PERFORMANCE CATASTRÓFICO**

**Gravedad:** CRÍTICA  
**Impacto:** La app será LENTA con >1000 documentos, costes de Firestore disparados

**Problema:**
La aplicación hace **queries complejas sin índices compuestos**:

```dart
// ❌ ESTO REQUIERE ÍNDICE COMPUESTO EN FIRESTORE
final snap = await _facturas(empresaId)
  .where('estado', isEqualTo: EstadoFactura.pendiente.name)
  .where('fecha_emision', isGreaterThanOrEqualTo: inicio)
  .orderBy('fecha_emision', descending: true)
  .get();

// ❌ ESTO FALLA EN PRODUCCIÓN (Firestore lanza error de índice)
final snap = await _clientes(empresaId)
  .where('activo', isEqualTo: true)
  .where('total_gastado', isGreaterThan: 1000)
  .orderBy('total_gastado', descending: true)
  .get();
```

**Evidencia:**
- El código hace queries con múltiples `where()` + `orderBy()`
- **NO HAY** `firestore.indexes.json` en el proyecto
- **NO HAY** documentación de índices necesarios
- Las reglas de Firestore **NO ESTÁN** versionadas en el repo

**Consecuencias:**
1. **App crashea en producción:** Firestore lanza `FAILED_PRECONDITION: The query requires an index`
2. **Performance terrible:** Queries sin índice tardan segundos
3. **Costes disparados:** Lees todos los documentos (no solo los necesarios)
4. **Experiencia horrible:** Usuarios ven spinners eternos

**Solución obligatoria:**
1. Crear `firestore.indexes.json`:
```json
{
  "indexes": [
    {
      "collectionGroup": "facturas",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "empresa_id", "order": "ASCENDING" },
        { "fieldPath": "estado", "order": "ASCENDING" },
        { "fieldPath": "fecha_emision", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "clientes",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "empresa_id", "order": "ASCENDING" },
        { "fieldPath": "activo", "order": "ASCENDING" },
        { "fieldPath": "total_gastado", "order": "DESCENDING" }
      ]
    }
  ]
}
```

2. Desplegar índices: `firebase deploy --only firestore:indexes`

3. **EVITAR queries complejas:** Usar denormalización y caché

**Esfuerzo:** MEDIO (1-2 semanas para auditar todas las queries)  
**Prioridad:** **CRÍTICA**

---

### 5. 🔴 **REGLAS DE FIRESTORE INEXISTENTES O INSEGURAS**

**Gravedad:** **CRÍTICA** — RIESGO DE SEGURIDAD MASIVO  
**Impacto:** Cualquier usuario puede leer/modificar datos de CUALQUIER empresa

**Problema:**
No hay evidencia de **Firestore Security Rules** adecuadas en el repositorio:

- **NO HAY** archivo `firestore.rules` versionado
- **NO HAY** tests de reglas de seguridad
- **NO HAY** documentación de permisos

**Riesgo:**
```javascript
// ⚠️ SI LAS REGLAS SON ASÍ (default Firebase):
match /{document=**} {
  allow read, write: if request.auth != null;
}

// ☠️ ENTONCES CUALQUIER USUARIO AUTENTICADO PUEDE:
// - Leer facturas de TODAS las empresas
// - Leer nóminas de TODOS los empleados
// - Modificar datos de CUALQUIER empresa
// - Borrar documentos críticos
```

**Evidencia en el código:**
```dart
// Múltiples servicios hacen queries SIN VALIDAR empresa_id del usuario:
final snap = await FirebaseFirestore.instance
  .collection('empresas')
  .doc(empresaId) // ⚠️ Este ID viene del cliente, podría ser manipulado
  .collection('nominas')
  .get();
```

**Solución obligatoria:**
Crear `firestore.rules` con validación estricta:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Función helper: verificar que el usuario pertenece a la empresa
    function perteneceAEmpresa(empresaId) {
      return request.auth != null &&
             get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.empresa_id == empresaId;
    }
    
    // Función helper: es admin de la plataforma
    function esAdmin() {
      return request.auth != null &&
             get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Empresas: solo propietarios y empleados de la empresa pueden leer/escribir
    match /empresas/{empresaId} {
      allow read: if perteneceAEmpresa(empresaId) || esAdmin();
      allow write: if perteneceAEmpresa(empresaId); // Solo empleados, no clientes
      
      // Subcolecciones
      match /clientes/{clienteId} {
        allow read, write: if perteneceAEmpresa(empresaId);
      }
      
      match /facturas/{facturaId} {
        allow read, write: if perteneceAEmpresa(empresaId);
      }
      
      match /nominas/{nominaId} {
        allow read: if perteneceAEmpresa(empresaId);
        allow write: if perteneceAEmpresa(empresaId) && 
                       get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role == 'propietario';
      }
    }
    
    // Usuarios: cada usuario solo puede leer/modificar su propio documento
    match /usuarios/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Denegar todo lo demás
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Tests de seguridad obligatorios:**
```typescript
// firestore-rules.test.ts
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';

test('Usuario NO puede leer empresas ajenas', async () => {
  const db = getFirestore(testApp('user1', { empresa_id: 'empresa1' }));
  await assertFails(db.collection('empresas').doc('empresa2').get());
});

test('Usuario SÍ puede leer su propia empresa', async () => {
  const db = getFirestore(testApp('user1', { empresa_id: 'empresa1' }));
  await assertSucceeds(db.collection('empresas').doc('empresa1').get());
});
```

**Esfuerzo:** ALTO (2 semanas)  
**Prioridad:** **CRÍTICA URGENTE** — esto es un agujero de seguridad masivo

---

### 6. 🔴 **SIN MANEJO DE ERRORES CENTRALIZADO — UX HORRIBLE Y DEBUGGING IMPOSIBLE**

**Gravedad:** ALTA  
**Impacto:** Usuarios ven errores técnicos, crashes silenciosos, debugging imposible

**Problema:**
El manejo de errores es **caótico e inconsistente**:

```dart
// ❌ PATRÓN 1: Ignorar errores silenciosamente
try {
  await VerifactuService.registrarFactura(...);
} catch (_) {} // ⚠️ Error silencioso, nadie se entera

// ❌ PATRÓN 2: Print y continuar
try {
  await _firestore.collection('empresas').doc(id).update(data);
} catch (e) {
  debugPrint('⚠️ Error actualizando empresa: $e'); // ⚠️ Solo en debug
}

// ❌ PATRÓN 3: Lanzar excepción genérica
throw Exception('Error de validación fiscal: ${resultado.errores.first}');
// ⚠️ El usuario ve: "Exception: Error de validación fiscal: R1 - Campo obligatorio..."

// ❌ PATRÓN 4: No capturar nada
final factura = Factura.fromFirestore(doc); // ⚠️ Si falla, crashea la app
```

**Consecuencias:**
1. **Usuarios ven mensajes técnicos:** "Exception: FirebaseException [permission-denied]"
2. **Crashes silenciosos:** Errores que nadie registra
3. **Debugging imposible:** No hay trazas de errores
4. **No hay métricas de errores:** ¿Cuántos errores hay en producción? No se sabe
5. **No hay alertas:** Errores críticos pasan desapercibidos

**Solución obligatoria:**

```dart
// ✅ SOLUCIÓN 1: Tipos de resultado (Railway Oriented Programming)
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);
}

// Tipos de errores jerárquicos
sealed class AppError {
  final String message;
  final String? technicalDetails;
  final StackTrace? stackTrace;
  
  const AppError(this.message, {this.technicalDetails, this.stackTrace});
  
  String getUserMessage(); // Mensaje amigable para el usuario
}

class ValidationError extends AppError {
  final Map<String, String> fieldErrors;
  ValidationError(super.message, this.fieldErrors);
  
  @override
  String getUserMessage() => 'Por favor, revisa los campos marcados en rojo';
}

class NetworkError extends AppError {
  NetworkError(super.message, {super.technicalDetails, super.stackTrace});
  
  @override
  String getUserMessage() => 'No hay conexión a Internet. Inténtalo más tarde.';
}

class PermissionError extends AppError {
  PermissionError(super.message, {super.technicalDetails});
  
  @override
  String getUserMessage() => 'No tienes permisos para realizar esta acción';
}

// Uso en servicios:
class FacturacionService {
  Future<Result<Factura>> crearFactura(CrearFacturaCommand cmd) async {
    try {
      // Validación
      final validacion = _validar(cmd);
      if (validacion.isNotEmpty) {
        return Failure(ValidationError('Datos inválidos', validacion));
      }
      
      // Lógica de negocio
      final factura = await _repo.crear(cmd);
      
      return Success(factura);
    } on FirebaseException catch (e, st) {
      if (e.code == 'permission-denied') {
        return Failure(PermissionError(
          'Sin permisos para crear factura',
          technicalDetails: e.message,
        ));
      }
      return Failure(NetworkError(
        'Error al guardar factura',
        technicalDetails: e.toString(),
        stackTrace: st,
      ));
    } catch (e, st) {
      // Log para monitoring
      crashlytics.recordError(e, st);
      return Failure(AppError(
        'Error inesperado',
        technicalDetails: e.toString(),
        stackTrace: st,
      ));
    }
  }
}

// ✅ SOLUCIÓN 2: Error handler global para UI
class ErrorHandler {
  static void showError(BuildContext context, AppError error) {
    // Log técnico
    logger.error(error.message, 
      technicalDetails: error.technicalDetails,
      stackTrace: error.stackTrace,
    );
    
    // UI amigable para usuario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.getUserMessage()),
        backgroundColor: Colors.red,
        action: error is NetworkError 
          ? SnackBarAction(label: 'Reintentar', onPressed: () {})
          : null,
      ),
    );
  }
}

// Uso en UI:
final result = await _facturacionService.crearFactura(cmd);
result.when(
  success: (factura) => Navigator.pop(context, factura),
  failure: (error) => ErrorHandler.showError(context, error),
);
```

**Esfuerzo:** MEDIO (2-3 semanas)  
**Prioridad:** **ALTA**

---

### 7. 🟠 **LÓGICA DE NEGOCIO EN WIDGETS — VIOLACIÓN MASIVA DE SEPARATION OF CONCERNS**

**Gravedad:** ALTA  
**Impacto:** Testing imposible, código duplicado, bugs ocultos

**Problema:**
Los widgets contienen **lógica de negocio compleja**:

```dart
// ❌ lib/features/tpv/widgets/tpv_bar_cobro.dart (línea 364+)
onPressed: () async {
  final db = FirebaseFirestore.instance;
  final ventaData = {
    'empresa_id': widget.empresaId,
    'total': total,
    'fecha': FieldValue.serverTimestamp(),
    'metodo_pago': _metodoPagoSeleccionado,
    'lineas': lineasVenta.map((l) => {
      'producto_id': l.productoId,
      'cantidad': l.cantidad,
      'precio_unitario': l.precioUnitario,
      'subtotal': l.cantidad * l.precioUnitario,
    }).toList(),
    'cajero_uid': FirebaseAuth.instance.currentUser?.uid,
    'cajero_nombre': widget.nombreCajero,
    'estado': 'completada',
  };
  
  await db.collection('empresas')
    .doc(widget.empresaId)
    .collection('ventas')
    .add(ventaData);
    
  // Actualizar stock
  for (final linea in lineasVenta) {
    final productoRef = db.collection('empresas')
      .doc(widget.empresaId)
      .collection('productos')
      .doc(linea.productoId);
    
    await productoRef.update({
      'stock': FieldValue.increment(-linea.cantidad),
    });
  }
  
  // Crear factura si necesario
  if (_necesitaFactura) {
    await FacturacionService().crearFactura(/* ... */);
  }
  
  // Registrar en caja
  await db.collection('empresas')
    .doc(widget.empresaId)
    .collection('cajas')
    .doc(widget.cajaId)
    .update({'total_efectivo': FieldValue.increment(total)});
}
```

**Esto es CATASTRÓFICO porque:**
1. **Imposible testear:** ¿Cómo testas un widget con 200 líneas de lógica?
2. **Código duplicado:** Esta lógica se repite en múltiples pantallas
3. **Transacciones inseguras:** No hay atomicidad (si falla actualizar stock, ya guardaste la venta)
4. **Lógica de negocio mezclada con UI:** Viola Clean Architecture
5. **Dificultad para mantener:** Un cambio en la lógica de ventas requiere modificar widgets

**Solución obligatoria:**

```dart
// ✅ SOLUCIÓN: Extraer a Use Cases

// Domain Layer
class RegistrarVentaCommand {
  final String empresaId;
  final List<LineaVenta> lineas;
  final MetodoPago metodoPago;
  final String cajeroId;
  final bool generarFactura;
}

class RegistrarVentaUseCase {
  final VentaRepository _ventaRepo;
  final ProductoRepository _productoRepo;
  final FacturacionService _facturacion;
  final CajaRepository _cajaRepo;
  
  Future<Result<Venta>> ejecutar(RegistrarVentaCommand cmd) async {
    // Validar stock disponible
    for (final linea in cmd.lineas) {
      final producto = await _productoRepo.obtenerPorId(cmd.empresaId, linea.productoId);
      if (producto.stock < linea.cantidad) {
        return Failure(ValidationError('Stock insuficiente para ${producto.nombre}'));
      }
    }
    
    // Ejecutar en transacción atómica
    return await _db.runTransaction((tx) async {
      final venta = Venta.crear(cmd);
      
      // Guardar venta
      await _ventaRepo.guardar(venta, transaction: tx);
      
      // Actualizar stock
      for (final linea in cmd.lineas) {
        await _productoRepo.decrementarStock(
          cmd.empresaId,
          linea.productoId,
          linea.cantidad,
          transaction: tx,
        );
      }
      
      // Registrar en caja
      await _cajaRepo.registrarMovimiento(
        cmd.empresaId,
        venta.total,
        cmd.metodoPago,
        transaction: tx,
      );
      
      return Success(venta);
    });
  }
}

// Widget simplificado
class TpvBarCobro extends StatelessWidget {
  final RegistrarVentaUseCase _registrarVenta = getIt<RegistrarVentaUseCase>();
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final cmd = RegistrarVentaCommand(/* ... */);
        final result = await _registrarVenta.ejecutar(cmd);
        
        result.when(
          success: (venta) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Venta registrada correctamente')),
            );
            Navigator.pop(context, venta);
          },
          failure: (error) => ErrorHandler.showError(context, error),
        );
      },
      child: Text('Cobrar'),
    );
  }
}
```

**Esfuerzo:** ALTO (4-5 semanas para refactorizar todos los widgets)  
**Prioridad:** **ALTA**

---

### 8. 🟠 **SIN CACHÉ — PERFORMANCE TERRIBLE Y COSTES DISPARADOS**

**Gravedad:** ALTA  
**Impacto:** App lenta, costes de Firestore altos, experiencia mala

**Problema:**
La aplicación **NO TIENE** capa de caché:

```dart
// ❌ CADA VEZ que abres la pantalla de clientes:
Stream<List<Cliente>> watchClientes(String empresaId) {
  return _firestore
    .collection('empresas')
    .doc(empresaId)
    .collection('clientes')
    .snapshots() // ⚠️ Firestore realtime listener (CARO)
    .map((snap) => snap.docs.map(Cliente.fromFirestore).toList());
}

// Si tienes 1000 clientes, cada vez que abres la pantalla:
// - Pagas por 1000 document reads
// - Transfieres ~500KB de datos
// - Tardas 2-3 segundos en renderizar
```

**Evidencia:**
- Hay un `CacheService` pero **solo se usa para estadísticas**
- **No hay** caché de Firestore (Firestore tiene caché nativa, pero no controlada)
- **No hay** caché de imágenes más allá de `cached_network_image`
- **No hay** caché de queries complejas

**Consecuencias:**
1. **Performance horrible:** Pantallas tardan 2-5 segundos en cargar
2. **Costes altos:** 1000 clientes × 30 vistas/día × 30 días = 900.000 reads/mes
3. **Uso de datos móviles:** Usuarios consumen megas innecesariamente
4. **Experiencia mala:** Spinners por todos lados

**Solución obligatoria:**

```dart
// ✅ SOLUCIÓN: Cache Repository Pattern

class CachedClienteRepository implements ClienteRepository {
  final ClienteRepository _remote; // Firestore
  final CacheManager _cache;
  
  @override
  Future<List<Cliente>> obtenerClientes(String empresaId) async {
    // Intentar caché primero
    final cached = await _cache.get<List<Cliente>>('clientes_$empresaId');
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    
    // Si no hay caché o expiró, ir a Firestore
    final clientes = await _remote.obtenerClientes(empresaId);
    
    // Guardar en caché (TTL: 5 minutos)
    await _cache.set('clientes_$empresaId', clientes, ttl: Duration(minutes: 5));
    
    return clientes;
  }
  
  @override
  Stream<List<Cliente>> watchClientes(String empresaId) {
    // Combinar caché + realtime
    return _cache.watchOrFetch(
      key: 'clientes_$empresaId',
      fetcher: () => _remote.watchClientes(empresaId),
      ttl: Duration(minutes: 5),
    );
  }
}

// Implementar CacheManager con Hive o SharedPreferences
class HiveCacheManager implements CacheManager {
  final Box _box;
  
  @override
  Future<CachedValue<T>?> get<T>(String key) async {
    final json = _box.get(key);
    if (json == null) return null;
    
    final data = jsonDecode(json);
    final expiresAt = DateTime.parse(data['expires_at']);
    
    if (DateTime.now().isAfter(expiresAt)) {
      await _box.delete(key);
      return null;
    }
    
    return CachedValue(
      data: _deserialize<T>(data['data']),
      expiresAt: expiresAt,
    );
  }
  
  @override
  Future<void> set<T>(String key, T data, {required Duration ttl}) async {
    final expiresAt = DateTime.now().add(ttl);
    final json = jsonEncode({
      'data': _serialize(data),
      'expires_at': expiresAt.toIso8601String(),
    });
    await _box.put(key, json);
  }
}
```

**Estrategia de invalidación de caché:**

```dart
// Invalidar caché cuando se modifica un recurso
class CrearClienteUseCase {
  final ClienteRepository _repo;
  final CacheManager _cache;
  
  Future<Result<Cliente>> ejecutar(CrearClienteCommand cmd) async {
    final result = await _repo.crear(cmd);
    
    if (result is Success) {
      // Invalidar caché de lista de clientes
      await _cache.invalidate('clientes_${cmd.empresaId}');
    }
    
    return result;
  }
}
```

**Esfuerzo:** MEDIO (2-3 semanas)  
**Prioridad:** **ALTA** (impacto inmediato en UX y costes)

---

### 9. 🟠 **TESTING INSUFICIENTE — COBERTURA <20%**

**Gravedad:** ALTA  
**Impacto:** Bugs en producción, miedo a refactorizar, regresiones constantes

**Problema:**
Hay tests, pero **INSUFICIENTES**:

**Tests encontrados:**
- `test/nominas_service_test.dart`
- `test/validador_fiscal_integral_test.dart`
- `test/verifactu_hash_chain_test.dart`
- `test/sepa_xml_test.dart`
- Algunos widget tests básicos

**Tests AUSENTES:**
- ❌ Tests de servicios críticos (`ClientesService`, `FacturacionService`, `ReservasService`)
- ❌ Tests de repositories
- ❌ Tests de use cases
- ❌ Tests de integración end-to-end
- ❌ Tests de reglas de Firestore (**CRÍTICO**)
- ❌ Tests de UI críticos (TPV, cobro, facturación)
- ❌ Tests de performance

**Consecuencias:**
1. **Bugs en producción:** No hay red de seguridad
2. **Miedo a refactorizar:** Cualquier cambio puede romper algo
3. **Regresiones:** Features que funcionaban dejan de funcionar
4. **Debugging lento:** Sin tests, debugar es prueba-error

**Solución obligatoria:**

```dart
// ✅ Tests unitarios de servicios (con mocks)
void main() {
  late FacturacionService service;
  late MockFacturaRepository mockRepo;
  late MockVerifactuService mockVerifactu;
  
  setUp(() {
    mockRepo = MockFacturaRepository();
    mockVerifactu = MockVerifactuService();
    service = FacturacionService(mockRepo, mockVerifactu);
  });
  
  group('FacturacionService', () {
    test('crearFactura con datos válidos debe crear factura', () async {
      // Arrange
      final cmd = CrearFacturaCommand(/* ... */);
      when(() => mockRepo.guardar(any())).thenAnswer((_) async => Success());
      when(() => mockVerifactu.registrar(any())).thenAnswer((_) async => Success());
      
      // Act
      final result = await service.crearFactura(cmd);
      
      // Assert
      expect(result, isA<Success<Factura>>());
      verify(() => mockRepo.guardar(any())).called(1);
      verify(() => mockVerifactu.registrar(any())).called(1);
    });
    
    test('crearFactura con NIF inválido debe fallar', () async {
      final cmd = CrearFacturaCommand(nif: 'INVÁLIDO');
      
      final result = await service.crearFactura(cmd);
      
      expect(result, isA<Failure>());
      verifyNever(() => mockRepo.guardar(any()));
    });
  });
}

// ✅ Tests de integración con Firestore Emulator
void main() {
  late FirebaseFirestore db;
  late ClienteRepository repo;
  
  setUpAll(() async {
    // Conectar a Firestore Emulator
    db = FirebaseFirestore.instance;
    db.useFirestoreEmulator('localhost', 8080);
    repo = FirestoreClienteRepository(db);
  });
  
  setUp(() async {
    // Limpiar datos entre tests
    await clearFirestoreData(db);
  });
  
  test('INTEGRATION: crear cliente debe guardarlo en Firestore', () async {
    final cliente = Cliente(/* ... */);
    
    await repo.guardar(cliente);
    
    final snapshot = await db.collection('empresas/test/clientes').get();
    expect(snapshot.docs.length, 1);
    expect(snapshot.docs.first.data()['nombre'], cliente.nombre);
  });
}

// ✅ Tests de reglas de Firestore
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';

describe('Firestore Security Rules', () => {
  it('Usuario NO puede leer empresas ajenas', async () => {
    const db = getFirestore(authContext({ uid: 'user1', empresa_id: 'empresa1' }));
    await assertFails(db.collection('empresas').doc('empresa2').get());
  });
  
  it('Usuario SÍ puede leer su propia empresa', async () => {
    const db = getFirestore(authContext({ uid: 'user1', empresa_id: 'empresa1' }));
    await assertSucceeds(db.collection('empresas').doc('empresa1').get());
  });
});
```

**Objetivo de cobertura:** >80% en servicios críticos, >60% global  
**Esfuerzo:** ALTO (3-4 semanas para escribir tests completos)  
**Prioridad:** **MEDIA-ALTA**

---

### 10. 🟠 **SIN OBSERVABILIDAD — DEBUGGING EN PRODUCCIÓN IMPOSIBLE**

**Gravedad:** ALTA  
**Impacto:** No sabes qué pasa en producción, bugs invisibles, performance impredecible

**Problema:**
La aplicación **NO TIENE** observabilidad:

- ❌ No hay logging estructurado
- ❌ No hay tracing de requests
- ❌ No hay métricas de performance
- ❌ No hay monitorización de errores
- ✅ Hay `firebase_crashlytics` pero no se usa correctamente
- ✅ Hay `firebase_analytics` pero solo se usa para eventos básicos
- ✅ Hay `firebase_performance` pero probablemente sin configurar

**Evidencia en el código:**
```dart
// ❌ Logging con debugPrint (solo en debug mode)
debugPrint('⚠️ Error creando cliente: $e');

// ❌ Logs que no van a ningún lado en producción
print('ℹ️ AdminInitializer no ejecutado: $e');

// ❌ Logger definido pero no usado consistentemente
final _log = Logger(); // Solo en facturacion_service.dart
```

**Consecuencias:**
1. **Bugs invisibles en producción:** No sabes cuántos errores hay
2. **Performance impredecible:** No sabes qué pantallas son lentas
3. **Debugging imposible:** Usuario reporta bug, no tienes trazas
4. **No hay métricas de negocio:** ¿Cuántas facturas se crean/día? No se sabe
5. **No hay alertas:** Errores críticos pasan desapercibidos

**Solución obligatoria:**

```dart
// ✅ SOLUCIÓN 1: Logging estructurado con contexto

class AppLogger {
  final Logger _logger;
  final FirebaseCrashlytics _crashlytics;
  final FirebaseAnalytics _analytics;
  
  void debug(String message, {Map<String, dynamic>? context}) {
    _logger.d(message, error: context);
  }
  
  void info(String message, {Map<String, dynamic>? context}) {
    _logger.i(message, error: context);
    _analytics.logEvent(name: 'app_info', parameters: context);
  }
  
  void warning(String message, {Map<String, dynamic>? context}) {
    _logger.w(message, error: context);
    _crashlytics.log('WARNING: $message');
  }
  
  void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    
    // Enviar a Crashlytics
    _crashlytics.recordError(
      error ?? message,
      stackTrace,
      reason: message,
      information: context?.entries.map((e) => '${e.key}: ${e.value}').toList() ?? [],
    );
    
    // Registrar evento de error en Analytics
    _analytics.logEvent(
      name: 'error_occurred',
      parameters: {
        'error_message': message,
        'error_type': error.runtimeType.toString(),
        ...?context,
      },
    );
  }
}

// ✅ SOLUCIÓN 2: Tracing de operaciones críticas

class PerformanceMonitor {
  final FirebasePerformance _performance;
  
  Future<T> trace<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  }) async {
    final trace = _performance.newTrace(name);
    
    attributes?.forEach((key, value) {
      trace.putAttribute(key, value);
    });
    
    await trace.start();
    
    try {
      final result = await operation();
      trace.putAttribute('success', 'true');
      return result;
    } catch (e) {
      trace.putAttribute('success', 'false');
      trace.putAttribute('error', e.toString());
      rethrow;
    } finally {
      await trace.stop();
    }
  }
}

// Uso en servicios:
class FacturacionService {
  final AppLogger _logger;
  final PerformanceMonitor _perf;
  
  Future<Result<Factura>> crearFactura(CrearFacturaCommand cmd) async {
    return _perf.trace(
      'facturacion_crear_factura',
      () async {
        _logger.info('Creando factura', context: {
          'empresa_id': cmd.empresaId,
          'cliente': cmd.clienteNombre,
          'total': cmd.total,
        });
        
        try {
          final factura = await _repo.crear(cmd);
          
          _logger.info('Factura creada exitosamente', context: {
            'factura_id': factura.id,
            'numero': factura.numeroFactura,
          });
          
          return Success(factura);
        } catch (e, st) {
          _logger.error(
            'Error al crear factura',
            error: e,
            stackTrace: st,
            context: {'empresa_id': cmd.empresaId},
          );
          return Failure(AppError.fromException(e));
        }
      },
      attributes: {
        'empresa_id': cmd.empresaId,
        'tipo': cmd.tipo.name,
      },
    );
  }
}

// ✅ SOLUCIÓN 3: Dashboards de monitorización

// Configurar Crashlytics en main.dart:
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};

// Métricas custom en Analytics:
await FirebaseAnalytics.instance.logEvent(
  name: 'factura_creada',
  parameters: {
    'valor': factura.total,
    'metodo_pago': factura.metodoPago.name,
    'tiene_verifactu': factura.verifactuOk,
  },
);

// Configurar Performance Monitoring para HTTP requests automáticos
HttpClient.enableTimelineLogging = true;
```

**Esfuerzo:** MEDIO (2 semanas)  
**Prioridad:** **ALTA** (crítico para producción enterprise)

---

## AUDITORÍA POR MÓDULOS

### MÓDULO: Sistema de Autenticación y Sesiones

**Objetivo:**  
Gestionar autenticación de usuarios, sesiones, permisos y seguridad de acceso.

**Cómo funciona actualmente:**
- Firebase Auth para autenticación
- Google Sign-In y Apple Sign-In
- Sistema de sesiones con timeout (30 min)
- Autenticación biométrica
- Sistema de invitaciones con deep links
- 2FA opcional
- Auditoría de accesos

**Problemas encontrados:**

#### 1. **Sistema de sesiones bien implementado pero aislado** ⭐ (PUNTO POSITIVO)
- ✅ `SesionService` bien estructurado con singleton
- ✅ Timeout de 30 minutos configurable
- ✅ Refresh de token al volver de background
- ✅ Gestión correcta de lifecycle
- ⚠️ Pero: expone callback mutable `onSesionExpirada` (riesgo de memory leak)

#### 2. **Sin rate limiting en login** 🔴 CRÍTICO
```dart
// ❌ Cualquiera puede intentar 1000 logins/segundo
await FirebaseAuth.instance.signInWithEmailAndPassword(email, password);
```

**Solución:** Implementar `FuerzaBrutaService` (ya existe pero no se usa):
```dart
if (await FuerzaBrutaService().bloqueado(email)) {
  throw Exception('Demasiados intentos. Inténtalo en 15 minutos');
}
```

#### 3. **Tokens almacenados sin cifrar en SharedPreferences** 🔴 CRÍTICO
```dart
// ❌ En app_config_service.dart
await _prefs.setString('firebase_token', token);
```

**Solución:** Usar `flutter_secure_storage`:
```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'firebase_token', value: token);
```

#### 4. **Auditoría incompleta**
- ✅ Hay `AuditoriaService`
- ❌ Pero no registra todos los eventos críticos:
  - Cambios de contraseña
  - Cambios de permisos
  - Acceso a datos sensibles (nóminas, facturas)

**Gravedad:** MEDIA-ALTA  
**Prioridad:** ALTA  
**Complejidad:** MEDIA  
**Riesgo si no se corrige:** Brechas de seguridad, ataques de fuerza bruta exitosos

**Recomendaciones:**
1. ✅ Mantener arquitectura de `SesionService`
2. 🔧 Implementar rate limiting real (conectar con Cloud Functions)
3. 🔧 Migrar tokens a secure storage
4. 🔧 Completar auditoría de eventos

---

### MÓDULO: Facturación y VeriFactu

**Objetivo:**  
Gestionar el ciclo completo de facturación con cumplimiento normativo (VeriFactu, Art. 15 RD 1619/2012).

**Cómo funciona actualmente:**
- `FacturacionService` (1,192 líneas) gestiona TODO
- Series de facturas: FAC, RECT, PROF
- Validación fiscal integral (R1-R9)
- Registro en VeriFactu automático
- Cálculo de IVA, IRPF, recargo equivalencia
- Facturascativas según normativa
- Mod. 303, 111 integrados

**Problemas encontrados:**

#### 1. **Lógica fiscal EXCELENTE** ⭐⭐⭐ (PUNTO MUY POSITIVO)
- ✅ Validación fiscal completa (`ValidadorFiscalIntegral`)
- ✅ VeriFactu bien implementado con hash chain
- ✅ Rectificativas según Art. 15
- ✅ Correlatividad de facturas validada
- ✅ Tests de validación fiscal

**Esto es oro puro — mantener y proteger**

#### 2. **Servicio GOD OBJECT** 🔴 CRÍTICO
1,192 líneas que hacen:
- Crear facturas
- Editar facturas
- Anular facturas
- Crear rectificativas
- Crear proformas
- Convertir proformas
- Duplicar facturas
- Generar números de serie
- Cálculo de impuestos
- Mod. 303, 111
- Estadísticas
- Historial por cliente
- Detección de vencidas

**Solución:** Dividir en Use Cases:
- `CrearFacturaUseCase`
- `EditarFacturaUseCase`
- `CrearRectificativaUseCase`
- `CalcularMod303UseCase`
- `ObtenerEstadisticasQuery`

#### 3. **Transacciones débiles** 🔴 CRÍTICO
```dart
// ❌ Esto NO es atómico:
final numero = await _generarNumeroFacturaSerie(empresaId, serie);
// ... Si falla aquí, el número ya se consumió
await docRef.set(factura.toFirestore());
```

**Solución:** Usar runTransaction para todo:
```dart
await _firestore.runTransaction((tx) async {
  final numero = await _generarNumero(empresaId, serie, tx);
  final factura = Factura(..., numeroFactura: numero);
  tx.set(docRef, factura.toFirestore());
});
```

#### 4. **Criterio IVA mal aplicado** 🟠 ALTO
```dart
// ⚠️ El criterio IVA se lee en CADA query
final criterio = await obtenerCriterioIVA(empresaId);
```

**Solución:** Cachear a nivel de empresa:
```dart
class EmpresaConfig {
  final CriterioIVA criterioIVA; // ← Mantener en memoria
}
```

**Gravedad:** ALTA  
**Prioridad:** MEDIA (el módulo funciona, pero no escala)  
**Complejidad:** ALTA  
**Riesgo si no se corrige:** Performance horrible con >10.000 facturas/año

**Recomendaciones:**
1. ✅ **MANTENER** lógica fiscal (es excelente)
2. 🔧 Dividir servicio en Use Cases
3. 🔧 Reforzar transacciones atómicas
4. 🔧 Implementar caché de configuración fiscal

---

### MÓDULO: Nóminas y Seguridad Social

**Objetivo:**  
Calcular nóminas con normativa 2026 (SS, IRPF, convenios colectivos).

**Cómo funciona actualmente:**
- `NominasService` (1,458 líneas)
- Cotizaciones SS 2026 correctas
- IRPF progresivo con tramos autonómicos
- Convenios colectivos de Guadalajara y Cuenca
- Cálculo de embargos salariales
- Pluses, complementos, horas extra
- PDF de nóminas

**Problemas encontrados:**

#### 1. **Cálculos fiscales EXCELENTES** ⭐⭐⭐ (PUNTO MUY POSITIVO)
- ✅ Tipos SS 2026 correctos (MEI incluido)
- ✅ IRPF progresivo bien implementado
- ✅ Reducción por rendimientos del trabajo
- ✅ 9 convenios colectivos incluidos
- ✅ Embargos según tabla actualizada

**Esto es un tesoro — inversión brutal de conocimiento fiscal**

#### 2. **Servicio GOD OBJECT (otra vez)** 🔴 CRÍTICO
1,458 líneas que hacen:
- Calcular cotizaciones SS
- Calcular IRPF
- Validar convenios
- Calcular embargos
- Generar PDFs
- Contabilizar costes
- Gestionar ausencias
- Calcular vacaciones
- ...

**Solución (igual que facturación):** Dividir en Use Cases

#### 3. **Hardcoded valores fiscales** 🟠 ALTO
```dart
// ⚠️ ¿Qué pasa cuando cambie el SMI en 2027?
static const double _smiAnual2026 = 15876.0;

// ⚠️ ¿Y cuando suban los tipos de SS?
static const double _ssCC = 4.70;
```

**Solución:** Configuración externa:
```dart
// Firestore: /configuracion/fiscal/2026
{
  "smi_anual": 15876.0,
  "ss_contingencias_comunes_trabajador": 4.70,
  "ss_contingencias_comunes_empresa": 23.60,
  // ...
}

// O mejor: Cloud Function que actualiza automáticamente desde API del BOE
```

#### 4. **Sin tests de nóminas reales** 🟠 ALTO
- ✅ Hay `nominas_service_test.dart`
- ❌ Pero no testea casos reales completos:
  - Nómina con embargos
  - Nómina con pluses variables
  - Nómina con horas extra
  - Nómina con baja IT

**Gravedad:** MEDIA  
**Prioridad:** MEDIA  
**Complejidad:** ALTA (los cálculos son complejos)  
**Riesgo si no se corrige:** Errores de cálculo en producción (multas de Inspección de Trabajo)

**Recomendaciones:**
1. ✅ **MANTENER** lógica fiscal (es excelente)
2. 🔧 Externalizar valores fiscales a configuración
3. 🔧 Dividir servicio en calculadoras específicas
4. 🔧 Completar test suite con casos reales

---

### MÓDULO: TPV (Punto de Venta)

**Objetivo:**  
Sistema TPV para hostelería, comercio y peluquería con venta rápida, gestión de stock y facturación.

**Cómo funciona actualmente:**
- `TpvBarCobro`, `TpvBarMejoras` widgets con lógica
- Cierre de caja
- Impresora Bluetooth térmica
- Escaneo de códigos de barras

**Problemas encontrados:**

#### 1. **Lógica de negocio EN WIDGETS** 🔴🔴 CATASTRÓFICO
```dart
// ❌ lib/features/tpv/widgets/tpv_bar_cobro.dart (línea 364)
// 200+ líneas de lógica de negocio DENTRO de onPressed()
final db = FirebaseFirestore.instance;
await db.collection('empresas').doc(empresaId).collection('ventas').add({...});
// Actualizar stock
for (final linea in lineas) {
  await db.collection('empresas').doc(empresaId).collection('productos').doc(linea.id).update({...});
}
// Crear factura
await FacturacionService().crearFactura(...);
// Registrar en caja
await db.collection('empresas').doc(empresaId).collection('cajas').doc(cajaId).update({...});
```

**Esto es HORRIBLE porque:**
- Imposible testear
- Transacciones no atómicas (puede quedar inconsistente)
- Código duplicado
- Viola todos los principios SOLID

**Solución:** Extraer a `RegistrarVentaUseCase` (ver problema #7)

#### 2. **Sin manejo de red offline** 🔴 CRÍTICO
El TPV requiere conexión constante:
- ❌ Si se cae WiFi/4G → TPV inoperativo
- ❌ No hay modo offline
- ❌ No hay cola de reintentos

**Solución:** Implementar offline-first:
```dart
class OfflineVentaQueue {
  final Box<VentaPendiente> _box; // Hive local
  
  Future<void> registrarVenta(Venta venta) async {
    // Guardar en cola local
    await _box.add(VentaPendiente(venta));
    
    // Intentar sincronizar inmediatamente
    await _sincronizar();
  }
  
  Future<void> _sincronizar() async {
    if (!await _hayConexion()) return;
    
    final pendientes = _box.values.toList();
    for (final venta in pendientes) {
      try {
        await _subirAFirestore(venta);
        await _box.delete(venta.key);
      } catch (e) {
        // Dejarlo en cola para más tarde
      }
    }
  }
}
```

#### 3. **Sin control de caja real** 🟠 ALTO
- ✅ Hay `CierreCajaService`
- ❌ Pero no valida descuadres
- ❌ No hay alertas de diferencias
- ❌ No hay auditoría de quién abrió/cerró

**Gravedad:** CRÍTICA  
**Prioridad:** URGENTE  
**Complejidad:** ALTA  
**Riesgo si no se corrige:** TPV HOY con pérdida de ventas, descuadres de caja

**Recomendaciones:**
1. 🔧 **URGENTE:** Extraer lógica de negocio de widgets
2. 🔧 **CRÍTICO:** Implementar modo offline
3. 🔧 Mejorar control de caja con auditoría

---

### MÓDULO: Datos de Prueba / Demo

**Objetivo:**  
Crear cuentas demo con datos realistas para onboarding de nuevos clientes.

**Cómo funciona actualmente:**
- `demo_cuenta_service.dart` (1,118 líneas)
- Crea empresa demo completa con:
  - Empleados
  - Clientes
  - Facturas
  - Pedidos
  - Reservas
  - Valoraciones
  - Contenido web

**Problemas encontrados:**

#### 1. **Servicio MONSTRUOSO** 🔴 CRÍTICO
1,118 líneas que crean TODO en un solo método gigante.

#### 2. **Datos hardcoded** 🟠 MEDIO
```dart
// ❌ Los clientes demo están hardcoded en el código
final clientesDemo = [
  {'nombre': 'María García', 'telefono': '666555444', ...},
  {'nombre': 'Carlos López', 'telefono': '677888999', ...},
];
```

**Solución:** Externalizar a JSON:
```json
// assets/data/clientes_demo.json
[
  {"nombre": "María García", "telefono": "666555444", ...},
  {"nombre": "Carlos López", "telefono": "677888999", ...}
]
```

#### 3. **Sin cleanup** 🟠 MEDIO
- ✅ Crea datos demo
- ❌ No hay forma de borrar cuenta demo
- ❌ No hay TTL en datos demo

**Gravedad:** MEDIA  
**Prioridad:** BAJA (funciona, pero es feo)  
**Complejidad:** MEDIA  
**Riesgo si no se corrige:** Mantenimiento difícil, código ilegible

---

### MÓDULO: Clientes CRM

**Objetivo:**  
Gestión de clientes con etiquetas, filtros, interacciones y seguimiento.

**Cómo funciona actualmente:**
- `ClientesService` (300 líneas) — tamaño razonable ✅
- Etiquetas predefinidas + custom
- Filtros locales (nombre, facturación, actividad)
- Sistema de interacciones
- Upsert desde reservas

**Problemas encontrados:**

#### 1. **Filtrado EN MEMORIA** 🔴 CRÍTICO para escala
```dart
// ❌ Esto trae TODOS los clientes y filtra en memoria
static List<QueryDocumentSnapshot> filtrarClientes({
  required List<QueryDocumentSnapshot> docs, // ← YA traídos de Firestore
  String textoBusqueda = '',
  Set<String> etiquetasActivas = const {},
  double? minFacturacion,
}) {
  return docs.where((doc) {
    // Filtrado en memoria...
  }).toList();
}
```

**Consecuencias:**
- Con 10.000 clientes: traes 10.000 documentos para mostrar 10
- Pagas por 10.000 reads
- Tardas 5-10 segundos
- Consumes 5MB de datos

**Solución:** Usar Firestore queries + paginación:
```dart
Query<Map<String, dynamic>> _buildQuery({
  required String empresaId,
  Set<String> etiquetas = const {},
  double? minFacturacion,
  int limit = 50,
}) {
  var query = _clientes(empresaId).where('activo', isEqualTo: true);
  
  if (etiquetas.isNotEmpty) {
    query = query.where('etiquetas', arrayContainsAny: etiquetas.toList());
  }
  
  if (minFacturacion != null) {
    query = query.where('total_gastado', isGreaterThanOrEqualTo: minFacturacion);
  }
  
  return query.orderBy('nombre').limit(limit);
}
```

#### 2. **Sin búsqueda full-text** 🟠 ALTO
```dart
// ❌ Búsqueda manual con contains()
if (!nombre.contains(q) && !tel.contains(q) && !correo.contains(q)) {
  return false;
}
```

**Solución:** Integrar Algolia o Typesense:
```dart
class AlgoliaClienteRepository implements ClienteRepository {
  final AlgoliaClient _algolia;
  
  Future<List<Cliente>> buscar(String query) async {
    final results = await _algolia.search(query, hitsPerPage: 50);
    return results.hits.map((h) => Cliente.fromJson(h.data)).toList();
  }
}
```

**Gravedad:** ALTA  
**Prioridad:** MEDIA  
**Complejidad:** MEDIA  
**Riesgo si no se corrige:** Performance terrible con >1000 clientes

**Recomendaciones:**
1. 🔧 Migrar filtros a Firestore queries
2. 🔧 Implementar paginación
3. 🔧 Integrar búsqueda full-text (Algolia)

---

### MÓDULO: Base de Datos y Firestore

**Objetivo:**  
Persistencia de datos con Firestore.

**Problemas encontrados:**

#### 1. **Acceso directo SIN Repository** 🔴 CRÍTICO (ya cubierto)

#### 2. **Estructura de datos NO NORMALIZADA** 🟠 ALTO
```dart
// ❌ Datos duplicados por todos lados
// Factura duplica info del cliente:
{
  "cliente_nombre": "María García",
  "cliente_telefono": "666555444",
  "cliente_correo": "maria@example.com",
}

// Cliente también tiene estos datos:
/empresas/{id}/clientes/{id}
{
  "nombre": "María García",
  "telefono": "666555444",
  "correo": "maria@example.com",
}
```

**Consecuencias:**
- Si María cambia su teléfono → hay que actualizar 50 facturas
- Facturamos a "María Garcia" (sin acento) → no encontramos su historial
- Datos inconsistentes

**Solución (difícil en Firestore):**
Opción 1: **Denormalizar pero con IDs de referencia**
```dart
{
  "cliente_id": "abc123", // ← ID del documento cliente
  "cliente_nombre_snap": "María García", // ← Snapshot para búsquedas rápidas
  "cliente_telefono_snap": "666555444",
}
```

Opción 2: **Migrar relaciones a PostgreSQL** (como en `billing_service`)

#### 3. **Sin validación de esquema** 🟠 ALTO
```dart
// ❌ Cualquiera puede escribir cualquier cosa:
await _firestore.collection('empresas').doc(id).set({
  'nombre': 123, // ⚠️ Se espera String pero se guarda int
  'sector': null, // ⚠️ Se espera String pero es null
});
```

**Solución:** Firestore no tiene schemas, pero puedes validar en código:
```dart
class Empresa {
  final String nombre;
  final String sector;
  
  Empresa({required this.nombre, required this.sector}) {
    if (nombre.isEmpty) throw ValidationError('Nombre obligatorio');
    if (sector.isEmpty) throw ValidationError('Sector obligatorio');
  }
  
  Map<String, dynamic> toFirestore() => {
    'nombre': nombre,
    'sector': sector,
  };
  
  factory Empresa.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Empresa(
      nombre: data['nombre'] as String? ?? '',
      sector: data['sector'] as String? ?? '',
    );
  }
}
```

**Gravedad:** ALTA  
**Prioridad:** MEDIA  
**Complejidad:** ALTA  
**Riesgo si no se corrige:** Datos inconsistentes, bugs difíciles de debugar

---

### MÓDULO: Billing Service (Servicio Externo)

**Objetivo:**  
Servicio independiente para procesamiento de pagos (Stripe, Redsys, PSD2).

**Cómo funciona actualmente:**
- Servidor Dart independiente en `/billing_service`
- PostgreSQL para persistencia
- Multi-tenant
- Proveedores: Stripe, Redsys, PSD2 (varios bancos)
- Idempotencia con retry queue
- Circuit breaker para APIs externas

**Análisis:**

#### 1. **ARQUITECTURA EXCELENTE** ⭐⭐⭐⭐ (PUNTO MUY POSITIVO)
- ✅ Servicio separado (microservicio)
- ✅ PostgreSQL (mejor que Firestore para transacciones)
- ✅ Repository Pattern implementado
- ✅ Interfaces para payment providers
- ✅ Circuit Breaker para resiliencia
- ✅ Idempotency keys
- ✅ Retry queue
- ✅ Multi-tenant bien diseñado
- ✅ Encriptación de credenciales

**Este servicio es un EJEMPLO de cómo debería ser el resto de la app**

#### 2. **Problema: NO ESTÁ INTEGRADO CON LA APP PRINCIPAL** 🟠 ALTO
- ❌ El servicio está en el repo pero **NO SE USA**
- ❌ La app principal NO hace llamadas a este servicio
- ❌ Hay un `StripeService` en la app principal que es básico

**Solución:** Integrar realmente:
```dart
class PagosRepository {
  final Dio _httpClient;
  final String _billingServiceUrl = 'https://billing.fluixcrm.com';
  
  Future<ResultadoPago> procesarPago({
    required String empresaId,
    required double monto,
    required MetodoPago metodo,
  }) async {
    final response = await _httpClient.post(
      '$_billingServiceUrl/api/v1/payments',
      data: {
        'tenant_id': empresaId,
        'amount': monto,
        'method': metodo.name,
      },
      options: Options(headers: {
        'Authorization': 'Bearer ${await _getToken()}',
        'X-Idempotency-Key': Uuid().v4(),
      }),
    );
    
    return ResultadoPago.fromJson(response.data);
  }
}
```

**Gravedad:** MEDIA  
**Prioridad:** MEDIA  
**Complejidad:** BAJA (el servicio ya existe, solo hay que conectarlo)  
**Riesgo si no se corrige:** Funcionalidad de pagos limitada, no se aprovecha el billing service

---

## PROBLEMAS TRANSVERSALES

### 1. **Sin Clean Architecture** 🔴
- ✅ Hay `/domain`, `/features`
- ❌ Pero la separación es NOMINAL, no real:
  - Widgets llaman directamente a Firestore
  - Servicios mezclan lógica de negocio con infraestructura
  - No hay contratos (interfaces) para repositories

**Solución:** Aplicar capas reales:
```
lib/
├── domain/               # ← PURO (sin dependencias externas)
│   ├── entidades/
│   ├── value_objects/
│   ├── repositorios/     # ← INTERFACES
│   └── casos_uso/
├── aplicacion/           # ← Orquestación
│   ├── comandos/
│   ├── queries/
│   └── servicios_app/
├── infraestructura/      # ← Implementaciones
│   ├── firestore/
│   │   └── repositories/
│   ├── http/
│   └── storage/
└── presentacion/         # ← UI
    ├── pantallas/
    ├── widgets/
    └── providers/
```

### 2. **Sin CI/CD real** 🔴
- ✅ Hay `codemagic.yaml`
- ❌ Pero no hay:
  - Tests automáticos en PRs
  - Despliegue automático a TestFlight/Play Store
  - Checks de calidad de código
  - Análisis de seguridad

**Solución:** Configurar GitHub Actions o Codemagic completo:
```yaml
name: CI/CD Pipeline

on:
  pull_request:
  push:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
      
  deploy-ios:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - run: flutter build ios --release
      - run: fastlane ios beta
      
  deploy-android:
    if: github.ref == 'refs/heads/main'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: flutter build appbundle --release
      - run: fastlane android beta
```

### 3. **Sin versionado de APIs** 🟠
- ❌ Cloud Functions sin versionado
- ❌ Cambios en Firestore pueden romper apps antiguas

**Solución:**
```dart
// Cloud Functions con versión en URL
exports.v1_crearFactura = functions.https.onCall(async (data, context) => {
  return FacturacionService.crearFactura(data);
});

exports.v2_crearFactura = functions.https.onCall(async (data, context) => {
  return FacturacionServiceV2.crearFactura(data);
});

// En la app, detectar versión:
class ApiClient {
  final int apiVersion;
  
  Future<T> call(String endpoint, Map<String, dynamic> data) {
    final versionedEndpoint = 'v${apiVersion}_$endpoint';
    return _functions.httpsCallable(versionedEndpoint).call(data);
  }
}
```

---

## DEUDA TÉCNICA PRIORITARIA

### 🔴 **CRÍTICA — Resolver en 1-2 meses:**
1. Implementar Repository Pattern (4 semanas)
2. Dividir servicios GOD OBJECT en Use Cases (6 semanas)
3. Implementar DI real con GetIt (3 semanas)
4. Crear y desplegar Firestore Security Rules + tests (2 semanas)
5. Auditar y crear índices de Firestore (2 semanas)
6. Extraer lógica de negocio de widgets TPV (2 semanas)
7. Implementar modo offline para TPV (3 semanas)

### 🟠 **ALTA — Resolver en 3-6 meses:**
8. Implementar caché (3 semanas)
9. Manejo de errores centralizado (2 semanas)
10. Observabilidad completa (2 semanas)
11. Testing completo (4 semanas)
12. Migrar filtros de clientes a queries optimizadas (2 semanas)
13. Integrar billing service (2 semanas)

### 🟡 **MEDIA — Resolver en 6-12 meses:**
14. Refactorizar hacia Clean Architecture completo (8 semanas)
15. Implementar CI/CD completo (2 semanas)
16. Búsqueda full-text con Algolia (1 semana)
17. Versionado de APIs (1 semana)

**TOTAL ESTIMADO:** 47 semanas de trabajo especializado (1 dev senior full-time)

---

## ROADMAP RECOMENDADO DE MEJORAS

### ⏱️ **CORTO PLAZO (1-3 meses) — SUPERVIVENCIA**

**Objetivo:** Hacer la app viable para producción sin colapsar.

1. **Semana 1-2:** Firestore Security Rules + Tests
   - Crear `firestore.rules` + tests
   - Desplegar y validar
   - **ROI:** Evitar brechas de seguridad masivas

2. **Semana 3-4:** Auditoría y creación de índices Firestore
   - Documentar todas las queries
   - Crear `firestore.indexes.json`
   - Desplegar índices
   - **ROI:** App deja de crashear con datos reales

3. **Semana 5-8:** Repository Pattern básico
   - Crear interfaces en `/domain/repositorios`
   - Implementar FirestoreRepositories
   - Migrar 3-4 servicios críticos (Clientes, Facturas, Nóminas)
   - **ROI:** Código testeable, base para futuras mejoras

4. **Semana 9-12:** Dependency Injection real
   - Configurar GetIt
   - Migrar servicios a DI
   - Eliminar singletons manuales
   - **ROI:** Testing posible, flexibilidad arquitectónica

**Resultado:** App testeable, segura y que no se cae con >1000 documentos.

---

### 📈 **MEDIO PLAZO (3-6 meses) — PROFESIONALIZACIÓN**

**Objetivo:** Convertir la app en un producto enterprise real.

5. **Mes 4:** Dividir servicios GOD OBJECT
   - Refactorizar `FacturacionService` → Use Cases
   - Refactorizar `NominasService` → Use Cases
   - Refactorizar `DemoCuentaService` → Builders
   - **ROI:** Mantenibilidad, reducción de bugs

6. **Mes 5:** Observabilidad y manejo de errores
   - Implementar `AppLogger` centralizado
   - Configurar Crashlytics correctamente
   - Performance monitoring
   - Error tracking
   - **ROI:** Debugging fácil, métricas de negocio

7. **Mes 6:** Testing completo
   - Tests unitarios de Use Cases
   - Tests de integración con Firestore Emulator
   - Tests de seguridad (Rules)
   - Objetivo: >60% cobertura
   - **ROI:** Confianza para refactorizar, menos bugs

**Resultado:** App mantenible, observable y con test coverage aceptable.

---

### 🚀 **LARGO PLAZO (6-12 meses) — EXCELENCIA**

**Objetivo:** App de clase mundial, escalable a 10.000+ empresas.

8. **Mes 7-8:** Clean Architecture completa
   - Separación real de capas
   - Domain puro sin dependencias
   - Inversión de dependencias
   - **ROI:** Arquitectura sostenible a largo plazo

9. **Mes 9:** Caché y performance
   - Implementar caché multi-capa
   - Optimizar queries más usadas
   - Lazy loading en listas
   - **ROI:** App 5x más rápida, costes -70%

10. **Mes 10:** Offline-first
    - TPV funcional sin conexión
    - Cola de sincronización
    - Conflict resolution
    - **ROI:** Experiencia perfecta, no más "sin internet"

11. **Mes 11-12:** CI/CD y DevOps
    - Pipeline completo de despliegue
    - Feature flags
    - A/B testing
    - Monitorización avanzada
    - **ROI:** Despliegues seguros, iteración rápida

**Resultado:** Aplicación de clase enterprise, escalable, mantenible y con desarrollo ágil.

---

## TOP 10 MEJORAS CON MAYOR ROI

| # | Mejora | Esfuerzo | ROI | Impacto |
|---|--------|----------|-----|---------|
| 1 | **Firestore Security Rules** | 2 sem | 🔥🔥🔥🔥🔥 | Evita brechas de seguridad masivas |
| 2 | **Índices Firestore** | 2 sem | 🔥🔥🔥🔥🔥 | App deja de crashear con datos reales |
| 3 | **Repository Pattern** | 4 sem | 🔥🔥🔥🔥 | Código testeable + flexible |
| 4 | **Extraer lógica de widgets TPV** | 2 sem | 🔥🔥🔥🔥 | TPV testeable + sin bugs |
| 5 | **Dependency Injection** | 3 sem | 🔥🔥🔥🔥 | Testing posible |
| 6 | **Modo offline TPV** | 3 sem | 🔥🔥🔥🔥 | TPV no se cae sin internet |
| 7 | **Caché** | 3 sem | 🔥🔥🔥 | -70% costes Firestore, +5x velocidad |
| 8 | **Observabilidad** | 2 sem | 🔥🔥🔥 | Debugging fácil, conocer producción |
| 9 | **Manejo errores centralizado** | 2 sem | 🔥🔥🔥 | UX mejor, debugging más fácil |
| 10 | **Testing** | 4 sem | 🔥🔥 | Confianza, menos bugs |

---

## VEREDICTO FINAL

### ¿ES VIABLE ESTE PROYECTO?

**SÍ, PERO CON URGENCIA CRÍTICA**.

Esta aplicación tiene **fundamentos excelentes**:
- ✅ Lógica fiscal avanzada (VeriFactu, nóminas, impuestos)
- ✅ Funcionalidades completas (CRM, TPV, facturación, reservas, valoraciones)
- ✅ Billing service bien arquitectado
- ✅ Amplio ecosistema de features

Pero sufre de **antipatrones masivos** que la hacen **insostenible**:
- 🔴 Arquitectura caótica (acceso directo a Firestore, servicios GOD OBJECT)
- 🔴 Seguridad comprometida (sin rules, sin rate limiting)
- 🔴 Performance terrible (sin índices, sin caché, filtros en memoria)
- 🔴 Testing insuficiente (imposible refactorizar con confianza)
- 🔴 Observabilidad inexistente (debugging imposible en producción)

### COMPARACIÓN CON LA COMPETENCIA

| Dimensión | Fluix CRM | Holded | QuickBooks | Estado |
|-----------|-----------|--------|------------|--------|
| Funcionalidades fiscales | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | MEJOR |
| Arquitectura | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | MUCHO PEOR |
| Performance | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | PEOR |
| Seguridad | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | MUCHO PEOR |
| UX | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ACEPTABLE |
| Escalabilidad | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | MUCHO PEOR |

**Conclusión:** Funcionalidades de nivel top, pero arquitectura de nivel junior.

---

### RECOMENDACIÓN ACCIONABLE

Si fuera CTO de esta empresa, haría esto **INMEDIATAMENTE**:

1. **STOP a nuevas features** por 2 meses
2. **Contratar 1 arquitecto senior** para liderar refactorización
3. **Ejecutar roadmap corto plazo** (Security Rules, índices, Repository Pattern, DI)
4. **Auditar producción** (¿hay datos comprometidos por falta de rules?)
5. **Plan de comunicación a clientes** (sobre mejoras de seguridad)

**Inversión necesaria:** 100.000-150.000 € (2-3 devs senior × 6 meses)  
**Alternativa:** Reescribir desde cero (300.000-500.000 €, 12-18 meses)

**La refactorización es más barata y mantiene el tesoro fiscal que ya tienes.**

---

## PUNTOS FUERTES A PRESERVAR ⭐

A pesar de los problemas graves, hay **elementos excelentes** que deben protegerse:

1. **Lógica fiscal de VeriFactu y validación** — invertida muchísimas horas, funciona perfectamente
2. **Cálculos de nóminas con SS e IRPF 2026** — complejidad fiscal bien dominada
3. **Convenios colectivos integrados** — diferenciador competitivo
4. **Billing service bien arquitectado** — ejemplo a seguir para el resto
5. **Ecosistema amplio de features** — CRM, TPV, facturación, reservas, web, GMB

**Estos son activos de alto valor que justifican la inversión en refactorización.**

---

## CONCLUSIÓN

**Esta aplicación es un diamante en bruto.**

Tiene la lógica de negocio y el conocimiento fiscal de una joya, pero está envuelta en una arquitectura que la asfixia. Con una refactorización urgente y disciplinada, puede convertirse en un producto SaaS competitivo a nivel enterprise.

**Sin esa refactorización, colapsará bajo su propio peso en 6-12 meses.**

La decisión es clara: **invertir ahora en deuda técnica o pagar el precio después (reescritura completa)**.

---

**Fin del informe.**

_Elaborado por: Auditor Técnico Senior_  
_Fecha: 19 de Mayo de 2026_


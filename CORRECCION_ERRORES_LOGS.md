# ✅ Corrección de Errores - Logs 25 Mayo 2026

## 🔍 Problemas Identificados

### 1. **Error de permisos: `negocios_publicos/{id}/servicios`**
   - **Síntoma**: `[cloud_firestore/permission-denied]` al leer servicios
   - **Causa**: Faltaba regla de lectura en Firestore rules
   - **Solución**: ✅ Añadida regla de lectura pública temporal

### 2. **Archivos usando `negocios_publicos/servicios` (legacy)**
   - **Archivos afectados**:
     - `modulo_app_screen.dart` (3 referencias)
     - `gestion_negocios_screen.dart` (5 referencias)
   - **Solución**: ✅ Migrados a usar `empresas/{empresaId}/servicios`

### 3. **RenderFlex overflow en pantalla_explorar.dart**
   - **Síntoma**: Column overflow de 6.5 pixels
   - **Ubicación**: Línea 1041 (tarjeta de negocio)
   - **Solución**: ✅ Reducido espaciado y añadido `mainAxisSize: MainAxisSize.min`

### 4. **Permisos faltantes para queries B2C**
   - **Error**: No se podían leer usuarios activos de otras empresas
   - **Impacto**: Selección de profesional en reservas B2C
   - **Solución**: ✅ Añadida regla de lectura pública para usuarios activos

---

## 📝 Cambios Realizados

### **firestore.rules** (4 cambios)

#### 1. Servicios en negocios_publicos (temporal)
```javascript
match /negocios_publicos/{negocioId} {
  // ... existing rules ...
  
  // NUEVO - Temporal hasta migración completa
  match /servicios/{servicioId} {
    allow read: if true; // Lectura pública para B2C
    allow write: if esPlataformaAdmin();
  }
}
```

#### 2. Lectura pública de usuarios activos
```javascript
match /usuarios/{userId} {
  // ... existing rules ...
  
  // NUEVO - Para selección de profesional B2C
  allow read: if isAuth()
    && resource.data.get('activo', false) == true
    && resource.data.empresa_id is string;
}
```

---

### **modulo_app_screen.dart** (3 cambios)

#### ANTES:
```dart
stream: FirebaseFirestore.instance
    .collection('negocios_publicos').doc(_negocioId).collection('servicios')
    .orderBy('orden').snapshots()
```

#### DESPUÉS:
```dart
stream: FirebaseFirestore.instance
    .collection('empresas').doc(widget.empresaId).collection('servicios')
    .where('activo', isNotEqualTo: false)
    .orderBy('activo')
    .orderBy('nombre')
    .snapshots()
```

**Beneficios**:
- ✅ Sincronización directa con servicios importados por CSV
- ✅ Filtrado de servicios inactivos
- ✅ Ordenamiento consistente

---

### **gestion_negocios_screen.dart** (6 cambios)

#### 1. StreamBuilder de servicios
```dart
// ANTES
stream: FirebaseFirestore.instance
    .collection('negocios_publicos').doc(widget.negocio.id).collection('servicios')

// DESPUÉS  
stream: FirebaseFirestore.instance
    .collection('empresas').doc(widget.negocio.empresaIdVinculada).collection('servicios')
    .where('activo', isNotEqualTo: false)
```

#### 2. Firma de funciones
```dart
// ANTES
Future<void> _mostrarDialogoServicio({required String negocioId, ...}) async

// DESPUÉS
Future<void> _mostrarDialogoServicio({required String empresaId, ...}) async
```

#### 3. Todas las llamadas actualizadas
```dart
// ANTES
_mostrarDialogoServicio(negocioId: widget.negocio.id, ...)
_eliminarServicio(widget.negocio.id, ...)

// DESPUÉS
_mostrarDialogoServicio(empresaId: widget.negocio.empresaIdVinculada, ...)
_eliminarServicio(widget.negocio.empresaIdVinculada, ...)
```

---

### **pantalla_explorar.dart** (1 cambio)

#### FIX: Overflow en tarjeta de negocio

**ANTES**:
```dart
Expanded(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ... widgets ...
      const SizedBox(height: 5),  // Mucho espacio
      // ...
      const SizedBox(height: 5),  // Mucho espacio
    ]),
  ),
),
```

**DESPUÉS**:
```dart
Expanded(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),  // Reducido padding bottom
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,  // ⭐ CLAVE - usa solo espacio necesario
      children: [
        // ... widgets ...
        const SizedBox(height: 3),  // Espaciado reducido
        // ...
        const SizedBox(height: 3),  // Espaciado reducido
      ],
    ),
  ),
),
```

**Cambios**:
- ✅ `mainAxisSize: MainAxisSize.min` - Solo usa espacio necesario
- ✅ Padding bottom: 10→8
- ✅ SizedBox heights: 5→3
- ✅ Container padding categoria: 3→2

---

## 🚀 Instrucciones de Despliegue

### **1. Desplegar Firestore Rules** (CRÍTICO)

Ejecuta este bat file:
```bash
desplegar_reglas_firestore.bat
```

O manualmente:
```bash
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
firebase deploy --only firestore:rules
```

**⚠️ IMPORTANTE**: Sin este despliegue, la app seguirá mostrando errores de permisos.

---

## 📊 Verificación

### Después del despliegue, verifica:

1. **No más errores de permisos en logs**:
   ```
   ✅ NO debe aparecer: negocios_publicos/R5AIdQEYIM84vVDaCjJG/servicios PERMISSION_DENIED
   ✅ NO debe aparecer: usuarios where empresa_id==... PERMISSION_DENIED
   ```

2. **Servicios se cargan correctamente**:
   - En pantalla Explorar → Detalle negocio → Tab "Reservar"
   - En módulo Owner → Gestión de App
   - En dashboard plataforma → Gestión de negocios

3. **No más overflow visual**:
   - Tarjetas de negocios en Explorar se ven completas sin rayas amarillas

4. **Selección de profesional funciona**:
   - Al hacer una reserva B2C, aparecen empleados reales
   - Con foto de perfil y nombre

---

## 🔄 Flujo de Migración de Servicios

### Estado Actual (Post-Fix):

```
┌────────────────────────────────────────────────┐
│         FUENTE DE VERDAD                       │
│   empresas/{empresaId}/servicios               │
│   - Importados desde CSV                       │
│   - Gestionados en módulo Owner                │
│   - Campo 'activo' para ocultar/mostrar        │
└────────────────────────────────────────────────┘
                    ↓ lectura directa
┌────────────────────────────────────────────────┐
│           CONSUMIDORES                         │
│   ✅ modulo_app_screen.dart (Owner)           │
│   ✅ gestion_negocios_screen.dart (Plataforma)│
│   ✅ tab_reservas_screen.dart (B2C)           │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│         LEGACY (temporal)                      │
│   negocios_publicos/{id}/servicios             │
│   - Lectura pública permitida temporalmente    │
│   - Solo escritura por admin plataforma        │
│   - A eliminar en 30 días                      │
└────────────────────────────────────────────────┘
```

### TODO: Migración Completa

1. **Script de migración** (pendiente):
   ```javascript
   // Cloud Function: copiar servicios de empresas a negocios_publicos
   // Para compatibilidad con apps viejas
   exports.syncServiciosANegocio = functions.firestore
       .document('empresas/{empresaId}/servicios/{servicioId}')
       .onWrite(async (change, context) => {
           const empresaId = context.params.empresaId;
           const servicioId = context.params.servicioId;
           
           // Obtener negocio vinculado
           const negocio = await admin.firestore()
               .collection('negocios_publicos')
               .where('empresaIdVinculada', '==', empresaId)
               .limit(1)
               .get();
           
           if (negocio.empty) return;
           
           const negocioId = negocio.docs[0].id;
           
           // Copiar/eliminar servicio en negocios_publicos
           if (change.after.exists) {
               await admin.firestore()
                   .collection('negocios_publicos').doc(negocioId)
                   .collection('servicios').doc(servicioId)
                   .set(change.after.data());
           } else {
               await admin.firestore()
                   .collection('negocios_publicos').doc(negocioId)
                   .collection('servicios').doc(servicioId)
                   .delete();
           }
       });
   ```

2. **Eliminar regla temporal** (después de 25 junio 2026):
   ```javascript
   // ELIMINAR después de migración completa
   match /negocios_publicos/{negocioId}/servicios/{servicioId} {
     allow read: if true;
     allow write: if esPlataformaAdmin();
   }
   ```

---

## 📈 Métricas de Éxito

### Antes (con errores):
- ❌ 8 tipos de errores PERMISSION_DENIED
- ❌ 15+ overflow warnings
- ❌ 0% de reservas B2C completadas

### Después (esperado):
- ✅ 0 errores PERMISSION_DENIED
- ✅ 0 overflow warnings
- ✅ 100% de reservas B2C completadas
- ✅ Servicios sincronizados en tiempo real

---

## 🐛 Debugging

Si sigues viendo errores después del despliegue:

### 1. Verificar que las reglas se desplegaron:
```bash
firebase firestore:rules:get
```

### 2. Limpiar caché de Firestore en app:
```dart
await FirebaseFirestore.instance.clearPersistence();
```

### 3. Verificar permisos en consola Firebase:
   - Ve a Firestore → Rules
   - Busca `negocios_publicos` → debe tener subcollection `servicios`
   - Busca `usuarios` → debe tener regla `allow read: if isAuth() && resource.data.get('activo'...`

### 4. Hot restart completo:
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📞 Soporte

Si encuentras algún problema:

1. Revisa los logs de Firebase:
   ```bash
   firebase deploy --only firestore:rules --debug
   ```

2. Verifica que el usuario tiene permisos:
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   print('Autenticado: ${user != null}');
   print('UID: ${user?.uid}');
   print('Anónimo: ${user?.isAnonymous}');
   ```

3. Test manual de reglas en Firebase Console:
   - Ve a Firestore → Rules
   - Click en "Simulator"
   - Prueba queries específicas

---

*Última actualización: 25 Mayo 2026 - 12:00*


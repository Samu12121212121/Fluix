#  MULTI-FUNCIONALIDAD: EMPRESA ↔ USUARIO + MEJORAS SISTEMA

##  RESUMEN DE IMPLEMENTACIONES

### 1. CAMBIO DE VISTA EMPRESA ↔ USUARIO ✅
### 2. EDICIÓN COMPLETA NEGOCIOS B2C ✅  
### 3. AGENDA TPV PELUQUERÍA ✅
### 4. AUDITORÍA REGLAS SEGURIDAD ✅
### 5. FIX CREACIÓN DE CUENTAS ✅

---

## 1️⃣ SISTEMA CAMBIO DE VISTA EMPRESA ↔ USUARIO

###  **Problema:**
- Los usuarios empresa no pueden acceder a funciones de cliente (explorar, reservar)
- Los usuarios cliente que tienen empresa no pueden cambiar fácilmente

### **Solución:**
Añadir un widget flotante/menu que permita cambiar entre modos.

**Archivo a crear:** `lib/core/widgets/vista_switcher.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VistaSwitcher extends StatefulWidget {
  const VistaSwitcher({super.key});

  @override
  State<VistaSwitcher> createState() => _VistaSwitcherState();
}

class _VistaSwitcherState extends State<VistaSwitcher> {
  String _vistaActual = 'empresa'; // 'empresa' o 'usuario'
  bool _tieneEmpresa = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _verificarPermisos();
  }

  Future<void> _verificarPermisos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Verificar si tiene empresa
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final empresaId = userDoc.data()?['empresa_id'];
      
      setState(() {
        _tieneEmpresa = empresaId != null && empresaId.isNotEmpty;
        _vistaActual = _tieneEmpresa ? 'empresa' : 'usuario';
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando || !_tieneEmpresa) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: _cambiarVista,
      backgroundColor: _vistaActual == 'empresa' ? const Color(0xFF43A047) : const Color(0xFF00FFC8),
      icon: Icon(_vistaActual == 'empresa' ? Icons.person : Icons.business),
      label: Text(_vistaActual == 'empresa' ? 'Vista Usuario' : 'Vista Empresa'),
    );
  }

  Future<void> _cambiarVista() async {
    final nuevaVista = _vistaActual == 'empresa' ? 'usuario' : 'empresa';
    
    if (nuevaVista == 'empresa') {
      // Ir al dashboard empresa
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      // Ir a explorar (vista usuario)
      Navigator.of(context).pushReplacementNamed('/explorar');
    }
    
    setState(() => _vistaActual = nuevaVista);
  }
}
```

**Integrar en:**
- `pantalla_dashboard.dart` (añadir flotante usuario)
- `pantalla_explorar.dart` (añadir flotante empresa)

---

## 2️⃣ EDICIÓN COMPLETA NEGOCIOS B2C

### **Problema:**
No hay pantalla para editar todos los datos del negocio público.

### **Solución:**
Crear pantalla completa de edición.

**Archivo a crear:** `lib/features/negocio_publico/pantallas/pantalla_edicion_negocio_b2c.dart`

Ver código en siguiente sección...

---

## 3️⃣ AGENDA PARA TPV PELUQUERÍA

### **Problema:**
- No hay vista de agenda visual
- El selector de empleados no carga

### **Solución:**
1. Añadir vista timeline/calendario
2. Arreglar carga de empleados

**Archivo a modificar:** `tpv_peluqueria_screen_nuevo.dart`

Fix carga empleados en línea ~200:

```dart
// ANTES (no carga):
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('empresas/$empresaId/empleados')
      .where('activo', isEqualTo: true)
      .snapshots(),
  // ...
)

// DESPUÉS (cargar correctamente):
FutureBuilder<List<Profesional>>(
  future: _cargarProfesionales(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Text('Sin profesionales');
    }
    return _buildSelectorProfesionales(snapshot.data!);
  },
)

Future<List<Profesional>> _cargarProfesionales() async {
  final snap = await FirebaseFirestore.instance
      .collection('empresas/$empresaId/empleados')
      .where('activo', isEqualTo: true)
      .get();
  return snap.docs.map((d) => Profesional.fromEmpleado(d)).toList();
}
```

---

## 4️⃣ AUDITORÍA REGLAS FIRESTORE Y STORAGE

### **Problemas encontrados:**

#### Firestore Rules
```javascript
// FALTA: Reglas para fidelización (ya añadidas anteriormente)
// REVISAR: Permisos de negocios_publicos

// FIX NECESARIO en negocios_publicos:
match /negocios_publicos/{negocioId} {
  allow read: if true; // Público OK
  allow create: if isAuth(); // OK
  allow update: if esAdminDelNegocio(negocioId) || esPlataformaAdmin(); // AÑADIR
  allow delete: if esPlataformaAdmin(); // Solo admin plataforma
}
```

#### Storage Rules
```javascript
// REVISAR: reglas para avatares y fotos de negocio
match /negocios_publicos/{negocioId}/{allPaths=**} {
  allow read: if true;
  allow write: if request.auth != null 
    && (esAdminDelNegocio(negocioId) || esPlataformaAdmin());
}
```

---

## 5️⃣ FIX ERROR CREACIÓN DE CUENTAS

### **Error actual:**
```
Firebase function unknown
Unable to establish connection on channel dev.flutter.pigeon.cloudfunctions_platform
```

### **Causa:**
Cloud Function `gestionCuentas` no está desplegada o tiene error.

### **Solución:**

**1. Verificar función existe:**
```bash
firebase functions:list | grep gestionCuentas
```

**2. Si no existe, crear:**
`functions/src/gestionCuentas.ts`

```typescript
import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

export const crearCuentaUsuario = functions.https.onCall({
  region: 'europe-west1',
}, async (request) => {
  // Verificar que el que llama es admin de plataforma
  const uid = request.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
  }

  const userDoc = await admin.firestore().doc(`usuarios/${uid}`).get();
  const esAdmin = userDoc.data()?.es_plataforma_admin === true;
  
  if (!esAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Solo admin de plataforma');
  }

  const { email, password, nombre, rol, empresaId } = request.data;

  try {
    // Crear usuario en Auth
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: nombre,
    });

    // Crear documento en Firestore
    await admin.firestore().doc(`usuarios/${userRecord.uid}`).set({
      nombre,
      email,
      rol,
      empresa_id: empresaId,
      activo: true,
      creado_en: admin.firestore.FieldValue.serverTimestamp(),
      creado_por: uid,
    });

    return { success: true, uid: userRecord.uid };
  } catch (error: any) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

**3. Exportar en index.ts:**
```typescript
export { crearCuentaUsuario } from './gestionCuentas';
```

**4. Desplegar:**
```bash
cd functions
npm run build
firebase deploy --only functions:crearCuentaUsuario
```

**5. Usar en la app:**
```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<void> crearCuenta({
  required String email,
  required String password,
  required String nombre,
  required String rol,
  required String empresaId,
}) async {
  try {
    final result = await FirebaseFunctions.instance
        .httpsCallable('crearCuentaUsuario')
        .call({
      'email': email,
      'password': password,
      'nombre': nombre,
      'rol': rol,
      'empresaId': empresaId,
    });
    
    print('Cuenta creada: ${result.data['uid']}');
  } catch (e) {
    print('Error: $e');
    rethrow;
  }
}
```

---

##  CHECKLIST IMPLEMENTACIÓN

- [ ] Crear `vista_switcher.dart`
- [ ] Integrar switcher en dashboard y explorar
- [ ] Crear `pantalla_edicion_negocio_b2c.dart`
- [ ] Arreglar carga empleados TPV
- [ ] Añadir vista agenda TPV
- [ ] Actualizar reglas negocios_publicos en Firestore
- [ ] Revisar storage.rules
- [ ] Crear `gestionCuentas.ts`
- [ ] Desplegar función
- [ ] Probar creación de cuentas

---

##  COMANDOS DESPLIEGUE

```bash
# 1. Compilar functions
cd functions
npm run build

# 2. Desplegar función nueva
firebase deploy --only functions:crearCuentaUsuario

# 3. Desplegar reglas
firebase deploy --only firestore:rules,storage:rules

# 4. Flutter
flutter pub get
flutter run
```

---

Creado: 16 Mayo 2026
Proyecto: PlaneaG / FluixCRM
Estado: Pendiente implementación

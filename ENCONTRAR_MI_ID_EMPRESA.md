# 🔑 CÓMO ENCONTRAR TU ID DE EMPRESA

## 3 FORMAS RÁPIDAS

### **FORMA 1: Firebase Console (Más visual)** ⭐

1. Abre: https://console.firebase.google.com
2. Selecciona proyecto: `planeaapp-4bea4`
3. Ve a: **Firestore Database** (en el menú izquierdo)
4. Verás: **Colección `empresas`**
5. Tus documentos aparecen así:

```
empresas/
├─ tu_id_aqui_12345 ← Este es tu ID
├─ otro_id_67890
└─ ...
```

Copia exactamente tu ID (sin espacios).

---

### **FORMA 2: En tu App Flutter** 

Si tienes acceso al código, añade esto en algún lugar:

```dart
import 'package:firebase_auth/firebase_auth.dart';

void mostrarMiId() {
  final user = FirebaseAuth.instance.currentUser;
  print('📍 Mi ID: ${user?.uid}');
}
```

Ejecuta y mira la consola.

---

### **FORMA 3: En la App (UI)**

Si tu app tiene un panel de administración:
- Ve a: **Configuración** o **Mi Perfil**
- Busca: "ID de empresa" o "Código único"
- Ahí está tu ID

---

## ❌ NO USES ESTOS

**Estos IDs son de OTRAS empresas:**
- ❌ `ztZblwm1w71wNQtzHV7S` (Fluixtech - ejemplo)
- ❌ `damajuana123` (otro ejemplo)

**USA TU ID REAL que encontraste arriba.**

---

## 📝 UNA VEZ LO TENGAS

Guarda tu ID en un lugar seguro:

```
Mi ID de Empresa: _______________________
                  ↑ Cópialo aquí
```

Úsalo en:
```javascript
const EMPRESA_ID = "PEGA_TU_ID_AQUI";
```

---

## ✅ VERIFICACIÓN

Después de pegarlo, el script debería escribir en Firestore:
```
empresas/
└─ TU_ID_AQUI/
   ├─ estadisticas/
   │  └─ web_resumen (actualizado cada visita)
   └─ eventos/
      └─ (llamadas, formularios, WhatsApp)
```

Si ves datos llegando → **¡ID correcto!** ✅

Si NO ves datos → **Verifica que sea exacto** ⚠️

---

**¿Cuál es tu ID? Cuéntame y lo añado al script.** 🚀


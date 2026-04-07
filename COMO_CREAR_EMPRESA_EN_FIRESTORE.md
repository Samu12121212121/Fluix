 # 🏢 CÓMO CREAR LA EMPRESA EN FIRESTORE

## Tu Empresa

**ID:** `ztZblwm1w71wNQtzHV7S`
**Nombre:** Fluixtech
**Dominio:** fluixtech.com

---

## OPCIÓN 1: Por Firebase Console (Más rápido) ✅

### Paso 1: Ve a Firebase Console
1. Abre: https://console.firebase.google.com
2. Selecciona proyecto: `planeaapp-4bea4`
3. Ve a Firestore

### Paso 2: Crea la colección y documento
1. Haz clic en "Crear colección"
2. Nombre: `empresas`
3. Haz clic en "Siguiente"
4. ID del documento: `ztZblwm1w71wNQtzHV7S`
5. Haz clic en "Crear documento"

### Paso 3: Añade los campos
```
nombre (String): "Fluixtech"
dominio (String): "fluixtech.com"
sitio_web (String): "fluixtech.com"
telefono (String): "" (vacío)
direccion (String): "" (vacío)
fecha_creacion (Timestamp): actual
```

### Paso 4: Crea las subcollections
Dentro del documento `ztZblwm1w71wNQtzHV7S`, crea:

**Subcollection 1: estadisticas**
- Documento: `web_resumen`
  ```
  visitas_totales (Number): 0
  visitas_mes (Number): 0
  ultima_visita (Timestamp): null
  sitio_web (String): "fluixtech.com"
  nombre_empresa (String): "Fluixtech"
  ```

**Subcollection 2: configuracion**
- Documento: `general`
  ```
  fecha_instalacion_script (Timestamp): null
  script_activo (Boolean): false
  dominio (String): "fluixtech.com"
  ```

---

## OPCIÓN 2: Por Cloud Function (Automático) ✅

**Después del deploy:**

```bash
curl -X POST https://europe-west1-planeaapp-4bea4.cloudfunctions.net/crearEmpresaHTTP \
  -H "Content-Type: application/json" \
  -d '{
    "empresaId": "ztZblwm1w71wNQtzHV7S",
    "nombre": "Fluixtech",
    "dominio": "fluixtech.com",
    "telefono": "",
    "direccion": ""
  }'
```

Espera la respuesta:
```json
{
  "exito": true,
  "mensaje": "Empresa \"Fluixtech\" creada exitosamente",
  "empresaId": "ztZblwm1w71wNQtzHV7S"
}
```

---

## OPCIÓN 3: Desde la App Flutter

En tu código Flutter:
```dart
final FirebaseFirestore _db = FirebaseFirestore.instance;

Future<void> crearEmpresa() async {
  await _db.collection('empresas').doc('ztZblwm1w71wNQtzHV7S').set({
    'nombre': 'Fluixtech',
    'dominio': 'fluixtech.com',
    'sitio_web': 'fluixtech.com',
    'telefono': '',
    'direccion': '',
    'fecha_creacion': DateTime.now(),
  });

  await _db
    .collection('empresas')
    .doc('ztZblwm1w71wNQtzHV7S')
    .collection('estadisticas')
    .doc('web_resumen')
    .set({
      'visitas_totales': 0,
      'visitas_mes': 0,
      'ultima_visita': null,
      'sitio_web': 'fluixtech.com',
      'nombre_empresa': 'Fluixtech',
    });

  await _db
    .collection('empresas')
    .doc('ztZblwm1w71wNQtzHV7S')
    .collection('configuracion')
    .doc('general')
    .set({
      'fecha_instalacion_script': null,
      'script_activo': false,
      'dominio': 'fluixtech.com',
    });
}
```

---

## ✅ Verificar que se creó

En Firebase Console:
```
empresas/
├─ ztZblwm1w71wNQtzHV7S/
│  ├─ nombre: "Fluixtech"
│  ├─ dominio: "fluixtech.com"
│  ├─ estadisticas/
│  │  └─ web_resumen: {...}
│  └─ configuracion/
│     └─ general: {...}
```

---

## 🚀 Después de crear la empresa

1. Pega el script en WordPress footer
2. Los datos comenzarán a llegar automáticamente
3. Verás estadísticas en tiempo real

---

**¿Cuál prefieres? La más rápida es la OPCIÓN 1 (Firebase Console)** ⚡


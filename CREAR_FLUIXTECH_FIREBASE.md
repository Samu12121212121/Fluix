# 🚀 CREAR FLUIXTECH EN FIREBASE

## ✅ OPCIÓN 1: INMEDIATA (Desde tu app - 2 minutos)

### Paso 1: Abre tu `main.dart` o pantalla de configuración

Añade esta función en un botón o en el `initState`:

```dart
import 'package:planeag_flutter/utils/inicializar_empresa.dart';

// Cuando quieras crear la empresa, llama:
await inicializarEmpresaFluixtech();
```

### Paso 2: Ejecuta
```bash
flutter run
```

### Paso 3: Toca el botón o espera a que se ejecute

Verás en la consola:
```
🚀 Inicializando empresa Fluixtech...
✅ Documento principal creado
✅ Estadísticas web_resumen creadas
✅ Configuración creada
✅ Estadísticas diarias creadas
✅ Estadísticas mensuales creadas
🎉 ¡Empresa Fluixtech inicializada correctamente!
```

### Paso 4: Verifica en Firebase Console
Ve a: https://console.firebase.google.com
Firestore → empresas → ztZblwm1w71wNQtzHV7S

¡Verás toda la estructura creada! ✅

---

## ✅ OPCIÓN 2: Por Cloud Function (Después del deploy)

Una vez hagas `firebase deploy --only functions`:

```bash
curl -X POST https://europe-west1-planeaapp-4bea4.cloudfunctions.net/crearEmpresaHTTP \
  -H "Content-Type: application/json" \
  -d '{
    "empresaId": "ztZblwm1w71wNQtzHV7S",
    "nombre": "Fluixtech",
    "dominio": "fluixtech.com"
  }'
```

Respuesta:
```json
{
  "exito": true,
  "mensaje": "Empresa \"Fluixtech\" creada exitosamente",
  "empresaId": "ztZblwm1w71wNQtzHV7S"
}
```

---

## ✅ OPCIÓN 3: Código simple en cualquier lugar

Puedes copiar-pegar esto en cualquier función:

```dart
void crearEmpresa() async {
  final db = FirebaseFirestore.instance;
  const id = "ztZblwm1w71wNQtzHV7S";
  
  await db.collection('empresas').doc(id).set({
    'nombre': 'Fluixtech',
    'dominio': 'fluixtech.com',
    'sitio_web': 'fluixtech.com',
    'fecha_creacion': FieldValue.serverTimestamp(),
  });

  await db.collection('empresas').doc(id)
    .collection('estadisticas').doc('web_resumen').set({
    'visitas_totales': 0,
    'visitas_mes': 0,
    'sitio_web': 'fluixtech.com',
    'nombre_empresa': 'Fluixtech',
  });

  print('✅ Empresa creada');
}
```

---

## 📋 Qué se crea:

```
empresas/
└─ ztZblwm1w71wNQtzHV7S/
   ├─ nombre: "Fluixtech"
   ├─ dominio: "fluixtech.com"
   ├─ sitio_web: "fluixtech.com"
   ├─ fecha_creacion: timestamp
   ├─ estadisticas/
   │  ├─ web_resumen (resumen general)
   │  ├─ visitas_2026-03-13 (hoy)
   │  └─ mes_2026-03 (este mes)
   └─ configuracion/
      └─ general (config)
```

---

## 🎯 RECOMENDACIÓN:

**OPCIÓN 1** es la más rápida (2 minutos).

Solo añade en tu app en algún lugar:
```dart
await inicializarEmpresaFluixtech();
```

Y listo.

---

**¿Prefieres que lo haga por ti en el código?** Dime dónde y lo implemento. 🚀


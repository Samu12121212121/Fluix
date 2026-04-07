# 🚀 EJECUTAR FLUTTER RUN

## Pasos para conectar tu app:

### 1. Terminal en la carpeta raíz:
```bash
cd C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
```

### 2. Limpia dependencias previas:
```bash
flutter clean
flutter pub get
```

### 3. Ejecuta la app:
```bash
flutter run
```

## ✅ Qué debería pasar:

1. **Compilando...**
   ```
   Building flutter app...
   ```

2. **Descargando dependencias**
   ```
   Getting packages...
   ```

3. **Conectando a emulador/dispositivo**
   ```
   Launching lib/main.dart on [tu dispositivo]
   ```

4. **App abierta** ✅
   Deberías ver tu app en el emulador o dispositivo

## 📝 Si hay errores:

### Error: "http" package not found
```
flutter pub add http
```

O ya está solucionado (usamos `dio` que ya tienes).

### Error: Dependencias faltantes
```bash
flutter pub get --verbose
```

### Error: Build gradle
```bash
cd android
gradlew clean
cd ..
flutter run
```

## 🔗 Verificar conexión Firebase:

Una vez la app esté abierta:
1. Ve a cualquier pantalla
2. Abre **Developer Tools** (F12 en navegador web)
3. Mira la consola (debería haber logs de Firebase)

Si ves:
```
✅ Firebase conectado
```

Todo está bien. ¡Ya está conectado!

---

**¿Algún error específico? Cuéntame y lo solucionamos.** 🚀


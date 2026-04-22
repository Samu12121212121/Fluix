# SOLUCIÓN PARA ERROR DE COMPILACIÓN IOS

El error que estás experimentando es:
```
lib/features/fiscal/pantallas/export_models_screen.dart:118:33: Error: The method 'HistorialPresentacionesScreen' isn't defined
```

## CAUSAS POSIBLES:
1. Cache corrupto de Flutter/iOS
2. Dependencias de Pods desactualizadas  
3. Archivos de build corruptos

## PASOS PARA RESOLVER:

### Opción 1: Usando el script PowerShell (RECOMENDADO)
```bash
# Ejecutar desde PowerShell como administrador:
powershell -ExecutionPolicy Bypass -File fix_ios_build.ps1
```

### Opción 2: Comandos manuales
```bash
# 1. Ir al directorio del proyecto
cd "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter"

# 2. Limpiar proyecto
flutter clean

# 3. Eliminar archivos iOS (opcional)
# Eliminar: ios/Pods, ios/Podfile.lock, ios/.symlinks

# 4. Obtener dependencias
flutter pub get

# 5. Instalar pods
cd ios
pod install --repo-update
cd ..

# 6. Compilar
flutter build ios --debug --no-codesign
```

### Opción 3: Desde el IDE
1. En tu IDE, ve a Tools → Flutter → Flutter Clean
2. Ejecuta Flutter Pub Get
3. Ve a ios/ y ejecuta `pod install`
4. Intenta compilar nuevamente

## VERIFICACIONES:
- El archivo `historial_presentaciones_screen.dart` existe ✓
- El import está correcto ✓
- La clase está bien definida ✓

El problema es de cache/build, no de código.

## SI PERSISTE EL ERROR:
1. Verifica que tienes Xcode actualizado
2. Verifica que tienes Flutter actualizado: `flutter upgrade`
3. Verifica que pod está instalado: `gem install cocoapods`

## ARCHIVOS CREADOS:
- `fix_ios_build.ps1` - Script automático de reparación
- `fix_build_error.bat` - Script alternativo

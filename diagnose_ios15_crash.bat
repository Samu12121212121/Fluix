@echo off
echo ================================================================================
echo 🔧 DIAGNOSTICO PASO A PASO - CRASH TRAS iOS 15.0
echo ================================================================================
echo.

:: Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ❌ Error: Este script debe ejecutarse desde la carpeta del proyecto Flutter
    pause
    exit /b 1
)

echo 📋 PROBLEMAS POTENCIALES IDENTIFICADOS:
echo.
echo 1. AppDelegate.swift con Firebase mal configurado
echo 2. Dependencias incompatibles con iOS 15.0
echo 3. APIs deprecadas en Flutter
echo 4. Configuración de CocoaPods desactualizada
echo.

echo 🔧 APLICANDO CORRECCIONES PASO A PASO...
echo.

echo ⭐ PASO 1: AppDelegate.swift mínimo (SIN Firebase)
echo    - Eliminado Firebase.configure() temporalmente
echo    - Solo GeneratedPluginRegistrant
echo    - Máxima compatibilidad iOS 15+
echo.

echo ⭐ PASO 2: Limpiar completamente el proyecto
flutter clean
if errorlevel 1 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)

echo ⭐ PASO 3: Limpiar iOS específicamente
cd ios
rm -rf build
rm -rf Pods/
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner*

echo ⭐ PASO 4: Reinstalar dependencias iOS
pod cache clean --all
pod install --repo-update --clean-install
if errorlevel 1 (
    echo ❌ Error en pod install - revisar dependencias
    cd ..
    pause
    exit /b 1
)
cd ..

echo ⭐ PASO 5: Obtener dependencias Flutter
flutter pub get
if errorlevel 1 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)

echo.
echo ================================================================================
echo ✅ DIAGNOSTICO COMPLETO APLICADO
echo ================================================================================
echo.
echo 🔬 ETAPAS DE PRUEBA:
echo.
echo 1. 📱 PROBAR AHORA: flutter run
echo    - Si funciona: El problema era Firebase en AppDelegate
echo    - Si crashea: El problema es más profundo
echo.
echo 2. 🔥 SI FUNCIONA, REACTIVAR FIREBASE:
echo    - Descomentar Firebase.configure() en AppDelegate.swift
echo    - Probar de nuevo
echo.
echo 3. 📊 SI SIGUE CRASHEANDO:
echo    - Abrir Xcode Console
echo    - Buscar logs específicos del crash
echo    - Verificar stack trace
echo.
echo 🎯 DEPENDENCIAS SOSPECHOSAS (si el problema persiste):
echo    • local_auth: ^2.3.0 (Face ID/Touch ID)
echo    • flutter_local_notifications: ^17.2.3
echo    • device_info_plus: ^10.1.2
echo    • firebase_messaging: ^15.1.3
echo.
echo 💡 SIGUIENTE SCRIPT: test_minimal_app.bat (si es necesario)
echo.

pause

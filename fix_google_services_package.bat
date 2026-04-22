@echo off
echo ================================================================================
echo 🔧 SOLUCION ERROR GOOGLE SERVICES - Package Name Mismatch
echo ================================================================================
echo.

:: Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ❌ Error: Este script debe ejecutarse desde la carpeta del proyecto Flutter
    pause
    exit /b 1
)

echo ❌ PROBLEMA IDENTIFICADO:
echo    Google Services error: No matching client found for package name 'com.fluixcrm.app'
echo.
echo 🔍 INCONSISTENCIA ENCONTRADA:
echo    • build.gradle.kts applicationId: com.fluixcrm.app
echo    • google-services.json tenía: com.example.planeaa, com.example.planeag_flutter
echo    • Faltaba: com.fluixcrm.app
echo.
echo ✅ CORRECCION APLICADA:
echo    • Agregada nueva entrada client en google-services.json
echo    • Package name: com.fluixcrm.app (coincide con applicationId)
echo    • Configuración Firebase completa para el package correcto
echo.

echo 🧹 Limpiando builds y cache de Gradle...
flutter clean
if errorlevel 1 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)

cd android
if exist "build" rmdir /s /q build
if exist ".gradle" rmdir /s /q .gradle
if exist "app\build" rmdir /s /q app\build
cd ..

echo 📦 Obteniendo dependencias...
flutter pub get
if errorlevel 1 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)

echo 🔨 Probando compilación Android...
flutter build apk --debug
if errorlevel 1 (
    echo ❌ Error en build - verificar logs arriba
    echo.
    echo 💡 Si persiste el error:
    echo    1. Verificar que Firebase Console tenga com.fluixcrm.app registrado
    echo    2. Descargar nuevo google-services.json desde Firebase Console
    echo    3. Reemplazar archivo android/app/google-services.json
    pause
    exit /b 1
)

echo.
echo ================================================================================
echo ✅ ERROR GOOGLE SERVICES CORREGIDO
echo ================================================================================
echo.
echo 🎉 La configuración de Google Services ahora es correcta
echo 📱 Package name com.fluixcrm.app configurado en google-services.json
echo 🔥 Firebase debería funcionar correctamente
echo.
echo 🚀 Para probar:
echo    flutter run
echo    flutter build apk --release
echo.
echo 📋 ARCHIVO CORREGIDO:
echo    android/app/google-services.json - Nueva entrada client agregada
echo.

pause

@echo off
echo ================================================================================
echo 🔧 SOLUCION ERROR GRADLE - newBuildDir Unresolved Reference
echo ================================================================================
echo.

:: Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ❌ Error: Este script debe ejecutarse desde la carpeta del proyecto Flutter
    pause
    exit /b 1
)

echo ❌ PROBLEMA IDENTIFICADO:
echo    android/build.gradle.kts tenía variable newBuildDir mal definida
echo    Líneas 29 y 32 con referencias no resueltas
echo.
echo ✅ CORRECCION APLICADA:
echo    - Variable newBuildDir correctamente definida
echo    - Configuración de buildDirectory arreglada
echo    - Sintaxis Kotlin corregida
echo.

echo 🧹 Limpiando builds anteriores...
flutter clean
if errorlevel 1 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)

echo 🧹 Limpiando cache de Gradle...
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
    echo ❌ Error en build APK - revisar logs arriba
    pause
    exit /b 1
)

echo.
echo ================================================================================
echo ✅ ERROR GRADLE CORREGIDO EXITOSAMENTE
echo ================================================================================
echo.
echo 🎉 El archivo build.gradle.kts ahora está correcto
echo 📱 La compilación Android debería funcionar
echo.
echo 🚀 Para probar:
echo    flutter run (Android)
echo    flutter build apk --release
echo.
echo 📋 CAMBIO APLICADO:
echo    android/build.gradle.kts - Variable newBuildDir definida correctamente
echo.

pause

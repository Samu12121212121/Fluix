@echo off
echo ================================================================================
echo 🔧 SOLUCION ERROR APP STORE CONNECT - Bundle Version Duplicada
echo ================================================================================
echo.

:: Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ❌ Error: Este script debe ejecutarse desde la carpeta del proyecto Flutter
    pause
    exit /b 1
)

echo ❌ PROBLEMA IDENTIFICADO:
echo    "The bundle version must be higher than the previously uploaded version: '9'"
echo    App Store Connect ya tiene una version con build number 9
echo.
echo ✅ CORRECCION APLICADA:
echo    pubspec.yaml: version: 1.0.9+10 → 1.0.9+11
echo    Nuevo build number será 11 (mayor que 9)
echo.

:: Obtener la versión actual del pubspec.yaml
for /f "tokens=2" %%i in ('findstr "^version:" pubspec.yaml') do set VERSION=%%i
echo 📋 Versión configurada en pubspec.yaml: %VERSION%

echo.
echo 🧹 Limpiando builds anteriores para asegurar nueva versión...
flutter clean
if errorlevel 1 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)

echo 📦 Obteniendo dependencias...
flutter pub get
if errorlevel 1 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)

echo 🔨 Construyendo iOS con nueva versión...
flutter build ios --release --no-codesign
if errorlevel 1 (
    echo ❌ Error en build iOS
    pause
    exit /b 1
)

echo.
echo ================================================================================
echo ✅ BUILD PREPARADO CON NUEVA VERSION
echo ================================================================================
echo.
echo 🎯 Build number actualizado: 9 → 11
echo 📱 Version string: 1.0.9
echo 🔢 Build number: 11
echo.
echo 🚀 SIGUIENTE PASO - SUBIR A APP STORE CONNECT:
echo.
echo 📱 OPCION A: Xcode (Recomendado)
echo    1. Abrir ios/Runner.xcworkspace
echo    2. Verificar versión: Product → Scheme → Edit Scheme → Archive → Build Configuration: Release
echo    3. Product → Archive
echo    4. Distribuir a App Store Connect
echo.
echo ☁️  OPCION B: CI/CD (Codemagic, etc.)
echo    1. Hacer commit del pubspec.yaml actualizado
echo    2. Push al repositorio
echo    3. El build automático usará la nueva versión
echo.
echo 🔍 VERIFICAR ANTES DE SUBIR:
echo    - Verificar en Xcode que muestre "1.0.9 (11)"
echo    - Confirmar que el bundle identifier sea correcto: com.fluixtech.crm
echo.

pause

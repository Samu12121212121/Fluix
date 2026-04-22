@echo off
echo ================================================================================
echo 🔧 SOLUCION ERROR iOS DEPLOYMENT TARGET - Firebase Storage iOS 15.0+
echo ================================================================================
echo.
echo ✅ CAMBIOS APLICADOS:
echo    - project.pbxproj: IPHONEOS_DEPLOYMENT_TARGET actualizado de 13.0 a 15.0
echo    - Podfile: Ya configurado para iOS 15.0
echo    - Firebase Storage compatible con iOS 15.0+
echo.

:: Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ❌ Error: Este script debe ejecutarse desde la carpeta del proyecto Flutter
    pause
    exit /b 1
)

echo 🧹 Limpiando proyecto completo...
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

:: Cambiar a directorio iOS
cd ios

echo 🧹 Limpiando Xcode y CocoaPods...
rm -rf build
rm -rf Pods/
rm -rf .symlinks/
rm -f Podfile.lock
pod cache clean --all

echo 📦 Reinstalando pods con iOS 15.0...
pod install --repo-update --clean-install
if errorlevel 1 (
    echo ❌ Error en pod install
    cd ..
    pause
    exit /b 1
)

:: Volver al directorio raíz
cd ..

echo.
echo ================================================================================
echo ✅ SOLUCION APLICADA CORRECTAMENTE
echo ================================================================================
echo.
echo 🎯 Cambios realizados:
echo    • iOS Deployment Target: 13.0 → 15.0
echo    • Pods limpiados e instalados con iOS 15.0
echo    • Firebase Storage ahora compatible
echo.
echo 🔨 Para construir el Archive:
echo    1. Abre ios/Runner.xcworkspace en Xcode
echo    2. Selecciona "Any iOS Device"
echo    3. Product → Archive
echo    4. El error de Firebase Storage debería estar resuelto
echo.
echo 📱 iOS 15.0+ significa compatibilidad con:
echo    • iPhone 6s y posteriores
echo    • iPad Air 2 y posteriores
echo    • iPad mini 4 y posteriores
echo    • iPhone SE (1st gen) y posteriores
echo.

pause

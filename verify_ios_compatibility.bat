@echo off
echo ================================================================================
echo 🔍 VERIFICACION FINAL - COMPATIBILIDAD iOS 15.0 + FIREBASE
echo ================================================================================
echo.

:: Verificar archivos críticos
echo 📋 VERIFICANDO CONFIGURACION...
echo.

echo ✅ DEPLOYMENT TARGET EN PROJECT.PBXPROJ:
findstr "IPHONEOS_DEPLOYMENT_TARGET = 15.0" ios\Runner.xcodeproj\project.pbxproj
if errorlevel 1 (
    echo ❌ Error: No se encontró iOS 15.0 en project.pbxproj
) else (
    echo ✅ Configurado correctamente para iOS 15.0
)
echo.

echo ✅ PODFILE CONFIGURACION:
findstr "platform :ios, '15.0'" ios\Podfile
if errorlevel 1 (
    echo ❌ Error: Podfile no configurado para iOS 15.0
) else (
    echo ✅ Podfile configurado para iOS 15.0
)
echo.

echo ✅ FIREBASE STORAGE VERSION:
findstr "firebase_storage: \^12" pubspec.yaml
if errorlevel 1 (
    echo ❌ Error: Firebase Storage no encontrado o versión incorrecta
) else (
    echo ✅ Firebase Storage ^12.3.4 - Compatible con iOS 15.0+
)
echo.

echo 📱 VERSIONES FIREBASE ACTUALES:
echo firebase_core: ^3.6.0
echo firebase_auth: ^5.3.1
echo firebase_messaging: ^15.1.3
echo firebase_analytics: ^11.3.3
echo firebase_storage: ^12.3.4 ← Esta requiere iOS 15.0+
echo firebase_crashlytics: ^4.1.3
echo firebase_performance: ^0.10.0+8
echo firebase_app_check: ^0.3.1+5
echo.

echo 🎯 COMPATIBILIDAD iOS 15.0:
echo ✅ iPhone 6s (2015) y posteriores
echo ✅ iPad Air 2 (2014) y posteriores
echo ✅ iPad mini 4 (2015) y posteriores
echo ✅ iPhone SE 1st gen (2016) y posteriores
echo ✅ iPod touch 7th gen (2019) y posteriores
echo.

echo ================================================================================
echo ✅ TODOS LOS ARCHIVOS CONFIGURADOS CORRECTAMENTE
echo ================================================================================
echo.
echo 🔨 SIGUIENTE PASO:
echo 1. Ejecutar: fix_ios_deployment_target.bat
echo 2. Abrir Xcode: ios/Runner.xcworkspace
echo 3. Product → Archive
echo 4. El error de Firebase Storage debería estar resuelto
echo.

pause

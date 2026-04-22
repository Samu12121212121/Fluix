@echo off
echo ================================================================================
echo 🚀 BUILD TESTFLIGHT CON NOTIFICACIONES PUSH VERIFICADAS
echo ================================================================================
echo.

:: Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ❌ Error: Este script debe ejecutarse desde la carpeta del proyecto Flutter
    pause
    exit /b 1
)

echo 📋 CHECKLIST PRE-BUILD:
echo ✅ Runner.entitlements: development
echo ✅ RunnerRelease.entitlements: production
echo ✅ AppDelegate.swift configurado con Firebase
echo ✅ GoogleService-Info.plist con REVERSED_CLIENT_ID
echo ✅ Info.plist con UIBackgroundModes remote-notification
echo.

:: Limpiar builds anteriores
echo 🧹 Limpiando builds anteriores...
flutter clean
if errorlevel 1 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)

:: Obtener dependencias
echo 📦 Obteniendo dependencias...
flutter pub get
if errorlevel 1 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)

:: Cambiar a directorio iOS
cd ios

:: Limpiar Xcode
echo 🧹 Limpiando Xcode...
rm -rf build
rm -rf Pods/
pod cache clean --all

:: Reinstalar pods
echo 📦 Reinstalando pods...
pod install --repo-update
if errorlevel 1 (
    echo ❌ Error en pod install
    cd ..
    pause
    exit /b 1
)

:: Volver al directorio raíz
cd ..

:: Build iOS Release (Archive)
echo 🔨 Construyendo iOS Release para TestFlight...
echo ⚠️  IMPORTANTE: Usa Xcode para archivar y subir a TestFlight
echo.
echo 1. Abre ios/Runner.xcworkspace en Xcode
echo 2. Selecciona "Any iOS Device"
echo 3. Product → Archive
echo 4. Distribuir app → App Store Connect
echo.

:: Verificar configuración de notificaciones
echo 🔔 VERIFICANDO CONFIGURACIÓN DE NOTIFICACIONES:
echo.

:: Verificar entitlements
echo Verificando Runner.entitlements...
findstr "development" ios\Runner\Runner.entitlements >nul && echo ✅ Runner.entitlements: development || echo ❌ Error en Runner.entitlements

echo Verificando RunnerRelease.entitlements...
findstr "production" ios\Runner\RunnerRelease.entitlements >nul && echo ✅ RunnerRelease.entitlements: production || echo ❌ Error en RunnerRelease.entitlements

:: Verificar Info.plist
echo Verificando Info.plist...
findstr "remote-notification" ios\Runner\Info.plist >nul && echo ✅ Info.plist: remote-notification configurado || echo ❌ Error: falta remote-notification

:: Verificar GoogleService-Info.plist
echo Verificando GoogleService-Info.plist...
findstr "REVERSED_CLIENT_ID" ios\Runner\GoogleService-Info.plist >nul && echo ✅ GoogleService-Info.plist: REVERSED_CLIENT_ID presente || echo ❌ Error: falta REVERSED_CLIENT_ID

:: Verificar AppDelegate
echo Verificando AppDelegate.swift...
findstr "FirebaseApp.configure" ios\Runner\AppDelegate.swift >nul && echo ✅ AppDelegate.swift: Firebase configurado || echo ❌ Error: Firebase no configurado en AppDelegate

echo.
echo ================================================================================
echo 📱 PARA PROBAR NOTIFICACIONES EN TESTFLIGHT:
echo ================================================================================
echo.
echo 1. Instala la app desde TestFlight
echo 2. Inicia sesión en la app
echo 3. Ve al menú lateral → Debug FCM
echo 4. Copia el token FCM
echo 5. Usa Firebase Console → Cloud Messaging para enviar prueba
echo.
echo 🔥 O usa el PushNotificationsTester desde la app:
echo    - Menú lateral → "Test Notificaciones Push"
echo.

pause

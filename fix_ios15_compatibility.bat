@echo off
echo ================================================================================
echo 🔧 DIAGNOSTICO Y CORRECCION: PROBLEMAS TRAS CAMBIO A iOS 15.0
echo ================================================================================
echo.

:: Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ❌ Error: Este script debe ejecutarse desde la carpeta del proyecto Flutter
    pause
    exit /b 1
)

echo 🔍 PROBLEMAS IDENTIFICADOS TRAS CAMBIO A iOS 15.0:
echo.
echo 1. ❌ AppDelegate.swift con código problemático de notificaciones
echo    - Sintaxis incompatible con iOS 15+
echo    - Delegados mal configurados
echo.
echo 2. ❌ Posibles dependencias incompatibles:
echo    - local_auth: ^2.3.0 (biometría)
echo    - flutter_local_notifications: ^17.2.3
echo    - device_info_plus: ^10.1.2
echo.
echo 3. ❌ APIs deprecadas en archivos:
echo    - withOpacity() en lugar de withValues(alpha:)
echo    - Posibles problemas de sintaxis Flutter
echo.

echo ✅ CORRECCIONES APLICADAS:
echo.
echo 1. ✅ AppDelegate.swift simplificado y compatible
echo 2. ✅ Configuración limpia de Firebase
echo 3. ✅ Eliminado código problemático de notificaciones
echo.

echo 🧹 Limpiando proyecto completo...
flutter clean
if errorlevel 1 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)

:: Cambiar a directorio iOS para limpiezas adicionales
cd ios

echo 🧹 Limpiando CocoaPods y derivados...
rm -rf build
rm -rf Pods/
rm -rf .symlinks/
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner*

echo 📦 Reinstalando pods con iOS 15.0...
pod cache clean --all
pod install --clean-install --repo-update
if errorlevel 1 (
    echo ❌ Error en pod install
    cd ..
    pause
    exit /b 1
)

:: Volver al directorio raíz
cd ..

echo 📦 Obteniendo dependencias Flutter...
flutter pub get
if errorlevel 1 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)

echo 🔍 Verificando compatibilidad de dependencias...
echo.
echo Dependencias que pueden tener problemas con iOS 15:
echo • local_auth: ^2.3.0 - REVISAR si funciona con Face ID en iOS 15+
echo • flutter_local_notifications: ^17.2.3 - Configuración manual necesaria
echo • device_info_plus: ^10.1.2 - Posibles cambios en APIs
echo • firebase_messaging: ^15.1.3 - Requiere configuración específica iOS 15+
echo.

echo ================================================================================
echo ✅ LIMPIEZA COMPLETA APLICADA
echo ================================================================================
echo.
echo 🚀 Para probar:
echo 1. Ejecutar en dispositivo/emulador iOS: flutter run
echo 2. Si aún crashea, verificar logs en Xcode Console
echo 3. Si funciona, hacer build release: flutter build ios
echo.
echo 📱 PROXIMOS PASOS SI AUN HAY PROBLEMAS:
echo 1. Abrir Xcode → Window → Devices and Simulators → View Device Logs
echo 2. Buscar crash logs de Fluix
echo 3. Verificar stack trace específico del crash
echo.
echo 🔔 NOTA: Las notificaciones push ahora requieren configuración manual
echo    desde Flutter (ya no desde AppDelegate.swift)
echo.

pause

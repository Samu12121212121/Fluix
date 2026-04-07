@echo off
REM ═══════════════════════════════════════════════════════════════════════════
REM PREPARAR FLUIX CRM PARA APP STORE / PLAY STORE
REM Cambia el Bundle ID de com.example.* a com.fluixtech.crm
REM ═══════════════════════════════════════════════════════════════════════════
REM
REM ⚠️  ANTES DE EJECUTAR ESTE SCRIPT:
REM   1. Asegúrate de tener GoogleService-Info.plist en ios/Runner/
REM   2. Asegúrate de tener google-services.json actualizado en android/app/
REM   3. Haz commit de todo tu código actual (por si algo sale mal)
REM
REM ═══════════════════════════════════════════════════════════════════════════

echo.
echo ============================================================
echo   PREPARAR FLUIX CRM PARA STORES
echo ============================================================
echo.

set PROJECT_DIR=C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter
set OLD_BUNDLE_IOS=com.example.planeagFlutter
set NEW_BUNDLE_IOS=com.fluixtech.crm
set OLD_BUNDLE_ANDROID=com.example.planeag_flutter
set NEW_BUNDLE_ANDROID=com.fluixtech.crm

echo [1/4] Cambiando Bundle ID en iOS (project.pbxproj)...
powershell -Command "(Get-Content '%PROJECT_DIR%\ios\Runner.xcodeproj\project.pbxproj') -replace '%OLD_BUNDLE_IOS%', '%NEW_BUNDLE_IOS%' | Set-Content '%PROJECT_DIR%\ios\Runner.xcodeproj\project.pbxproj' -Encoding UTF8"
echo       OK

echo [2/4] Cambiando applicationId en Android (build.gradle.kts)...
powershell -Command "(Get-Content '%PROJECT_DIR%\android\app\build.gradle.kts') -replace '%OLD_BUNDLE_ANDROID%', '%NEW_BUNDLE_ANDROID%' | Set-Content '%PROJECT_DIR%\android\app\build.gradle.kts' -Encoding UTF8"
echo       OK

echo [3/4] Cambiando iosBundleId en firebase_options.dart...
powershell -Command "(Get-Content '%PROJECT_DIR%\lib\firebase_options.dart') -replace '%OLD_BUNDLE_IOS%', '%NEW_BUNDLE_IOS%' | Set-Content '%PROJECT_DIR%\lib\firebase_options.dart' -Encoding UTF8"
echo       OK

echo [4/4] Limpiando cache de Flutter...
cd /d %PROJECT_DIR%
call flutter clean
call flutter pub get

echo.
echo ============================================================
echo   HECHO! Bundle ID cambiado a: %NEW_BUNDLE_IOS%
echo ============================================================
echo.
echo SIGUIENTE PASO:
echo   1. Ve a Firebase Console y registra la app iOS con el nuevo Bundle ID
echo   2. Descarga GoogleService-Info.plist y ponlo en ios\Runner\
echo   3. Descarga google-services.json actualizado y ponlo en android\app\
echo   4. Ejecuta: flutter build appbundle --release  (para Android)
echo   5. Ejecuta en Mac: flutter build ipa --release  (para iOS)
echo.
pause


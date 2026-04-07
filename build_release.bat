@echo off
echo ========================================
echo   Build Release - PlaneaGuada CRM
echo ========================================
echo.
echo Que quieres generar?
echo 1. APK (para pasar por WhatsApp o instalar directo)
echo 2. AAB (para subir a Google Play Store)
echo.
set /p opcion="Elige 1 o 2: "

cd /d "%~dp0"

if "%opcion%"=="1" (
    echo.
    echo Generando APK release...
    flutter clean
    flutter pub get
    flutter build apk --release --dart-define=FLUTTER_WEB_AUTO_DETECT=false
    echo.
    echo ========================================
    echo APK generado en:
    echo build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo Puedes pasarlo por WhatsApp o Google Drive
    echo a tu movil para instalarlo.
    echo ========================================
    explorer build\app\outputs\flutter-apk\
) else if "%opcion%"=="2" (
    echo.
    echo Generando AAB para Play Store...
    flutter clean
    flutter pub get
    flutter build appbundle --release
    echo.
    echo ========================================
    echo AAB generado en:
    echo build\app\outputs\bundle\release\app-release.aab
    echo.
    echo Sube este archivo a Google Play Console.
    echo ========================================
    explorer build\app\outputs\bundle\release\
) else (
    echo Opcion no valida.
)

echo.
pause


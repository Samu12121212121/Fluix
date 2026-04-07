@echo off
echo ===============================================================
echo  PlaneaG — Completar sesion 2026-04-01
echo ===============================================================

cd /d "%~dp0"

echo.
echo [1/4] flutter pub get (dependencias principales)...
call flutter pub get
if errorlevel 1 ( echo ERROR en flutter pub get & pause & exit /b 1 )

echo.
echo [2/4] dart pub get (billing_service)...
cd billing_service
call dart pub get
if errorlevel 1 ( echo ADVERTENCIA: dart pub get fallo en billing_service )
cd ..

echo.
echo [3/4] Generando iconos de la app (flutter_launcher_icons)...
call flutter pub run flutter_launcher_icons
if errorlevel 1 ( echo ERROR generando iconos & pause & exit /b 1 )

echo.
echo [4/4] Verificando compilacion (flutter analyze)...
call flutter analyze
if errorlevel 1 ( echo Hay advertencias — revisa el output )

echo.
echo ===============================================================
echo  COMPLETADO. Puedes ejecutar:
echo    flutter run --debug
echo  o para release:
echo    flutter build apk --release
echo ===============================================================
pause


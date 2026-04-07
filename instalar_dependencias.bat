@echo off
echo ==========================================
echo  Instalando dependencias de PlaneaGuada
echo ==========================================
cd /d %~dp0
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: flutter pub get fallo
    pause
    exit /b 1
)
echo.
echo ==========================================
echo  Dependencias instaladas correctamente!
echo ==========================================
echo.
echo Ahora puedes ejecutar: flutter run
pause


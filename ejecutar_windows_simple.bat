@echo off
echo ================================================
echo   FLUIXCRM WINDOWS - LIMPIEZA Y EJECUCION
echo ================================================
echo.
echo NOTA: Si aparece error de CMake con Firebase,
echo       ejecuta: ejecutar_windows_fix.bat
echo.
echo Limpiando proyecto anterior...
flutter clean >nul 2>&1

echo Ejecutando en Windows...
echo.
flutter run -d windows


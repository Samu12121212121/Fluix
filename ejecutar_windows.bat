@echo off
echo ========================================
echo   EJECUTAR FLUIXCRM EN WINDOWS DESKTOP
echo ========================================
echo.

echo [1/3] Verificando configuracion de Flutter...
flutter config --enable-windows-desktop
echo.

echo [2/3] Limpiando build anterior...
flutter clean
echo.

echo [3/3] Ejecutando app en Windows...
flutter run -d windows

pause

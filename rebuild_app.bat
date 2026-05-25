@echo off
title Rebuilding Fluix CRM App
cd /d "C:\Users\Samu\AndroidStudioProjects\PlaneaG\planeag_flutter"

echo.
echo ==========================================
echo   Fluix CRM - Rebuilding App
echo ==========================================
echo.

echo [1/3] Limpiando cache de Flutter...
call flutter clean

echo.
echo [2/3] Descargando dependencias...
call flutter pub get

echo.
echo [3/3] Iniciando app...
call flutter run

echo.
echo Listo!
pause


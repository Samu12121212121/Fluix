@echo off
echo Limpiando cache de compilacion de Flutter...
echo.

cd /d "%~dp0"

echo [1/4] Flutter clean...
call flutter clean

echo.
echo [2/4] Eliminando carpeta build...
if exist build rmdir /s /q build

echo.
echo [3/4] Eliminando archivos generados de Windows...
if exist windows\flutter\ephemeral rmdir /s /q windows\flutter\ephemeral
if exist build\windows rmdir /s /q build\windows

echo.
echo [4/4] Obteniendo dependencias...
call flutter pub get

echo.
echo ============================================
echo Limpieza completada!
echo Ahora puedes compilar de nuevo con:
echo   flutter build windows
echo ============================================
pause


@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   FIX FIREBASE CMAKE Y EJECUTAR
echo ========================================
echo.

echo [PASO 1/5] Limpiando proyecto completamente...
flutter clean >nul 2>&1
if exist build rmdir /s /q build >nul 2>&1
echo OK - Limpieza completada
echo.

echo [PASO 2/5] Obteniendo dependencias...
flutter pub get >nul 2>&1
echo OK - Dependencias obtenidas
echo.

echo [PASO 3/5] IMPORTANTE: Descargando Firebase SDK...
echo (Esto tardara 5-10 minutos la primera vez)
echo (El comando fallara al final, pero eso es normal)
echo.

REM Intentar build para que descargue Firebase SDK
flutter build windows --debug 2>nul

echo.
echo [PASO 4/5] Buscando y parcheando Firebase CMakeLists.txt...

set "firebaseCMake=build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"

if exist "%firebaseCMake%" (
    echo OK - Archivo Firebase encontrado
    echo      Aplicando parche CMAKE...

    REM Crear respaldo
    copy "%firebaseCMake%" "%firebaseCMake%.backup" >nul 2>&1

    REM Usar PowerShell para hacer el reemplazo - usar 3.10 por compatibilidad
    powershell -Command "(Get-Content '%firebaseCMake%') -replace 'cmake_minimum_required\(VERSION [0-9.]+\)', 'cmake_minimum_required(VERSION 3.10)' | Set-Content '%firebaseCMake%'"
    
    echo OK - Parche aplicado correctamente
    echo      VERSION cambiada a 3.10
) else (
    echo ERROR - Archivo Firebase no encontrado en:
    echo        %firebaseCMake%
    echo.
    echo        El SDK no se descargo. Verifica tu conexion.
    pause
    exit /b 1
)

echo.
echo [PASO 5/5] Ejecutando app en Windows...
echo (Ahora deberia compilar correctamente)
echo.
echo ========================================
echo.

REM NO limpiar build, usar el archivo parcheado
flutter run -d windows

echo.
echo ========================================
echo   Ejecucion completada
echo ========================================
pause



@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   SOLUCION COMPLETA CMAKE + PLUGINS
echo ========================================
echo.

echo [PASO 1/7] Cerrando procesos de Flutter/Dart...
taskkill /F /IM dart.exe >nul 2>&1
taskkill /F /IM flutter.exe >nul 2>&1
timeout /t 2 >nul

echo [PASO 2/7] Limpiando COMPLETAMENTE el proyecto...
if exist build rmdir /s /q build
if exist windows\flutter\ephemeral rmdir /s /q windows\flutter\ephemeral
if exist .dart_tool rmdir /s /q .dart_tool
if exist .flutter-plugins rmdir /s /q .flutter-plugins
if exist .flutter-plugins-dependencies rmdir /s /q .flutter-plugins-dependencies
flutter clean >nul 2>&1
echo OK - Limpieza completa

echo.
echo [PASO 3/7] Obteniendo dependencias (regenera symlinks)...
flutter pub get
if errorlevel 1 (
    echo ERROR - Fallo en flutter pub get
    echo Verifica tu conexion a internet
    pause
    exit /b 1
)
echo OK - Dependencias obtenidas

echo.
echo [PASO 4/7] Verificando que existen los symlinks...
if not exist "windows\flutter\ephemeral\.plugin_symlinks\firebase_core" (
    echo ERROR - Symlinks no se generaron correctamente
    echo Intentando flutter pub get de nuevo...
    flutter pub get
    if not exist "windows\flutter\ephemeral\.plugin_symlinks\firebase_core" (
        echo ERROR CRITICO - Los symlinks siguen sin generarse
        echo.
        echo Posibles causas:
        echo 1. Usuario sin permisos para crear symlinks
        echo 2. Antivirus bloqueando operacion
        echo 3. Problema en flutter pub cache
        echo.
        echo Intentando reparar cache de Flutter...
        flutter pub cache repair
        flutter pub get
        pause
        exit /b 1
    )
)
echo OK - Symlinks verificados

echo.
echo [PASO 5/7] Iniciando build para descargar Firebase SDK...
echo (Esto fallara, pero es normal - solo necesitamos el SDK)
flutter build windows --debug 2>nul

echo.
echo [PASO 6/7] Parcheando Firebase CMakeLists.txt...
set "firebaseCMake=build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"

if exist "%firebaseCMake%" (
    echo OK - Firebase SDK descargado
    echo      Aplicando parche...

    REM Crear respaldo
    copy "%firebaseCMake%" "%firebaseCMake%.backup" >nul 2>&1

    REM Parchear VERSION
    powershell -Command "(Get-Content '%firebaseCMake%') -replace 'cmake_minimum_required\(VERSION [0-9.]+\)', 'cmake_minimum_required(VERSION 3.10)' | Set-Content '%firebaseCMake%'"

    echo OK - Parche aplicado (VERSION 3.10)
) else (
    echo AVISO - Firebase SDK no se descargo
    echo         Intentando ejecutar de todas formas...
)

echo.
echo [PASO 7/7] Ejecutando app en Windows...
echo.
echo ========================================
echo.

flutter run -d windows

if errorlevel 1 (
    echo.
    echo ========================================
    echo   FALLO EN EJECUCION
    echo ========================================
    echo.
    echo Si el error es sobre symlinks:
    echo - Ejecuta PowerShell como administrador:
    echo   New-Item -ItemType SymbolicLink requiere permisos
    echo.
    echo Si el error es sobre Firebase:
    echo - Verifica que el parche se aplico
    echo - Revisa: build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt
    echo   Debe tener: cmake_minimum_required(VERSION 3.10)
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Ejecucion completada exitosamente
echo ========================================
pause


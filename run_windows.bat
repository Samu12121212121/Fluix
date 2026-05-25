@echo off
echo ================================================
echo   FLUIXCRM WINDOWS - CON FIX CMAKE AUTOMATICO
echo ================================================
echo.

REM Verificar si existe el archivo de Firebase que causa problemas
set "firebaseCMake=build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"

if exist "%firebaseCMake%" (
    echo [FIX] Aplicando parche a Firebase CMakeLists.txt...
    powershell -Command "(Get-Content '%firebaseCMake%') -replace 'cmake_minimum_required\(VERSION [0-9.]+\)', 'cmake_minimum_required(VERSION 3.10)' | Set-Content '%firebaseCMake%'" >nul 2>&1
    echo [OK] Parche aplicado (VERSION 3.10)
    echo.
)

echo Ejecutando FluixCRM en Windows...
echo.
flutter run -d windows




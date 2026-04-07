@echo off
echo ══════════════════════════════════════════════════════════════
echo  BILLING SERVICE — Instalar dependencias y ejecutar tests
echo ══════════════════════════════════════════════════════════════
echo.

cd /d "%~dp0billing_service"

echo [1/2] Instalando dependencias...
call dart pub get
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: No se pudieron instalar las dependencias.
    echo Asegurate de tener Dart SDK en el PATH.
    pause
    exit /b 1
)

echo.
echo [2/2] Ejecutando tests...
call dart test test/billing_service_test.dart --reporter expanded
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ALGUNOS TESTS FALLARON — revisa los errores arriba.
) else (
    echo.
    echo ✅ TODOS LOS TESTS PASARON
)

echo.
pause


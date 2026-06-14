@echo off
echo ========================================
echo  SEED DE NEGOCIOS DE PRUEBA
echo ========================================
echo.
echo IMPORTANTE: Antes de ejecutar, abre:
echo   lib\scripts\seed_negocios_prueba.dart
echo.
echo Y cambia EMPRESA_ID_VINCULADA por tu empresa real.
echo.
echo Presiona ENTER para continuar o CTRL+C para cancelar...
pause >nul

cd /d "%~dp0"
dart run lib\scripts\seed_negocios_prueba.dart

echo.
echo Presiona ENTER para cerrar...
pause >nul

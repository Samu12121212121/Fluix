@echo off
echo ================================
echo   LIMPIEZA Y RECONSTRUCCION
echo ================================
echo.

echo [1/3] Limpiando cache de Flutter...
call flutter clean

echo.
echo [2/3] Descargando dependencias...
call flutter pub get

echo.
echo [3/3] Verificando errores...
call flutter analyze lib/services/pdf lib/domain/modelos/pdf_template.dart

echo.
echo ================================
echo   PROCESO COMPLETADO
echo ================================
pause


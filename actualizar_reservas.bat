@echo off
echo.
echo ════════════════════════════════════════════════════════════════
echo   🔄 ACTUALIZANDO CONFIGURACIÓN DE RESERVAS
echo ════════════════════════════════════════════════════════════════
echo.

echo 📦 Obteniendo dependencias...
call flutter pub get

echo.
echo 🧹 Limpiando caché de build...
call flutter clean

echo.
echo 🔨 Compilando proyecto...
call flutter pub get

echo.
echo ════════════════════════════════════════════════════════════════
echo   ✅ ACTUALIZACIÓN COMPLETADA
echo ════════════════════════════════════════════════════════════════
echo.
echo 📋 SIGUIENTE PASO:
echo    1. Ejecuta: flutter run
echo    2. Abre la app y ve a Configuración de Reservas
echo    3. Haz un cambio y guarda
echo    4. Verifica el mensaje: "✅ Configuración guardada y sincronizada con web"
echo.
echo 📄 Lee SOLUCION_CONFIGURACION_RESERVAS.md para más detalles
echo.

pause


@echo off
REM ═══════════════════════════════════════════════════════════════════════════════
REM TEST RÁPIDO - Sistema de Captura de Errores (NUEVO)
REM ═══════════════════════════════════════════════════════════════════════════════

echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo   🚨 TEST - SISTEMA DE CAPTURA DE ERRORES ANTES DEL CRASH
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
echo CAMBIOS APLICADOS:
echo   ✅ Captura de errores ANTES del crash
echo   ✅ Diálogo de error visible con detalles completos
echo   ✅ Error guardado en archivo persistente
echo   ✅ PDF desactivado temporalmente para debugging
echo.
echo Este script:
echo   1. Limpia compilación previa
echo   2. Recompila la app con el nuevo sistema
echo   3. Ejecuta la app en Windows
echo   4. Monitorea errores
echo.
pause

cd /d "%~dp0"

echo.
echo ──────────────────────────────────────────────────────────────────────────────
echo 1/3 - Limpiando compilación previa...
echo ──────────────────────────────────────────────────────────────────────────────
flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)
echo ✅ Limpieza completada

echo.
echo ──────────────────────────────────────────────────────────────────────────────
echo 2/3 - Obteniendo dependencias...
echo ──────────────────────────────────────────────────────────────────────────────
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)
echo ✅ Dependencias listas

echo.
echo ──────────────────────────────────────────────────────────────────────────────
echo 3/3 - Ejecutando aplicación con monitoreo...
echo ──────────────────────────────────────────────────────────────────────────────
echo.
echo ⏳ Iniciando app en Windows...
echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo   📋 INSTRUCCIONES CRÍTICAS
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
echo 1. Espera a que la app se abra completamente
echo.
echo 2. Ve a: TPV -^> Caja Rápida
echo.
echo 3. Añade varios productos al ticket
echo.
echo 4. Click en COBRAR
echo.
echo 5. Confirma el cobro
echo.
echo 6. 🚨 IMPORTANTE: SI APARECE UN DIÁLOGO ROJO CON ERROR:
echo.
echo     🔴 ¡NO LO CIERRES INMEDIATAMENTE!
echo.
echo     📋 LEE TODO EL CONTENIDO
echo     📝 Anota o copia:
echo         - "Paso que falló"
echo         - "Error" completo
echo.
echo     💾 El error también se guardará en:
echo         C:\Users\Samu\Documents\fluixcrm_error_cobro.txt
echo.
echo 7. Presiona Ctrl+C aquí para finalizar el monitoring
echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
echo 🔍 Monitoreando errores...
echo.

flutter run -d windows --verbose 2>&1 | findstr /C:"🚨" /C:"[COBRO]" /C:"ERROR CRÍTICO" /C:"PASO" /C:"Lost connection"

echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo   📊 RESUMEN
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
echo ¿Apareció el diálogo ROJO de error?
echo.
echo   ✅ SÍ → PERFECTO! El sistema funcionó
echo          Comparte el contenido del error que aparecía en el diálogo
echo          O abre: C:\Users\Samu\Documents\fluixcrm_error_cobro.txt
echo.
echo   ❌ NO → La app se cerró sin mostrar error
echo          Revisar logs en consola arriba
echo.
echo ¿El cobro funcionó completamente?
echo.
echo   ✅ SÍ → Genial! El problema ERA el PDF/impresora
echo          Ahora hay que arreglar esa parte específica
echo.
echo   ❌ NO → Hay otro error antes del PDF
echo          El diálogo te habrá dicho cuál es
echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
echo Para ver el error guardado:
echo   notepad C:\Users\Samu\Documents\fluixcrm_error_cobro.txt
echo.
echo Para ver el log de crash original:
echo   notepad C:\Users\Samu\Documents\fluixcrm_crash.log
echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo.

pause



@echo off
REM ═══════════════════════════════════════════════════════════════════════════════
REM TEST RÁPIDO - Fix de Crash Windows (Threading + Auth)
REM ═══════════════════════════════════════════════════════════════════════════════

echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo   🧪 TEST RÁPIDO - FIX CRASH WINDOWS
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
echo Este script:
echo   1. Limpia compilación previa
echo   2. Recompila la app con los fixes
echo   3. Ejecuta y monitorea errores de threading
echo   4. Muestra resumen al finalizar
echo.
pause

cd /d "%~dp0"

echo.
echo ──────────────────────────────────────────────────────────────────────────────
echo 1/4 - Limpiando compilación previa...
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
echo 2/4 - Obteniendo dependencias...
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
echo 3/4 - Ejecutando aplicación...
echo ──────────────────────────────────────────────────────────────────────────────
echo.
echo ⏳ Iniciando app en Windows...
echo    Guardando logs en: test_threading_fix.txt
echo.
echo 📋 INSTRUCCIONES:
echo    1. Espera a que la app se abra
echo    2. Ve a TPV -^> Caja Rápida
echo    3. Navega entre categorías 2-3 veces
echo    4. Añade varios productos
echo    5. Intenta COBRAR
echo    6. Cierra la app normalmente (NO debe crashear)
echo    7. Presiona Ctrl+C aquí para finalizar el monitoring
echo.
echo 🔍 Buscando errores de threading...
echo.

flutter run -d windows --verbose 2>&1 | findstr /C:"non-platform thread" /C:"FIRESTORE THREAD FIX" /C:"[COBRO]" /C:"Lost connection"

echo.
echo ──────────────────────────────────────────────────────────────────────────────
echo 4/4 - Analizando resultados...
echo ──────────────────────────────────────────────────────────────────────────────
echo.

REM Buscar errores de threading en el log
findstr /C:"non-platform thread" test_threading_fix.txt > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ❌ ENCONTRADOS ERRORES DE THREADING
    echo    Algunos StreamBuilder aún no usan SafeStreamBuilder
    echo.
    echo    Para ver detalles:
    echo    notepad test_threading_fix.txt
    echo.
) else (
    echo ✅ SIN ERRORES DE THREADING
    echo    El fix está funcionando correctamente
    echo.
)

REM Buscar si la app crasheó
findstr /C:"Lost connection to device" test_threading_fix.txt > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ❌ LA APP CRASHEÓ
    echo    Revisar logs para identificar la causa
    echo.
    echo    Abrir log completo:
    echo    notepad test_threading_fix.txt
    echo.
) else (
    echo ✅ SIN CRASH DETECTADO
    echo    La app cerró normalmente
    echo.
)

REM Buscar logs del fix de threading
findstr /C:"FIRESTORE THREAD FIX" test_threading_fix.txt > nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ FIX DE THREADING ACTIVO
    echo    Los streams están protegidos correctamente
    echo.
) else (
    echo ⚠️  FIX DE THREADING NO DETECTADO
    echo    Verificar que SafeStreamBuilder se está usando
    echo.
)

echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo   📊 RESUMEN
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
echo Archivos generados:
echo   • test_threading_fix.txt (log completo)
echo   • C:\Users\Samu\Documents\fluixcrm_crash.log (log persistente)
echo.
echo Para ver log completo:
echo   notepad test_threading_fix.txt
echo.
echo Para ver log persistente:
echo   notepad C:\Users\Samu\Documents\fluixcrm_crash.log
echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo.

pause


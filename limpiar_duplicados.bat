@echo off
echo ═══════════════════════════════════════════════════
echo    LIMPIEZA DE ARCHIVOS DUPLICADOS — Fluix CRM
echo ═══════════════════════════════════════════════════
echo.

REM ── 1. Archivos de valoraciones duplicados ──────────────
echo Eliminando archivos de valoraciones duplicados...
del /f "lib\features\dashboard\widgets\modulo_valoraciones_backup.dart" 2>nul
del /f "lib\features\dashboard\widgets\modulo_valoraciones_nuevo.dart" 2>nul
echo   OK: valoraciones backup y nuevo eliminados

REM ── 2. Pantalla de pedidos duplicada ────────────────────
REM (el dashboard usa modulo_pedidos_nuevo_screen, no el original)
REM NO ELIMINAR modulo_pedidos_screen.dart — puede tener funciones que
REM se usen en algún sitio. Verificar primero.

REM ── 3. Carpeta lib\screens\ (duplica features\) ────────
echo.
echo Eliminando lib\screens\ (duplicados de features\)...
rmdir /s /q "lib\screens" 2>nul
echo   OK: lib\screens eliminado

REM ── 4. Carpeta lib\models\ (duplica domain\modelos\) ───
echo.
echo Eliminando lib\models\ (duplicados de domain\modelos\)...
REM CUIDADO: embargo_model.dart y vacacion_model.dart se usan desde models\
REM Movemos los que se importan activamente antes de borrar:
echo   NOTA: Verifica que ningun import apunte a lib\models\ antes de borrar.
echo   Si todo usa domain\modelos\, puedes descomentar la linea siguiente:
REM rmdir /s /q "lib\models" 2>nul

echo.
echo ═══════════════════════════════════════════════════
echo    LIMPIEZA COMPLETADA
echo ═══════════════════════════════════════════════════
echo.
echo Ahora ejecuta: flutter pub get
echo Y luego: flutter analyze
pause


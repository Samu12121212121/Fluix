@echo off
REM ═══════════════════════════════════════════════════════════════════════════════
REM DEBUG_TPV.BAT - Ejecutor simplificado del script de debugging
REM ═══════════════════════════════════════════════════════════════════════════════

echo ═══════════════════════════════════════════════════════════════════════════════
echo    FLUIX CRM - DEBUGGING TPV CRASH
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
echo Este script ejecutará el debugging automático del crash en el TPV.
echo.
echo IMPORTANTE: 
echo   - Se abrirá la aplicación en modo debug
echo   - Ve a TPV -^> Caja Rápida
echo   - Reproduce el crash intentando cobrar
echo   - Los logs se guardarán automáticamente
echo.
echo Presiona cualquier tecla para continuar...
pause > nul
echo.

REM Ejecutar el script PowerShell
powershell.exe -ExecutionPolicy Bypass -File "%~dp0debug_tpv.ps1"

echo.
echo ═══════════════════════════════════════════════════════════════════════════════
echo   ✅ Proceso completado
echo ═══════════════════════════════════════════════════════════════════════════════
echo.
pause

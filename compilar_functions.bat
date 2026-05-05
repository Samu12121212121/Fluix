@echo off
cd functions
echo Compilando TypeScript y copiando templates...
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo ERROR en compilacion
    pause
    exit /b 1
)
echo.
echo ✅ Compilacion completada
echo.
pause


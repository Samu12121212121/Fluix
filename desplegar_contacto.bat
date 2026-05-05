@echo off
cd functions
echo Desplegando Cloud Function enviarEmailsContactoInteres...
call firebase deploy --only functions:enviarEmailsContactoInteres
if %ERRORLEVEL% NEQ 0 (
    echo ERROR en despliegue
    pause
    exit /b 1
)
echo.
echo ✅ Despliegue completado
echo.
pause


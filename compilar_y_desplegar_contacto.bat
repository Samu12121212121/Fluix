@echo off
echo ========================================
echo COMPILAR Y DESPLEGAR EMAILS DE CONTACTO
echo ========================================
echo.

cd functions

echo [1/4] Compilando TypeScript y copiando templates...
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR en compilacion
    echo.
    pause
    exit /b 1
)

echo.
echo [2/4] Verificando templates copiados...
dir lib\templates\contacto*.html | find "contacto"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️ ADVERTENCIA: No se encontraron templates de contacto
    echo.
)

echo.
echo [3/4] Desplegando Cloud Function...
call firebase deploy --only functions:enviarEmailsContactoInteres
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR en despliegue
    echo.
    pause
    exit /b 1
)

echo.
echo [4/4] Verificacion final...
echo.
echo ============================================
echo ✅ DESPLIEGUE COMPLETADO
echo ============================================
echo.
echo La Cloud Function 'enviarEmailsContactoInteres' esta lista.
echo.
echo Cuando alguien llene el formulario de contacto:
echo   1. Email de confirmacion al usuario
echo   2. Email de notificacion a sacoor80@gmail.com
echo   3. Tarea de alta prioridad en modulo propietario
echo.
echo 📄 Lee INSTRUCCIONES_DESPLIEGUE_CONTACTO.md para mas detalles
echo.
pause



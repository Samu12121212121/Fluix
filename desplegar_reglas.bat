@echo off
cd /d "%~dp0"
echo ============================================
echo  Desplegando Reglas Firestore + Hosting Web
echo ============================================
echo.

call firebase deploy --only firestore:rules,hosting
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR al desplegar.
    echo Comprueba que has iniciado sesion: firebase login
    pause
    exit /b 1
)

echo.
echo ============================================
echo  LISTO. Reglas y hosting desplegados.
echo  El formulario web ya puede crear reservas
echo  sin necesidad de login en Firebase Auth.
echo ============================================
pause

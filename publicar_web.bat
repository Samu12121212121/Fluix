@echo off
cd /d "%~dp0"
echo ============================================
echo  Publicando visor web en Firebase Hosting...
echo ============================================
echo.

where firebase >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Firebase CLI no encontrado.
    echo Instala con: npm install -g firebase-tools
    echo.
    pause
    exit /b 1
)

firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo.
    echo ERROR al desplegar. Revisa el error arriba.
    echo Si pone "not logged in", ejecuta primero: firebase login
    pause
    exit /b 1
)

echo.
echo ============================================
echo  URLS DE TUS SCRIPTS (copia las que necesites):
echo.
echo  Script principal:
echo  https://planeaapp-4bea4.web.app/fluix-embed.js
echo.
echo  Script configuracion Hostinger:
echo  https://planeaapp-4bea4.web.app/fluix-setup-hostinger.js
echo ============================================
pause

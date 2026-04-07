@echo off
echo ══════════════════════════════════════════════════════════════
echo  ACTIVAR ADMIN DE PLATAFORMA
echo ══════════════════════════════════════════════════════════════
echo.
echo Este script activa tu cuenta como admin de plataforma.
echo Necesitas tener Node.js y el credentials.json del proyecto.
echo.
echo.

set /p EMAIL=Introduce tu email de Firebase Auth:

echo.
echo Activando %EMAIL% como admin de plataforma...
echo.

cd /d "%~dp0"
node scripts/activar_admin_plataforma.js %EMAIL%

echo.
pause

